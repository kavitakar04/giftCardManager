import XCTest
@testable import DigitalCards

final class MoneyFormatterTests: XCTestCase {
    func testMinorUnitsParsing() {
        XCTAssertEqual(MoneyFormatter.minorUnits(from: "$18.42"), 1842)
        XCTAssertEqual(MoneyFormatter.minorUnits(from: "0"), 0)
        XCTAssertNil(MoneyFormatter.minorUnits(from: "-1"))
        XCTAssertNil(MoneyFormatter.minorUnits(from: "abc"))
    }

    func testLast4() {
        XCTAssertEqual(MoneyFormatter.last4("1234 5678 9012"), "9012")
    }

    func testBalanceTotalsGroupByCurrencyAndIgnoreUnknownBalances() {
        let cards = [
            makeSummary(balance: 2500, currency: "usd"),
            makeSummary(balance: 750, currency: "USD"),
            makeSummary(balance: nil, currency: "USD"),
            makeSummary(balance: 1200, currency: "CAD")
        ]

        XCTAssertEqual(
            CardBalanceCalculator.totals(for: cards),
            [
                CardBalanceTotal(currency: "CAD", minorUnits: 1200),
                CardBalanceTotal(currency: "USD", minorUnits: 3250)
            ]
        )
    }

    private func makeSummary(balance: Int?, currency: String) -> CardSummary {
        CardSummary(
            id: UUID(),
            merchantID: "merchant",
            displayName: "Gift Card",
            cardNumberLast4: "1234",
            currentBalanceMinorUnits: balance,
            currency: currency,
            balanceStatus: balance == nil ? .missing : .userEntered,
            lastBalanceUpdateAt: nil
        )
    }
}
