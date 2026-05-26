import CryptoKit
import Foundation

enum EncryptionError: Error, LocalizedError {
    case invalidCiphertext

    var errorDescription: String? {
        switch self {
        case .invalidCiphertext:
            return "The encrypted value could not be read."
        }
    }
}

struct EncryptionService {
    private let key: SymmetricKey

    init(keyStore: SymmetricKeyStore) throws {
        self.key = SymmetricKey(data: try keyStore.loadOrCreateKey())
    }

    func encrypt(_ plaintext: String) throws -> Data {
        let data = Data(plaintext.utf8)
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let combined = sealedBox.combined else {
            throw EncryptionError.invalidCiphertext
        }
        return combined
    }

    func decrypt(_ ciphertext: Data) throws -> String {
        let sealedBox = try AES.GCM.SealedBox(combined: ciphertext)
        let data = try AES.GCM.open(sealedBox, using: key)
        guard let string = String(data: data, encoding: .utf8) else {
            throw EncryptionError.invalidCiphertext
        }
        return string
    }
}
