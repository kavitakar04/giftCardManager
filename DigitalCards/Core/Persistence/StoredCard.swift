import Foundation
import SwiftData

@Model
final class StoredCard {
    @Attribute(.unique) var id: UUID
    var merchantID: String
    var displayName: String
    var cardNumberCiphertext: Data
    var pinCiphertext: Data?
    var barcodeValueCiphertext: Data
    var barcodeFormatRaw: String
    var currentBalanceMinorUnits: Int?
    var currency: String
    var balanceSourceRaw: String
    var balanceStatusRaw: String
    var lastBalanceUpdateAt: Date?
    var balanceRefreshConsentGrantedAt: Date?
    var balanceRefreshConsentProviderID: String?
    var balanceRefreshConsentVersion: String?
    var lastBalanceCheckStatusMessage: String?
    var cardNumberLast4: String
    var walletPassSerialNumber: String?
    var createdAt: Date
    var updatedAt: Date
    var archivedAt: Date?

    init(
        id: UUID = UUID(),
        merchantID: String,
        displayName: String,
        cardNumberCiphertext: Data,
        pinCiphertext: Data?,
        barcodeValueCiphertext: Data,
        barcodeFormat: BarcodeFormat,
        currentBalanceMinorUnits: Int?,
        currency: String,
        balanceSource: BalanceSource,
        balanceStatus: BalanceStatus,
        lastBalanceUpdateAt: Date?,
        balanceRefreshConsentGrantedAt: Date? = nil,
        balanceRefreshConsentProviderID: String? = nil,
        balanceRefreshConsentVersion: String? = nil,
        lastBalanceCheckStatusMessage: String? = nil,
        cardNumberLast4: String,
        walletPassSerialNumber: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        archivedAt: Date? = nil
    ) {
        self.id = id
        self.merchantID = merchantID
        self.displayName = displayName
        self.cardNumberCiphertext = cardNumberCiphertext
        self.pinCiphertext = pinCiphertext
        self.barcodeValueCiphertext = barcodeValueCiphertext
        self.barcodeFormatRaw = barcodeFormat.rawValue
        self.currentBalanceMinorUnits = currentBalanceMinorUnits
        self.currency = currency
        self.balanceSourceRaw = balanceSource.rawValue
        self.balanceStatusRaw = balanceStatus.rawValue
        self.lastBalanceUpdateAt = lastBalanceUpdateAt
        self.balanceRefreshConsentGrantedAt = balanceRefreshConsentGrantedAt
        self.balanceRefreshConsentProviderID = balanceRefreshConsentProviderID
        self.balanceRefreshConsentVersion = balanceRefreshConsentVersion
        self.lastBalanceCheckStatusMessage = lastBalanceCheckStatusMessage
        self.cardNumberLast4 = cardNumberLast4
        self.walletPassSerialNumber = walletPassSerialNumber
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.archivedAt = archivedAt
    }
}

@Model
final class BalanceAdjustment {
    @Attribute(.unique) var id: UUID
    var cardID: UUID
    var merchantID: String
    var cardDisplayName: String
    var cardNumberLast4: String
    var previousBalanceMinorUnits: Int?
    var newBalanceMinorUnits: Int?
    var currency: String
    var balanceSourceRaw: String
    var balanceStatusRaw: String
    var note: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        cardID: UUID,
        merchantID: String,
        cardDisplayName: String,
        cardNumberLast4: String,
        previousBalanceMinorUnits: Int?,
        newBalanceMinorUnits: Int?,
        currency: String,
        balanceSource: BalanceSource,
        balanceStatus: BalanceStatus,
        note: String?,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.cardID = cardID
        self.merchantID = merchantID
        self.cardDisplayName = cardDisplayName
        self.cardNumberLast4 = cardNumberLast4
        self.previousBalanceMinorUnits = previousBalanceMinorUnits
        self.newBalanceMinorUnits = newBalanceMinorUnits
        self.currency = currency
        self.balanceSourceRaw = balanceSource.rawValue
        self.balanceStatusRaw = balanceStatus.rawValue
        self.note = note
        self.createdAt = createdAt
    }
}

extension StoredCard {
    var barcodeFormat: BarcodeFormat {
        get { BarcodeFormat(rawValue: barcodeFormatRaw) ?? .code128 }
        set { barcodeFormatRaw = newValue.rawValue }
    }

    var balanceSource: BalanceSource {
        get { BalanceSource(rawValue: balanceSourceRaw) ?? .unknown }
        set { balanceSourceRaw = newValue.rawValue }
    }

    var balanceStatus: BalanceStatus {
        get { BalanceStatus(rawValue: balanceStatusRaw) ?? .missing }
        set { balanceStatusRaw = newValue.rawValue }
    }

    var summary: CardSummary {
        CardSummary(
            id: id,
            merchantID: merchantID,
            displayName: displayName,
            cardNumberLast4: cardNumberLast4,
            currentBalanceMinorUnits: currentBalanceMinorUnits,
            currency: currency,
            balanceStatus: balanceStatus,
            lastBalanceUpdateAt: lastBalanceUpdateAt
        )
    }

    func hasBalanceRefreshConsent(providerID: String, version: String) -> Bool {
        balanceRefreshConsentProviderID == providerID &&
            balanceRefreshConsentVersion == version &&
            balanceRefreshConsentGrantedAt != nil
    }
}

extension BalanceAdjustment {
    var balanceSource: BalanceSource {
        get { BalanceSource(rawValue: balanceSourceRaw) ?? .unknown }
        set { balanceSourceRaw = newValue.rawValue }
    }

    var balanceStatus: BalanceStatus {
        get { BalanceStatus(rawValue: balanceStatusRaw) ?? .missing }
        set { balanceStatusRaw = newValue.rawValue }
    }

    var statusLabel: String {
        switch balanceStatus {
        case .missing:
            return "Balance cleared"
        case .userEntered:
            return "Manual update"
        case .stale:
            return "Marked stale"
        case .verified:
            return "Verified update"
        case .refreshFailed:
            return "Refresh failed"
        }
    }

    var balanceText: String {
        MoneyFormatter.string(minorUnits: newBalanceMinorUnits, currency: currency)
    }

    var changeText: String {
        switch (previousBalanceMinorUnits, newBalanceMinorUnits) {
        case (.none, .none):
            return "No balance entered"
        case (.none, .some):
            return "Set to \(balanceText)"
        case (.some, .none):
            return "Cleared balance"
        case let (.some(previous), .some(current)):
            let delta = current - previous
            guard delta != 0 else { return "No change" }
            let amount = MoneyFormatter.string(minorUnits: abs(delta), currency: currency)
            return delta > 0 ? "+\(amount)" : "-\(amount)"
        }
    }
}
