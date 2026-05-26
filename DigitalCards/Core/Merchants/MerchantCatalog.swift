import Foundation

struct Merchant: Identifiable, Equatable {
    let id: String
    let displayName: String
    let aliases: [String]
    let brandColorHex: String
    let supportedBarcodeFormats: [BarcodeFormat]
    let requiresPin: Bool
    let defaultCurrency: String
    let balanceLookup: BalanceLookupDescriptor
    let redemptionNotes: String
    let supportURL: URL?
}

struct MerchantCatalog {
    let merchants: [Merchant]

    var all: [Merchant] { merchants }

    func merchant(id: String) -> Merchant {
        merchants.first { $0.id == id } ?? Self.other
    }

    static let other = Merchant(
        id: "other",
        displayName: "Other",
        aliases: ["GIFT CARD", "CARD"],
        brandColorHex: "#4B5563",
        supportedBarcodeFormats: [.qr, .pdf417, .aztec, .code128],
        requiresPin: false,
        defaultCurrency: "USD",
        balanceLookup: .manualOnly,
        redemptionNotes: "Show this barcode in store or use the saved card number for online checkout.",
        supportURL: nil
    )

    static let phase1 = MerchantCatalog(merchants: [
        Merchant(
            id: "subway",
            displayName: "Subway",
            aliases: ["SUBWAY", "SUBWAY GIFT CARD", "MY SUBWAY CARD"],
            brandColorHex: "#008938",
            supportedBarcodeFormats: [.qr, .pdf417, .aztec, .code128],
            requiresPin: true,
            defaultCurrency: "USD",
            balanceLookup: .subwayOfficialWeb,
            redemptionNotes: "Show the barcode in store. Reveal the PIN in the app only when online checkout requires it.",
            supportURL: URL(string: "https://www.subway.com/en-us/subwaycard?id=home")
        ),
        Merchant(
            id: "starbucks",
            displayName: "Starbucks",
            aliases: ["STARBUCKS", "STARBUCKS CARD", "STARBUCKS GIFT CARD"],
            brandColorHex: "#006241",
            supportedBarcodeFormats: [.qr, .code128],
            requiresPin: false,
            defaultCurrency: "USD",
            balanceLookup: .starbucksOfficialWeb,
            redemptionNotes: "Show the barcode in store or copy the card number for checkout.",
            supportURL: URL(string: "https://www.starbucks.com/card")
        ),
        Merchant(
            id: "target",
            displayName: "Target",
            aliases: ["TARGET", "TARGET GIFT CARD", "TARGETCARD"],
            brandColorHex: "#CC0000",
            supportedBarcodeFormats: [.qr, .code128, .pdf417],
            requiresPin: true,
            defaultCurrency: "USD",
            balanceLookup: .targetOfficialWeb,
            redemptionNotes: "Show the barcode in store. Keep the PIN protected in the app.",
            supportURL: URL(string: "https://www.target.com/giftcard/check-balance")
        ),
        Merchant(
            id: "amazon",
            displayName: "Amazon",
            aliases: ["AMAZON", "AMAZON.COM", "AMAZON GIFT CARD", "AMAZON.COM GIFT CARD"],
            brandColorHex: "#FF9900",
            supportedBarcodeFormats: [.qr, .code128],
            requiresPin: false,
            defaultCurrency: "USD",
            balanceLookup: .amazonOfficialWeb,
            redemptionNotes: "Use the saved claim code or card number during online checkout.",
            supportURL: URL(string: "https://www.amazon.com/gc/balance")
        ),
        Self.other
    ])
}
