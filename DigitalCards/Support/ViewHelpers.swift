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
