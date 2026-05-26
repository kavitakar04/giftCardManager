import XCTest
@testable import DigitalCards

final class BarcodeServiceTests: XCTestCase {
    func testRenderableFormatsValidate() {
        let service = CoreImageBarcodeService()

        XCTAssertTrue(service.validate(value: "123456", format: .qr).isValid)
        XCTAssertTrue(service.validate(value: "123456", format: .pdf417).isValid)
        XCTAssertTrue(service.validate(value: "123456", format: .aztec).isValid)
        XCTAssertTrue(service.validate(value: "123456", format: .code128).isValid)
    }

    func testScanOnlyFormatsDoNotValidateForRendering() {
        let service = CoreImageBarcodeService()

        XCTAssertFalse(service.validate(value: "1234567890123", format: .ean13).isValid)
        XCTAssertFalse(service.validate(value: "", format: .qr).isValid)
    }
}
