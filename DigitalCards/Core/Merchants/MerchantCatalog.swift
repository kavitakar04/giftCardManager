import Foundation

enum MerchantCategory: String, Codable, CaseIterable, Identifiable {
    case foodAndCoffee
    case restaurants
    case retail
    case beautyAndApparel
    case entertainment
    case prepaid
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .foodAndCoffee: return "Food & Coffee"
        case .restaurants: return "Restaurants"
        case .retail: return "Retail"
        case .beautyAndApparel: return "Beauty & Apparel"
        case .entertainment: return "Entertainment"
        case .prepaid: return "Prepaid"
        case .other: return "Other"
        }
    }
}

struct Merchant: Identifiable, Equatable {
    let id: String
    let displayName: String
    let category: MerchantCategory
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
        category: .other,
        aliases: ["GIFT CARD", "CARD"],
        brandColorHex: "#4B5563",
        supportedBarcodeFormats: [.qr, .pdf417, .aztec, .code128],
        requiresPin: false,
        defaultCurrency: "USD",
        balanceLookup: .manualOnly,
        redemptionNotes: "Save the barcode and card details for manual redemption.",
        supportURL: nil
    )

    private static func merchant(
        id: String,
        displayName: String,
        category: MerchantCategory,
        aliases: [String],
        brandColorHex: String,
        supportedBarcodeFormats: [BarcodeFormat] = [.code128, .qr],
        requiresPin: Bool = true,
        redemptionNotes: String
    ) -> Merchant {
        Merchant(
            id: id,
            displayName: displayName,
            category: category,
            aliases: aliases,
            brandColorHex: brandColorHex,
            supportedBarcodeFormats: supportedBarcodeFormats,
            requiresPin: requiresPin,
            defaultCurrency: "USD",
            balanceLookup: .manualOnly,
            redemptionNotes: redemptionNotes,
            supportURL: nil
        )
    }

    static let phase1 = MerchantCatalog(merchants: [
        merchant(
            id: "dunkin",
            displayName: "Dunkin'",
            category: .foodAndCoffee,
            aliases: ["DUNKIN", "DUNKIN DONUTS", "DUNKIN GIFT CARD"],
            brandColorHex: "#FF671F",
            supportedBarcodeFormats: [.qr, .code128],
            redemptionNotes: "Show barcode in store or enter card details where supported. Good fit for users who have a physical card but do not actively manage it in the Dunkin' app."
        ),
        merchant(
            id: "subway",
            displayName: "Subway",
            category: .foodAndCoffee,
            aliases: ["SUBWAY", "SUBWAY GIFT CARD", "MY SUBWAY CARD"],
            brandColorHex: "#008938",
            redemptionNotes: "Show barcode in store or use card details online. Strong Phase 1 test merchant because many users may have physical cards without managing them in an app."
        ),
        merchant(
            id: "chipotle",
            displayName: "Chipotle",
            category: .foodAndCoffee,
            aliases: ["CHIPOTLE", "CHIPOTLE GIFT CARD", "CHIPOTLE MEXICAN GRILL"],
            brandColorHex: "#A81612",
            redemptionNotes: "Show barcode in store or enter card details online. Useful for physical cards that are not already added to a Chipotle account."
        ),
        merchant(
            id: "target",
            displayName: "Target",
            category: .retail,
            aliases: ["TARGET", "TARGET GIFT CARD", "TARGET GIFTCARD", "TARGETCARD"],
            brandColorHex: "#CC0000",
            redemptionNotes: "Show barcode in store or enter card number and access code online."
        ),
        merchant(
            id: "walmart",
            displayName: "Walmart",
            category: .retail,
            aliases: ["WALMART", "WALMART GIFT CARD", "WAL-MART"],
            brandColorHex: "#0071CE",
            redemptionNotes: "Use in store or online with card number and PIN. Strong fit because many users hold physical cards without actively tracking the balance."
        ),
        merchant(
            id: "homedepot",
            displayName: "Home Depot",
            category: .retail,
            aliases: ["HOME DEPOT", "THE HOME DEPOT", "HOME DEPOT GIFT CARD"],
            brandColorHex: "#F96302",
            redemptionNotes: "Show barcode in store or use card details online. Good fit for high-value cards that users may not spend immediately."
        ),
        merchant(
            id: "bestbuy",
            displayName: "Best Buy",
            category: .retail,
            aliases: ["BEST BUY", "BEST BUY GIFT CARD"],
            brandColorHex: "#0046BE",
            redemptionNotes: "Show barcode in store or enter card number and PIN online."
        ),
        merchant(
            id: "sephora",
            displayName: "Sephora",
            category: .beautyAndApparel,
            aliases: ["SEPHORA", "SEPHORA GIFT CARD"],
            brandColorHex: "#000000",
            redemptionNotes: "Show barcode in store or enter card details online."
        ),
        merchant(
            id: "ulta",
            displayName: "Ulta Beauty",
            category: .beautyAndApparel,
            aliases: ["ULTA", "ULTA BEAUTY", "ULTA GIFT CARD", "ULTA BEAUTY GIFT CARD"],
            brandColorHex: "#E4007C",
            redemptionNotes: "Show barcode in store or use card number and PIN online."
        ),
        merchant(
            id: "olivegarden",
            displayName: "Olive Garden",
            category: .restaurants,
            aliases: ["OLIVE GARDEN", "OLIVE GARDEN GIFT CARD"],
            brandColorHex: "#5B7F2A",
            redemptionNotes: "Show barcode in restaurant or enter card details online where supported. Common gift-card use case where users may not have a dedicated app."
        ),
        merchant(
            id: "amc",
            displayName: "AMC Theatres",
            category: .entertainment,
            aliases: ["AMC", "AMC THEATRES", "AMC THEATERS", "AMC GIFT CARD"],
            brandColorHex: "#D71920",
            supportedBarcodeFormats: [.qr, .code128],
            redemptionNotes: "Show barcode at checkout or enter card details online. Useful for occasional-use entertainment cards."
        ),
        merchant(
            id: "starbucks",
            displayName: "Starbucks",
            category: .foodAndCoffee,
            aliases: ["STARBUCKS", "STARBUCKS CARD", "STARBUCKS GIFT CARD"],
            brandColorHex: "#006241",
            supportedBarcodeFormats: [.qr, .code128],
            requiresPin: false,
            redemptionNotes: "Show barcode in store or use card number in the Starbucks app. Many users may already manage Starbucks cards in the merchant app, so this is useful mainly for physical-card storage."
        ),
        merchant(
            id: "chickfila",
            displayName: "Chick-fil-A",
            category: .foodAndCoffee,
            aliases: ["CHICK FIL A", "CHICK-FIL-A", "CHICKFILA", "CHICK FIL A GIFT CARD"],
            brandColorHex: "#E51636",
            supportedBarcodeFormats: [.qr, .code128],
            requiresPin: false,
            redemptionNotes: "Show code in store or add to the merchant app where supported."
        ),
        merchant(
            id: "panera",
            displayName: "Panera Bread",
            category: .foodAndCoffee,
            aliases: ["PANERA", "PANERA BREAD", "PANERA GIFT CARD"],
            brandColorHex: "#5F3B1D",
            redemptionNotes: "Show barcode in store or use card details online. Useful for stored physical gift cards and manual balance tracking."
        ),
        merchant(
            id: "mcdonalds",
            displayName: "McDonald's",
            category: .foodAndCoffee,
            aliases: ["MCDONALDS", "MCDONALD'S", "MC DONALDS", "MCDONALDS GIFT CARD", "ARCH CARD"],
            brandColorHex: "#DA291C",
            supportedBarcodeFormats: [.qr, .code128],
            requiresPin: false,
            redemptionNotes: "Show code in store where accepted or use card details through supported redemption flows."
        ),
        merchant(
            id: "cheesecakefactory",
            displayName: "The Cheesecake Factory",
            category: .restaurants,
            aliases: ["CHEESECAKE FACTORY", "THE CHEESECAKE FACTORY", "CHEESECAKE FACTORY GIFT CARD"],
            brandColorHex: "#6B4E16",
            redemptionNotes: "Show barcode or provide card details at checkout. Useful for occasional-use restaurant cards."
        ),
        merchant(
            id: "texasroadhouse",
            displayName: "Texas Roadhouse",
            category: .restaurants,
            aliases: ["TEXAS ROADHOUSE", "TEXAS ROADHOUSE GIFT CARD"],
            brandColorHex: "#8B1E1E",
            redemptionNotes: "Show barcode or enter card details where supported. Good fit for physical restaurant gift cards."
        ),
        merchant(
            id: "dominos",
            displayName: "Domino's",
            category: .restaurants,
            aliases: ["DOMINOS", "DOMINO'S", "DOMINOS PIZZA", "DOMINO'S PIZZA", "DOMINOS GIFT CARD"],
            brandColorHex: "#006491",
            redemptionNotes: "Use card details online or in store where supported. Useful for users who receive a card but do not keep it in a merchant app."
        ),
        merchant(
            id: "amazon",
            displayName: "Amazon",
            category: .retail,
            aliases: ["AMAZON", "AMAZON.COM", "AMAZON GIFT CARD", "AMAZON.COM GIFT CARD"],
            brandColorHex: "#FF9900",
            requiresPin: false,
            redemptionNotes: "Redeem to Amazon balance using the claim code. Amazon cards are common, but they are usually redeemed into an account rather than repeatedly scanned."
        ),
        merchant(
            id: "lowes",
            displayName: "Lowe's",
            category: .retail,
            aliases: ["LOWES", "LOWE'S", "LOWES GIFT CARD", "LOWE'S GIFT CARD"],
            brandColorHex: "#004990",
            redemptionNotes: "Show barcode in store or use card details online. Useful for home improvement cards that may sit unused for a long time."
        ),
        merchant(
            id: "nike",
            displayName: "Nike",
            category: .beautyAndApparel,
            aliases: ["NIKE", "NIKE GIFT CARD"],
            brandColorHex: "#111111",
            redemptionNotes: "Use in store or online with card details where supported."
        ),
        merchant(
            id: "macys",
            displayName: "Macy's",
            category: .beautyAndApparel,
            aliases: ["MACYS", "MACY'S", "MACYS GIFT CARD", "MACY'S GIFT CARD"],
            brandColorHex: "#E21A2C",
            redemptionNotes: "Show barcode in store or enter card details online. Good fit for traditional physical gift-card users."
        ),
        merchant(
            id: "nordstrom",
            displayName: "Nordstrom",
            category: .beautyAndApparel,
            aliases: ["NORDSTROM", "NORDSTROM GIFT CARD"],
            brandColorHex: "#111111",
            redemptionNotes: "Use in store or online with card details where supported."
        ),
        merchant(
            id: "playstation",
            displayName: "PlayStation",
            category: .entertainment,
            aliases: ["PLAYSTATION", "PLAYSTATION STORE", "PLAYSTATION GIFT CARD", "PSN", "PSN CARD"],
            brandColorHex: "#003791",
            requiresPin: false,
            redemptionNotes: "Store the claim code for later redemption. These are usually redeemed into an account rather than scanned repeatedly."
        ),
        merchant(
            id: "xbox",
            displayName: "Xbox",
            category: .entertainment,
            aliases: ["XBOX", "XBOX GIFT CARD", "MICROSOFT XBOX", "MICROSOFT GIFT CARD"],
            brandColorHex: "#107C10",
            requiresPin: false,
            redemptionNotes: "Store the claim code for later redemption. These are usually redeemed into an account rather than scanned repeatedly."
        ),
        merchant(
            id: "visa_prepaid",
            displayName: "Visa Prepaid",
            category: .prepaid,
            aliases: ["VISA PREPAID", "VISA GIFT CARD", "VISA REWARD CARD", "VISA DEBIT GIFT CARD"],
            brandColorHex: "#1A1F71",
            redemptionNotes: "Store card details for reference. Open-loop prepaid cards may not be scannable like merchant gift cards and may need to be used as payment cards."
        ),
        merchant(
            id: "mastercard_prepaid",
            displayName: "Mastercard Prepaid",
            category: .prepaid,
            aliases: ["MASTERCARD PREPAID", "MASTERCARD GIFT CARD", "MASTERCARD REWARD CARD", "MASTER CARD GIFT CARD"],
            brandColorHex: "#EB001B",
            redemptionNotes: "Store card details for reference. Open-loop prepaid cards may not be scannable like merchant gift cards and may need to be used as payment cards."
        ),
        Self.other
    ])
}
