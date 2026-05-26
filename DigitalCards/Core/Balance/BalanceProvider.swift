import Foundation

enum BalanceLookupCapability: String, Codable {
    case manualOnly
    case officialWeb
    case backendAuto
}

enum BalanceCredentialField: String, Codable, Identifiable {
    case cardNumber
    case pin
    case accessCode
    case claimCode
    case accountLogin

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cardNumber:
            return "Card Number"
        case .pin:
            return "PIN"
        case .accessCode:
            return "Access Number/PIN"
        case .claimCode:
            return "Claim Code"
        case .accountLogin:
            return "Merchant Account"
        }
    }

    func storedValue(from secrets: CardSecrets) -> String? {
        switch self {
        case .cardNumber:
            return secrets.cardNumber
        case .pin, .accessCode:
            return secrets.pin
        case .claimCode:
            return secrets.cardNumber
        case .accountLogin:
            return nil
        }
    }
}

struct BalanceLookupDescriptor: Equatable {
    let providerID: String
    let displayLabel: String
    let capability: BalanceLookupCapability
    let officialURL: URL?
    let requiredFields: [BalanceCredentialField]
    let supportsRememberedConsent: Bool
    let userGuidance: String
}

extension BalanceLookupDescriptor {
    static let manualOnly = BalanceLookupDescriptor(
        providerID: "manual-only",
        displayLabel: "Manual balance entry",
        capability: .manualOnly,
        officialURL: nil,
        requiredFields: [],
        supportsRememberedConsent: false,
        userGuidance: "This merchant does not have a configured balance lookup. Enter the balance manually after checking it with the merchant."
    )

    static let subwayOfficialWeb = BalanceLookupDescriptor(
        providerID: "subway-official-web",
        displayLabel: "Subway balance inquiry",
        capability: .officialWeb,
        officialURL: URL(string: "https://www.subway.com/en-us/subwaycard?id=home"),
        requiredFields: [.cardNumber, .pin],
        supportsRememberedConsent: false,
        userGuidance: "Use Subway's official balance inquiry. Copy the card number and PIN after authentication, then enter them on Subway's site."
    )

    static let starbucksOfficialWeb = BalanceLookupDescriptor(
        providerID: "starbucks-official-web",
        displayLabel: "Starbucks card management",
        capability: .officialWeb,
        officialURL: URL(string: "https://www.starbucks.com/card"),
        requiredFields: [.accountLogin],
        supportsRememberedConsent: false,
        userGuidance: "Sign in to Starbucks or add the card to your Starbucks account to review the card balance through the official card flow."
    )

    static let targetOfficialWeb = BalanceLookupDescriptor(
        providerID: "target-official-web",
        displayLabel: "Target GiftCard balance",
        capability: .officialWeb,
        officialURL: URL(string: "https://www.target.com/giftcard/check-balance"),
        requiredFields: [.cardNumber, .accessCode],
        supportsRememberedConsent: false,
        userGuidance: "Use Target's official GiftCard balance page. Target asks for the 15-digit card number and the Access Number or PIN."
    )

    static let amazonOfficialWeb = BalanceLookupDescriptor(
        providerID: "amazon-official-web",
        displayLabel: "Amazon gift card balance",
        capability: .officialWeb,
        officialURL: URL(string: "https://www.amazon.com/gc/balance"),
        requiredFields: [.accountLogin],
        supportsRememberedConsent: false,
        userGuidance: "Amazon gift card balance is account based after redemption. Sign in to Amazon to view your gift card balance or redeem a claim code."
    )
}

struct BalanceResult: Equatable {
    let minorUnits: Int?
    let currency: String
    let status: BalanceStatus
    let checkedAt: Date?
    let providerMessage: String?
}

protocol BalanceProvider {
    var merchantID: String { get }
    var descriptor: BalanceLookupDescriptor { get }
    var supportsAutoRefresh: Bool { get }
    func checkBalance(card: StoredCard) async throws -> BalanceResult
}

struct ManualBalanceProvider: BalanceProvider {
    let merchantID: String
    let descriptor = BalanceLookupDescriptor.manualOnly
    let supportsAutoRefresh = false

    func checkBalance(card: StoredCard) async throws -> BalanceResult {
        BalanceResult(
            minorUnits: card.currentBalanceMinorUnits,
            currency: card.currency,
            status: card.balanceStatus,
            checkedAt: card.lastBalanceUpdateAt,
            providerMessage: card.lastBalanceCheckStatusMessage
        )
    }
}

struct BalanceCredentialDisplayValue: Identifiable, Equatable {
    let field: BalanceCredentialField
    let value: String?

    var id: String { field.rawValue }
    var canCopy: Bool { value?.isEmpty == false }
}

struct BalanceOfficialWebContext: Identifiable {
    let id = UUID()
    let merchantDisplayName: String
    let descriptor: BalanceLookupDescriptor
    let credentialValues: [BalanceCredentialDisplayValue]
}

enum BalanceCheckStatus: String, Codable, Equatable {
    case verified
    case refreshFailed = "refresh_failed"
    case unsupportedAutoRefresh = "unsupported_auto_refresh"
}

struct BalanceCheckResponse: Codable, Equatable {
    let balanceMinorUnits: Int?
    let currency: String
    let status: BalanceCheckStatus
    let checkedAt: Date
    let providerMessage: String

    enum CodingKeys: String, CodingKey {
        case balanceMinorUnits = "balance_minor_units"
        case currency
        case status
        case checkedAt = "checked_at"
        case providerMessage = "provider_message"
    }
}

private struct BalanceCheckRequest: Codable {
    let merchantID: String
    let providerID: String
    let cardNumber: String
    let pin: String?
    let accessCode: String?
    let claimCode: String?
    let consentToken: String?
    let consentVersion: String?

    enum CodingKeys: String, CodingKey {
        case merchantID = "merchant_id"
        case providerID = "provider_id"
        case cardNumber = "card_number"
        case pin
        case accessCode = "access_code"
        case claimCode = "claim_code"
        case consentToken = "consent_token"
        case consentVersion = "consent_version"
    }
}

enum BalanceLookupError: Error, LocalizedError {
    case unsupportedManualOnly
    case missingOfficialURL
    case unsupportedAutoRefresh(String)
    case invalidResponse
    case providerFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedManualOnly:
            return "This merchant only supports manual balance entry."
        case .missingOfficialURL:
            return "No official balance lookup page is configured for this merchant."
        case .unsupportedAutoRefresh(let message), .providerFailed(let message):
            return message
        case .invalidResponse:
            return "The balance lookup service returned an invalid response."
        }
    }
}

struct BalanceLookupService {
    let baseURL: URL
    let session: URLSession
    let consentVersion = "2026-05-26"

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func descriptor(for merchant: Merchant) -> BalanceLookupDescriptor {
        merchant.balanceLookup
    }

    func officialWebContext(
        for card: StoredCard,
        merchant: Merchant,
        secrets: CardSecrets
    ) throws -> BalanceOfficialWebContext {
        let descriptor = descriptor(for: merchant)
        guard descriptor.capability == .officialWeb else {
            throw BalanceLookupError.unsupportedManualOnly
        }
        guard descriptor.officialURL != nil else {
            throw BalanceLookupError.missingOfficialURL
        }

        let credentialValues = descriptor.requiredFields.map {
            BalanceCredentialDisplayValue(field: $0, value: $0.storedValue(from: secrets))
        }

        return BalanceOfficialWebContext(
            merchantDisplayName: merchant.displayName,
            descriptor: descriptor,
            credentialValues: credentialValues
        )
    }

    func checkBackendBalance(
        merchant: Merchant,
        secrets: CardSecrets,
        consentToken: String?,
        consentVersion: String?
    ) async throws -> BalanceCheckResponse {
        let descriptor = descriptor(for: merchant)
        guard descriptor.capability == .backendAuto else {
            throw BalanceLookupError.unsupportedAutoRefresh("Automatic balance refresh is not available for \(merchant.displayName).")
        }

        let requestBody = BalanceCheckRequest(
            merchantID: merchant.id,
            providerID: descriptor.providerID,
            cardNumber: secrets.cardNumber,
            pin: descriptor.requiredFields.contains(.pin) ? secrets.pin : nil,
            accessCode: descriptor.requiredFields.contains(.accessCode) ? secrets.pin : nil,
            claimCode: descriptor.requiredFields.contains(.claimCode) ? secrets.cardNumber : nil,
            consentToken: consentToken,
            consentVersion: consentVersion
        )

        var request = URLRequest(url: baseURL.appending(path: "/api/balance/check"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(requestBody)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BalanceLookupError.invalidResponse
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer().decode(String.self)
            let fractionalFormatter = ISO8601DateFormatter()
            fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractionalFormatter.date(from: value) {
                return date
            }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: value) {
                return date
            }
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid ISO8601 date.")
            )
        }

        if (200..<300).contains(httpResponse.statusCode) {
            return try decoder.decode(BalanceCheckResponse.self, from: data)
        }

        if let errorResponse = try? decoder.decode(BalanceErrorResponse.self, from: data) {
            throw BalanceLookupError.providerFailed(errorResponse.error)
        }
        throw BalanceLookupError.providerFailed("Balance refresh failed.")
    }
}

private struct BalanceErrorResponse: Codable {
    let error: String
}
