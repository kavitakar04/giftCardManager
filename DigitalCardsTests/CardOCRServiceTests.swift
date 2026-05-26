import XCTest
@testable import DigitalCards

final class CardOCRServiceTests: XCTestCase {
    func testDetectsMerchantCardNumberAndPIN() {
        let service = CardOCRService()

        let result = service.recognize(
            textBlocks: [
                "Subway Gift Card",
                "Card Number 6011 2345 6789 0123",
                "PIN 9876",
                "Call 1-800-555-1212 for support"
            ],
            barcode: nil,
            catalog: .phase1
        )

        XCTAssertEqual(result.merchantCandidates.first?.merchantID, "subway")
        XCTAssertEqual(result.cardNumberCandidates.first?.value, "6011234567890123")
        XCTAssertEqual(result.pinCandidates.first?.value, "9876")
        XCTAssertFalse(result.cardNumberCandidates.contains { $0.value == "18005551212" })
    }

    func testBarcodeBecomesHighConfidenceCardCandidate() {
        let service = CardOCRService()

        let result = service.recognize(
            textBlocks: ["Target GiftCard"],
            barcode: ScannedBarcode(value: "1234567890123456", format: .code128),
            catalog: .phase1
        )

        XCTAssertEqual(result.merchantCandidates.first?.merchantID, "target")
        XCTAssertEqual(result.cardNumberCandidates.first?.value, "1234567890123456")
        XCTAssertEqual(result.barcode?.format, .code128)
    }

    func testDetectsExpandedMerchantAlias() {
        let service = CardOCRService()

        let result = service.recognize(
            textBlocks: [
                "Dunkin Donuts Gift Card",
                "Card Number 1234 5678 9012 3456"
            ],
            barcode: nil,
            catalog: .phase1
        )

        XCTAssertEqual(result.merchantCandidates.first?.merchantID, "dunkin")
    }

    func testUnknownMerchantFallsBackToOther() {
        let service = CardOCRService()

        let result = service.recognize(
            textBlocks: ["Thank you", "Card 9999 8888 7777 6666"],
            barcode: nil,
            catalog: .phase1
        )

        XCTAssertEqual(result.merchantCandidates.first?.merchantID, "other")
    }
}
