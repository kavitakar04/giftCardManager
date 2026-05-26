import Foundation
import Security

enum KeychainError: Error, LocalizedError {
    case unexpectedStatus(OSStatus)
    case invalidData

    var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status):
            return "Keychain returned status \(status)."
        case .invalidData:
            return "Keychain returned invalid key data."
        }
    }
}

protocol SymmetricKeyStore {
    func loadOrCreateKey() throws -> Data
}

final class KeychainKeyStore: SymmetricKeyStore {
    private let service = "com.digitalcards.encryption"
    private let account = "card-field-key"

    func loadOrCreateKey() throws -> Data {
        if let existing = try loadKey() {
            return existing
        }

        var key = Data(count: 32)
        let status = key.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, 32, buffer.baseAddress!)
        }
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }

        try saveKey(key)
        return key
    }

    private func loadKey() throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
        guard let data = item as? Data, data.count == 32 else {
            throw KeychainError.invalidData
        }
        return data
    }

    private func saveKey(_ key: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: key
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}

struct InMemoryKeyStore: SymmetricKeyStore {
    let key: Data

    func loadOrCreateKey() throws -> Data {
        key
    }
}
