import Foundation

enum BarcodeFormat: String, CaseIterable, Codable, Identifiable {
    case qr
    case pdf417
    case aztec
    case code128
    case ean13
    case ean8
    case upce

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .qr: return "QR"
        case .pdf417: return "PDF417"
        case .aztec: return "Aztec"
        case .code128: return "Code 128"
        case .ean13: return "EAN-13"
        case .ean8: return "EAN-8"
        case .upce: return "UPC-E"
        }
    }

    var isRenderableInPhase1: Bool {
        switch self {
        case .qr, .pdf417, .aztec, .code128:
            return true
        case .ean13, .ean8, .upce:
            return false
        }
    }
}

enum BalanceSource: String, Codable {
    case manual
    case unknown
    case merchantLookup
}

enum BalanceStatus: String, Codable {
    case missing
    case userEntered
    case stale
    case verified
    case refreshFailed
}

struct CardSummary: Identifiable, Equatable {
    let id: UUID
    let merchantID: String
    let displayName: String
    let cardNumberLast4: String
    let currentBalanceMinorUnits: Int?
    let currency: String
    let balanceStatus: BalanceStatus
    let lastBalanceUpdateAt: Date?
}

struct CardBalanceTotal: Identifiable, Equatable {
    let currency: String
    let minorUnits: Int

    var id: String { currency }

    var displayText: String {
        MoneyFormatter.string(minorUnits: minorUnits, currency: currency)
    }
}

struct CardBalanceStatusCounts: Equatable {
    let unknownCount: Int
    let staleCount: Int

    var hasAttentionItems: Bool {
        unknownCount > 0 || staleCount > 0
    }

    var displayText: String? {
        var parts: [String] = []
        if unknownCount > 0 {
            parts.append("\(unknownCount) unknown")
        }
        if staleCount > 0 {
            parts.append("\(staleCount) stale")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " / ")
    }
}

enum CardBalanceCalculator {
    static func totals(for cards: [CardSummary]) -> [CardBalanceTotal] {
        var totalsByCurrency: [String: Int] = [:]

        for card in cards {
            guard let balance = card.currentBalanceMinorUnits else { continue }
            totalsByCurrency[card.currency.uppercased(), default: 0] += balance
        }

        return totalsByCurrency
            .map { CardBalanceTotal(currency: $0.key, minorUnits: $0.value) }
            .sorted { $0.currency < $1.currency }
    }

    static func displayText(for cards: [CardSummary]) -> String? {
        let totals = totals(for: cards)
        guard !totals.isEmpty else { return nil }
        return totals.map(\.displayText).joined(separator: " + ")
    }

    static func statusCounts(for cards: [CardSummary]) -> CardBalanceStatusCounts {
        var unknownCount = 0
        var staleCount = 0

        for card in cards {
            if card.currentBalanceMinorUnits == nil || card.balanceStatus == .missing {
                unknownCount += 1
            }
            if card.balanceStatus == .stale || card.balanceStatus == .refreshFailed {
                staleCount += 1
            }
        }

        return CardBalanceStatusCounts(unknownCount: unknownCount, staleCount: staleCount)
    }
}

struct CardCreateInput: Equatable {
    var merchantID: String
    var displayName: String
    var cardNumber: String
    var pin: String?
    var barcodeValue: String
    var barcodeFormat: BarcodeFormat
    var startingBalanceMinorUnits: Int?
    var currency: String
}

struct CardSecrets: Equatable {
    var cardNumber: String
    var pin: String?
    var barcodeValue: String
}

struct ScannedBarcode: Equatable {
    var value: String
    var format: BarcodeFormat
}

struct ValidationResult: Equatable {
    var isValid: Bool
    var message: String?

    static let valid = ValidationResult(isValid: true, message: nil)
}
