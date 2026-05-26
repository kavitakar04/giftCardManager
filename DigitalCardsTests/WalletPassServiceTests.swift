import XCTest
import SwiftData
@testable import DigitalCards

final class WalletPassServiceTests: XCTestCase {
    @MainActor
    func testPassRequestIncludesPIN() throws {
        let service = WalletPassService(baseURL: URL(string: "http://localhost:3000")!)
        let encryption = try EncryptionService(keyStore: InMemoryKeyStore(key: Data(repeating: 3, count: 32)))
        let card = StoredCard(
            merchantID: "subway",
            displayName: "Subway",
            cardNumberCiphertext: try encryption.encrypt("1234567890123456"),
            pinCiphertext: try encryption.encrypt("9999"),
            barcodeValueCiphertext: try encryption.encrypt("1234567890123456"),
            barcodeFormat: .code128,
            currentBalanceMinorUnits: 1842,
            currency: "USD",
            balanceSource: .manual,
            balanceStatus: .userEntered,
            lastBalanceUpdateAt: Date(timeIntervalSince1970: 0),
            cardNumberLast4: "3456",
            walletPassSerialNumber: "serial-1"
        )
        let merchant = MerchantCatalog.phase1.merchant(id: "subway")

        let request = service.buildPassRequest(
            card: card,
            secrets: CardSecrets(cardNumber: "1234567890123456", pin: "9999", barcodeValue: "1234567890123456"),
            merchant: merchant,
            serialNumber: "serial-1"
        )
        let encoded = try JSONEncoder().encode(request)
        let json = String(data: encoded, encoding: .utf8)!

        XCTAssertEqual(request.cardNumberLast4, "3456")
        XCTAssertEqual(request.pin, "9999")
        XCTAssertTrue(json.contains("\"pin\":\"9999\""))
        XCTAssertFalse(json.contains("1234567890123456\"card"))
    }
}
final class BalanceLookupServiceTests: XCTestCase {
    func testPhaseOneMerchantsExposeLookupDescriptors() {
        let catalog = MerchantCatalog.phase1

        let subway = catalog.merchant(id: "subway").balanceLookup
        XCTAssertEqual(subway.capability, .officialWeb)
        XCTAssertEqual(subway.providerID, "subway-official-web")
        XCTAssertEqual(subway.requiredFields, [.cardNumber, .pin])
        XCTAssertEqual(subway.officialURL?.absoluteString, "https://www.subway.com/en-us/subwaycard?id=home")

        let starbucks = catalog.merchant(id: "starbucks").balanceLookup
        XCTAssertEqual(starbucks.capability, .officialWeb)
        XCTAssertEqual(starbucks.requiredFields, [.accountLogin])
        XCTAssertEqual(starbucks.officialURL?.absoluteString, "https://www.starbucks.com/card")

        let target = catalog.merchant(id: "target").balanceLookup
        XCTAssertEqual(target.capability, .officialWeb)
        XCTAssertEqual(target.requiredFields, [.cardNumber, .accessCode])
        XCTAssertEqual(target.officialURL?.absoluteString, "https://www.target.com/giftcard/check-balance")

        let amazon = catalog.merchant(id: "amazon").balanceLookup
        XCTAssertEqual(amazon.capability, .officialWeb)
        XCTAssertEqual(amazon.requiredFields, [.accountLogin])
        XCTAssertEqual(amazon.officialURL?.absoluteString, "https://www.amazon.com/gc/balance")

        let other = catalog.merchant(id: "other").balanceLookup
        XCTAssertEqual(other.capability, .manualOnly)
        XCTAssertEqual(other.requiredFields, [])
        XCTAssertNil(other.officialURL)
    }

    func testOfficialWebMerchantsAreNotSubmittedToBackend() async throws {
        let service = BalanceLookupService(baseURL: URL(string: "http://localhost:3000")!)
        let merchant = MerchantCatalog.phase1.merchant(id: "target")
        let secrets = CardSecrets(cardNumber: "123456789012345", pin: "99999999", barcodeValue: "123456789012345")

        do {
            _ = try await service.checkBackendBalance(
                merchant: merchant,
                secrets: secrets,
                consentToken: nil,
                consentVersion: nil
            )
            XCTFail("Official web merchants should not use backend auto refresh.")
        } catch BalanceLookupError.unsupportedAutoRefresh(let message) {
            XCTAssertTrue(message.contains("Target"))
        }
    }
}

final class CardRepositoryBalanceTests: XCTestCase {
    @MainActor
    func testManualAndVerifiedBalanceStatesAreStoredSeparately() throws {
        let (repository, _) = try makeRepository()
        let merchant = MerchantCatalog.phase1.merchant(id: "subway")
        let card = try repository.createCard(
            CardCreateInput(
                merchantID: merchant.id,
                displayName: merchant.displayName,
                cardNumber: "1234567890123456",
                pin: "9999",
                barcodeValue: "1234567890123456",
                barcodeFormat: .code128,
                startingBalanceMinorUnits: nil,
                currency: "USD"
            ),
            merchant: merchant
        )

        let manual = try repository.updateManualBalance(id: card.id, minorUnits: 1250, currency: "USD")
        XCTAssertEqual(manual.balanceSource, .manual)
        XCTAssertEqual(manual.balanceStatus, .userEntered)

        let verified = try repository.updateVerifiedBalance(
            id: card.id,
            minorUnits: 1400,
            currency: "USD",
            providerID: "test-provider",
            message: "Verified at merchant."
        )
        XCTAssertEqual(verified.balanceSource, .merchantLookup)
        XCTAssertEqual(verified.balanceStatus, .verified)
        XCTAssertEqual(verified.currentBalanceMinorUnits, 1400)
        XCTAssertEqual(verified.lastBalanceCheckStatusMessage, "Verified at merchant.")
        XCTAssertNil(verified.walletPassSerialNumber)
    }

    @MainActor
    func testRefreshFailureKeepsExistingBalanceAndStoresMessage() throws {
        let (repository, _) = try makeRepository()
        let merchant = MerchantCatalog.phase1.merchant(id: "subway")
        let card = try repository.createCard(
            CardCreateInput(
                merchantID: merchant.id,
                displayName: merchant.displayName,
                cardNumber: "1234567890123456",
                pin: "9999",
                barcodeValue: "1234567890123456",
                barcodeFormat: .code128,
                startingBalanceMinorUnits: 1250,
                currency: "USD"
            ),
            merchant: merchant
        )

        let failed = try repository.recordBalanceRefreshFailure(
            id: card.id,
            providerID: "test-provider",
            message: "Provider unavailable."
        )

        XCTAssertEqual(failed.currentBalanceMinorUnits, 1250)
        XCTAssertEqual(failed.balanceStatus, .refreshFailed)
        XCTAssertEqual(failed.lastBalanceCheckStatusMessage, "Provider unavailable.")
    }

    @MainActor
    func testBalanceRefreshConsentIsScopedAndClearable() throws {
        let (repository, _) = try makeRepository()
        let merchant = MerchantCatalog.phase1.merchant(id: "subway")
        let card = try repository.createCard(
            CardCreateInput(
                merchantID: merchant.id,
                displayName: merchant.displayName,
                cardNumber: "1234567890123456",
                pin: "9999",
                barcodeValue: "1234567890123456",
                barcodeFormat: .code128,
                startingBalanceMinorUnits: nil,
                currency: "USD"
            ),
            merchant: merchant
        )
        let grantedAt = Date(timeIntervalSince1970: 10)

        let consented = try repository.saveBalanceRefreshConsent(
            id: card.id,
            providerID: "provider-a",
            version: "v1",
            grantedAt: grantedAt
        )
        XCTAssertTrue(consented.hasBalanceRefreshConsent(providerID: "provider-a", version: "v1"))
        XCTAssertFalse(consented.hasBalanceRefreshConsent(providerID: "provider-a", version: "v2"))
        XCTAssertFalse(consented.hasBalanceRefreshConsent(providerID: "provider-b", version: "v1"))

        let cleared = try repository.clearBalanceRefreshConsent(id: card.id)
        XCTAssertNil(cleared.balanceRefreshConsentGrantedAt)
        XCTAssertNil(cleared.balanceRefreshConsentProviderID)
        XCTAssertNil(cleared.balanceRefreshConsentVersion)
    }

    @MainActor
    private func makeRepository() throws -> (SwiftDataCardRepository, ModelContainer) {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: StoredCard.self, configurations: configuration)
        let encryption = try EncryptionService(keyStore: InMemoryKeyStore(key: Data(repeating: 4, count: 32)))
        return (SwiftDataCardRepository(context: container.mainContext, encryptionService: encryption), container)
    }
}
