import XCTest
@testable import LookAway

final class RandomQuoteTests: XCTestCase {
    func testRandomQuotePreferenceRoundTrips() throws {
        var settings = AppSettings.defaults
        settings.randomBreakQuoteEnabled = true
        let restored = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertTrue(restored.randomBreakQuoteEnabled)
    }

    func testOlderSettingsDefaultRandomQuotesOff() throws {
        let data = Data("{\"breakMessage\":\"Custom\"}".utf8)
        let settings = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertFalse(settings.randomBreakQuoteEnabled)
        XCTAssertEqual(settings.resolvedBreakMessage, "Custom")
    }

    func testRandomQuoteComesFromBuiltInSet() {
        var settings = AppSettings.defaults
        settings.randomBreakQuoteEnabled = true
        for _ in 0..<50 {
            XCTAssertTrue(AppSettings.breakQuotes.contains(settings.resolvedBreakMessage))
        }
    }
}
