import XCTest
@testable import DigitalCards

final class EncryptionServiceTests: XCTestCase {
    func testEncryptDecryptRoundTrip() throws {
        let service = try EncryptionService(keyStore: InMemoryKeyStore(key: Data(repeating: 7, count: 32)))

        let ciphertext = try service.encrypt("1234567890123456")
        let plaintext = try service.decrypt(ciphertext)

        XCTAssertNotEqual(ciphertext, Data("1234567890123456".utf8))
        XCTAssertEqual(plaintext, "1234567890123456")
    }

    func testDecryptWithWrongKeyFails() throws {
        let service = try EncryptionService(keyStore: InMemoryKeyStore(key: Data(repeating: 1, count: 32)))
        let wrongService = try EncryptionService(keyStore: InMemoryKeyStore(key: Data(repeating: 2, count: 32)))

        let ciphertext = try service.encrypt("9999")

        XCTAssertThrowsError(try wrongService.decrypt(ciphertext))
    }
}
