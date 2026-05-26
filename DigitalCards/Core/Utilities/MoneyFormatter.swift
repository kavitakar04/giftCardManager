import Foundation

enum MoneyFormatter {
    static func string(minorUnits: Int?, currency: String) -> String {
        guard let minorUnits else {
            return "Balance not entered"
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        let amount = Decimal(minorUnits) / Decimal(100)
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "\(currency) \(amount)"
    }

    static func minorUnits(from text: String) -> Int? {
        let filtered = text
            .filter { $0.isNumber || $0 == "." || $0 == "-" }
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !filtered.isEmpty, let decimal = Decimal(string: filtered), decimal >= 0 else {
            return nil
        }

        var cents = decimal * Decimal(100)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &cents, 0, .plain)
        return NSDecimalNumber(decimal: rounded).intValue
    }

    static func last4(_ value: String) -> String {
        let cleaned = value.filter { !$0.isWhitespace }
        return String(cleaned.suffix(4))
    }
}
