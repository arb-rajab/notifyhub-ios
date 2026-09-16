import XCTest
@testable import NotifyHubIOS

final class JSONCodingTests: XCTestCase {
    private struct Wrapper: Decodable { let date: Date }

    func testDecodesNotifyHubsISO8601WithFractionalSeconds() throws {
        let json = #"{"date":"2026-09-15T21:00:00.000Z"}"#.data(using: .utf8)!
        let wrapper = try JSONDecoder.notifyHub.decode(Wrapper.self, from: json)

        let components = Calendar(identifier: .gregorian).dateComponents(
            in: TimeZone(identifier: "UTC")!,
            from: wrapper.date
        )
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 9)
        XCTAssertEqual(components.day, 15)
        XCTAssertEqual(components.hour, 21)
    }

    func testDecodesWithoutFractionalSecondsAsAFallback() throws {
        let json = #"{"date":"2026-09-15T21:00:00Z"}"#.data(using: .utf8)!
        XCTAssertNoThrow(try JSONDecoder.notifyHub.decode(Wrapper.self, from: json))
    }

    func testThrowsOnAMalformedDateString() {
        let json = #"{"date":"not-a-date"}"#.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder.notifyHub.decode(Wrapper.self, from: json))
    }
}
