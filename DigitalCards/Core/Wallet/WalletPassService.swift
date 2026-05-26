import Foundation
import PassKit
import SwiftUI
import UIKit

struct PassRequest: Codable, Equatable {
    let serialNumber: String
    let merchantDisplayName: String
    let cardNumberLast4: String
    let pin: String?
    let barcodeValue: String
    let barcodeFormat: BarcodeFormat
    let currentBalanceMinorUnits: Int?
    let currency: String
    let lastBalanceUpdateAt: Date?
    let redemptionNotes: String

    enum CodingKeys: String, CodingKey {
        case serialNumber = "serial_number"
        case merchantDisplayName = "merchant_display_name"
        case cardNumberLast4 = "card_number_last4"
        case pin
        case barcodeValue = "barcode_value"
        case barcodeFormat = "barcode_format"
        case currentBalanceMinorUnits = "current_balance_minor_units"
        case currency
        case lastBalanceUpdateAt = "last_balance_update_at"
        case redemptionNotes = "redemption_notes"
    }
}

enum WalletPassError: Error, LocalizedError {
    case walletUnavailable
    case invalidResponse
    case signingFailed(String)

    var errorDescription: String? {
        switch self {
        case .walletUnavailable:
            return "Apple Wallet is unavailable on this device."
        case .invalidResponse:
            return "The signing service returned an invalid response."
        case .signingFailed(let message):
            return message
        }
    }
}

struct WalletPassService {
    let baseURL: URL
    let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func buildPassRequest(
        card: StoredCard,
        secrets: CardSecrets,
        merchant: Merchant,
        serialNumber: String
    ) -> PassRequest {
        PassRequest(
            serialNumber: serialNumber,
            merchantDisplayName: merchant.displayName,
            cardNumberLast4: card.cardNumberLast4,
            pin: normalizedPIN(secrets.pin),
            barcodeValue: secrets.barcodeValue,
            barcodeFormat: card.barcodeFormat,
            currentBalanceMinorUnits: card.currentBalanceMinorUnits,
            currency: card.currency,
            lastBalanceUpdateAt: card.lastBalanceUpdateAt,
            redemptionNotes: merchant.redemptionNotes
        )
    }

    private func normalizedPIN(_ pin: String?) -> String? {
        guard let trimmed = pin?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    func requestSignedPass(_ passRequest: PassRequest) async throws -> Data {
        var request = URLRequest(url: baseURL.appending(path: "/api/wallet/passes"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/vnd.apple.pkpass", forHTTPHeaderField: "Accept")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(passRequest)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WalletPassError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8)
            throw WalletPassError.signingFailed(message ?? "Pass signing failed.")
        }
        return data
    }

    func makePass(from data: Data) throws -> PKPass {
        guard PKAddPassesViewController.canAddPasses() else {
            throw WalletPassError.walletUnavailable
        }
        return try PKPass(data: data)
    }
}

struct AddPassViewController: UIViewControllerRepresentable {
    let pass: PKPass

    func makeUIViewController(context: Context) -> UIViewController {
        PKAddPassesViewController(pass: pass) ?? UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
