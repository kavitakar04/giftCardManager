import Foundation
import SwiftData

enum CardRepositoryError: Error, LocalizedError {
    case cardNotFound
    case requiredPINMissing
    case unsupportedBarcodeFormat

    var errorDescription: String? {
        switch self {
        case .cardNotFound:
            return "The card could not be found."
        case .requiredPINMissing:
            return "This merchant requires a PIN."
        case .unsupportedBarcodeFormat:
            return "This barcode format is not supported for checkout display."
        }
    }
}

@MainActor
protocol CardRepository {
    func listActiveCards() throws -> [CardSummary]
    func getCard(id: UUID) throws -> StoredCard
    func createCard(_ input: CardCreateInput, merchant: Merchant) throws -> StoredCard
    func archiveCard(id: UUID) throws
    func updateManualBalance(id: UUID, minorUnits: Int?, currency: String) throws -> StoredCard
    func updateVerifiedBalance(
        id: UUID,
        minorUnits: Int,
        currency: String,
        providerID: String,
        message: String?
    ) throws -> StoredCard
    func recordBalanceRefreshFailure(id: UUID, providerID: String, message: String) throws -> StoredCard
    func saveBalanceRefreshConsent(
        id: UUID,
        providerID: String,
        version: String,
        grantedAt: Date
    ) throws -> StoredCard
    func clearBalanceRefreshConsent(id: UUID) throws -> StoredCard
    func ensureWalletSerialNumber(id: UUID) throws -> String
    func decryptSecrets(for card: StoredCard) throws -> CardSecrets
}

@MainActor
final class SwiftDataCardRepository: CardRepository {
    private let context: ModelContext
    private let encryptionService: EncryptionService

    init(context: ModelContext, encryptionService: EncryptionService) {
        self.context = context
        self.encryptionService = encryptionService
    }

    func listActiveCards() throws -> [CardSummary] {
        var descriptor = FetchDescriptor<StoredCard>(
            predicate: #Predicate { $0.archivedAt == nil },
            sortBy: [
                SortDescriptor(\.displayName),
                SortDescriptor(\.updatedAt, order: .reverse)
            ]
        )
        descriptor.includePendingChanges = true
        return try context.fetch(descriptor).map(\.summary)
    }

    func getCard(id: UUID) throws -> StoredCard {
        let descriptor = FetchDescriptor<StoredCard>(
            predicate: #Predicate { $0.id == id && $0.archivedAt == nil }
        )
        guard let card = try context.fetch(descriptor).first else {
            throw CardRepositoryError.cardNotFound
        }
        return card
    }

    func createCard(_ input: CardCreateInput, merchant: Merchant) throws -> StoredCard {
        if merchant.requiresPin && (input.pin ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw CardRepositoryError.requiredPINMissing
        }
        guard input.barcodeFormat.isRenderableInPhase1 else {
            throw CardRepositoryError.unsupportedBarcodeFormat
        }

        let now = Date()
        let card = StoredCard(
            merchantID: input.merchantID,
            displayName: input.displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            cardNumberCiphertext: try encryptionService.encrypt(input.cardNumber),
            pinCiphertext: try input.pin.flatMap { $0.isEmpty ? nil : try encryptionService.encrypt($0) },
            barcodeValueCiphertext: try encryptionService.encrypt(input.barcodeValue),
            barcodeFormat: input.barcodeFormat,
            currentBalanceMinorUnits: input.startingBalanceMinorUnits,
            currency: input.currency,
            balanceSource: input.startingBalanceMinorUnits == nil ? .unknown : .manual,
            balanceStatus: input.startingBalanceMinorUnits == nil ? .missing : .userEntered,
            lastBalanceUpdateAt: input.startingBalanceMinorUnits == nil ? nil : now,
            lastBalanceCheckStatusMessage: input.startingBalanceMinorUnits == nil
                ? nil : "Balance entered manually.",
            cardNumberLast4: MoneyFormatter.last4(input.cardNumber),
            walletPassSerialNumber: UUID().uuidString,
            createdAt: now,
            updatedAt: now
        )

        context.insert(card)
        try context.save()
        return card
    }

    func archiveCard(id: UUID) throws {
        let card = try getCard(id: id)
        card.archivedAt = Date()
        card.updatedAt = Date()
        try context.save()
    }

    func updateManualBalance(id: UUID, minorUnits: Int?, currency: String) throws -> StoredCard {
        let card = try getCard(id: id)
        card.currentBalanceMinorUnits = minorUnits
        card.currency = currency
        card.balanceSource = minorUnits == nil ? .unknown : .manual
        card.balanceStatus = minorUnits == nil ? .missing : .userEntered
        card.lastBalanceUpdateAt = minorUnits == nil ? nil : Date()
        card.lastBalanceCheckStatusMessage = minorUnits == nil ? nil : "Balance entered manually."
        card.updatedAt = Date()
        try context.save()
        return card
    }

    func updateVerifiedBalance(
        id: UUID,
        minorUnits: Int,
        currency: String,
        providerID: String,
        message: String?
    ) throws -> StoredCard {
        let card = try getCard(id: id)
        card.currentBalanceMinorUnits = minorUnits
        card.currency = currency.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? card.currency : currency.uppercased()
        card.balanceSource = .merchantLookup
        card.balanceStatus = .verified
        card.lastBalanceUpdateAt = Date()
        card.lastBalanceCheckStatusMessage = message ?? "Balance verified by \(providerID)."
        card.walletPassSerialNumber = nil
        card.updatedAt = Date()
        try context.save()
        return card
    }

    func recordBalanceRefreshFailure(id: UUID, providerID: String, message: String) throws -> StoredCard {
        let card = try getCard(id: id)
        card.balanceStatus = .refreshFailed
        card.lastBalanceCheckStatusMessage = message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Balance refresh failed with \(providerID)."
            : message
        card.updatedAt = Date()
        try context.save()
        return card
    }

    func saveBalanceRefreshConsent(
        id: UUID,
        providerID: String,
        version: String,
        grantedAt: Date = Date()
    ) throws -> StoredCard {
        let card = try getCard(id: id)
        card.balanceRefreshConsentProviderID = providerID
        card.balanceRefreshConsentVersion = version
        card.balanceRefreshConsentGrantedAt = grantedAt
        card.updatedAt = Date()
        try context.save()
        return card
    }

    func clearBalanceRefreshConsent(id: UUID) throws -> StoredCard {
        let card = try getCard(id: id)
        card.balanceRefreshConsentProviderID = nil
        card.balanceRefreshConsentVersion = nil
        card.balanceRefreshConsentGrantedAt = nil
        card.updatedAt = Date()
        try context.save()
        return card
    }

    func ensureWalletSerialNumber(id: UUID) throws -> String {
        let card = try getCard(id: id)
        if let serial = card.walletPassSerialNumber, !serial.isEmpty {
            return serial
        }
        let serial = UUID().uuidString
        card.walletPassSerialNumber = serial
        card.updatedAt = Date()
        try context.save()
        return serial
    }

    func decryptSecrets(for card: StoredCard) throws -> CardSecrets {
        CardSecrets(
            cardNumber: try encryptionService.decrypt(card.cardNumberCiphertext),
            pin: try card.pinCiphertext.map { try encryptionService.decrypt($0) },
            barcodeValue: try encryptionService.decrypt(card.barcodeValueCiphertext)
        )
    }
}
