import XCTest
@testable import NotifyHubIOS

final class NotificationPayloadTests: XCTestCase {
    func testParsesBothCustomKeys() {
        let payload = NotificationPayload(userInfo: ["channelSlug": "alerts", "notificationId": "n1"])
        XCTAssertEqual(payload?.channelSlug, "alerts")
        XCTAssertEqual(payload?.notificationId, "n1")
    }

    func testNotificationIdIsOptional() {
        let payload = NotificationPayload(userInfo: ["channelSlug": "alerts"])
        XCTAssertEqual(payload?.channelSlug, "alerts")
        XCTAssertNil(payload?.notificationId)
    }

    func testFailsWithoutChannelSlug() {
        XCTAssertNil(NotificationPayload(userInfo: ["notificationId": "n1"]))
        XCTAssertNil(NotificationPayload(userInfo: [:]))
    }

    func testIgnoresNonStringChannelSlug() {
        XCTAssertNil(NotificationPayload(userInfo: ["channelSlug": 42]))
    }
}
