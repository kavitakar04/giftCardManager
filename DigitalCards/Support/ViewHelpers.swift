import SwiftUI
import UIKit

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let red: Double
        let green: Double
        let blue: Double

        if cleaned.count == 6 {
            red = Double((value >> 16) & 0xFF) / 255
            green = Double((value >> 8) & 0xFF) / 255
            blue = Double(value & 0xFF) / 255
        } else {
            red = 0.25
            green = 0.25
            blue = 0.25
        }

        self.init(red: red, green: green, blue: blue)
    }
}

extension Date {
    var shortDisplay: String {
        formatted(date: .abbreviated, time: .shortened)
    }
}

struct ErrorMessage: Identifiable {
    let id = UUID()
    let text: String
}

enum InputSanitizer {
    static func displayName(_ value: String) -> String {
        let singleLine = value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        let filtered = String(singleLine.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) })
        let collapsed = filtered.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return String(collapsed.prefix(48))
    }

    static func cardNumber(_ value: String) -> String {
        code(value, allowedPunctuation: " -", maxLength: 64)
    }

    static func pin(_ value: String) -> String {
        code(value, allowedPunctuation: " -", maxLength: 32)
    }

    static func barcodeValue(_ value: String) -> String {
        let singleLine = value
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
        let printable = singleLine.unicodeScalars.filter { scalar in
            scalar.value >= 32 && scalar.value <= 126
        }
        return String(String.UnicodeScalarView(printable)).limited(to: 128)
    }

    static func balance(_ value: String) -> String {
        var result = ""
        var hasDecimal = false
        var wholeDigits = 0
        var fractionDigits = 0

        for character in value {
            if character == "." {
                guard !hasDecimal else { continue }
                hasDecimal = true
                result.append(character)
                continue
            }

            guard character.isNumber else { continue }
            if hasDecimal {
                guard fractionDigits < 2 else { continue }
                fractionDigits += 1
            } else {
                guard wholeDigits < 9 else { continue }
                wholeDigits += 1
            }
            result.append(character)
        }

        return result
    }

    static func currency(_ value: String) -> String {
        let letters = value.uppercased().unicodeScalars.filter { scalar in
            scalar.value >= 65 && scalar.value <= 90
        }
        return String(String.UnicodeScalarView(letters)).limited(to: 3)
    }

    private static func code(_ value: String, allowedPunctuation: String, maxLength: Int) -> String {
        let punctuation = Set(allowedPunctuation.unicodeScalars)
        let scalars = value.unicodeScalars.filter { scalar in
            isASCIIAlphanumeric(scalar) || punctuation.contains(scalar)
        }
        return String(String.UnicodeScalarView(scalars)).limited(to: maxLength)
    }

    private static func isASCIIAlphanumeric(_ scalar: UnicodeScalar) -> Bool {
        (scalar.value >= 48 && scalar.value <= 57)
            || (scalar.value >= 65 && scalar.value <= 90)
            || (scalar.value >= 97 && scalar.value <= 122)
    }
}

private extension String {
    func limited(to maxLength: Int) -> String {
        String(prefix(maxLength))
    }
}
