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
    func testPhaseOneCatalogPrioritizesPhysicalManualGiftCards() {
        let catalog = MerchantCatalog.phase1

        XCTAssertEqual(catalog.all.count, 28)
        XCTAssertEqual(
            catalog.all.prefix(11).map(\.id),
            [
                "dunkin",
                "subway",
                "chipotle",
                "target",
                "walmart",
                "homedepot",
                "bestbuy",
                "sephora",
                "ulta",
                "olivegarden",
                "amc"
            ]
        )
        XCTAssertTrue(catalog.all.allSatisfy { $0.balanceLookup.capability == .manualOnly })
        XCTAssertEqual(catalog.merchant(id: "dunkin").category, .foodAndCoffee)
        XCTAssertEqual(catalog.merchant(id: "olivegarden").category, .restaurants)
        XCTAssertEqual(catalog.merchant(id: "visa_prepaid").category, .prepaid)
        XCTAssertFalse(catalog.merchant(id: "starbucks").requiresPin)
        XCTAssertFalse(catalog.merchant(id: "amazon").requiresPin)
    }

    func testManualCatalogMerchantsAreNotSubmittedToBackend() async throws {
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
            XCTFail("Manual catalog merchants should not use backend auto refresh.")
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

        let history = try repository.listBalanceHistory(cardID: card.id)
        XCTAssertEqual(history.count, 2)
        XCTAssertEqual(history[0].previousBalanceMinorUnits, 1250)
        XCTAssertEqual(history[0].newBalanceMinorUnits, 1400)
        XCTAssertEqual(history[0].balanceStatus, .verified)
        XCTAssertEqual(history[1].previousBalanceMinorUnits, nil)
        XCTAssertEqual(history[1].newBalanceMinorUnits, 1250)
        XCTAssertEqual(history[1].balanceStatus, .userEntered)
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

        let history = try repository.listBalanceHistory(cardID: card.id)
        XCTAssertEqual(history.count, 2)
        XCTAssertEqual(history[0].previousBalanceMinorUnits, 1250)
        XCTAssertEqual(history[0].newBalanceMinorUnits, 1250)
        XCTAssertEqual(history[0].balanceStatus, .refreshFailed)
        XCTAssertEqual(history[0].note, "Provider unavailable.")
    }

    @MainActor
    func testManualBalanceClearIsAudited() throws {
        let (repository, _) = try makeRepository()
        let merchant = MerchantCatalog.phase1.merchant(id: "target")
        let card = try repository.createCard(
            CardCreateInput(
                merchantID: merchant.id,
                displayName: merchant.displayName,
                cardNumber: "123456789012345",
                pin: "99999999",
                barcodeValue: "123456789012345",
                barcodeFormat: .code128,
                startingBalanceMinorUnits: 5000,
                currency: "USD"
            ),
            merchant: merchant
        )

        _ = try repository.updateManualBalance(id: card.id, minorUnits: nil, currency: "USD")

        let cardHistory = try repository.listBalanceHistory(cardID: card.id)
        XCTAssertEqual(cardHistory.count, 2)
        XCTAssertEqual(cardHistory[0].previousBalanceMinorUnits, 5000)
        XCTAssertNil(cardHistory[0].newBalanceMinorUnits)
        XCTAssertEqual(cardHistory[0].balanceStatus, .missing)
        XCTAssertEqual(cardHistory[0].changeText, "Cleared balance")

        let merchantHistory = try repository.listBalanceHistory(merchantID: merchant.id)
        XCTAssertEqual(merchantHistory.map(\.cardID), [card.id, card.id])
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
        let container = try ModelContainer(for: StoredCard.self, BalanceAdjustment.self, configurations: configuration)
        let encryption = try EncryptionService(keyStore: InMemoryKeyStore(key: Data(repeating: 4, count: 32)))
        return (SwiftDataCardRepository(context: container.mainContext, encryptionService: encryption), container)
    }
}
