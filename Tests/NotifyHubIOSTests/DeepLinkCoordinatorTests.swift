import XCTest
@testable import NotifyHubIOS

/// The genuine push -> deep-link integration test this app's scope calls
/// for, at the layer that's actually possible to exercise in CI: a real
/// push can't be delivered to a CI simulator (no live APNs credentials -
/// see docs/project-memory/07-decisions.md ADR-002/08-risk.md), but the
/// exact payload notifyhub's `ApnsPushChannel` sends (see notifyhub's
/// `src/services/push/apnsChannel.ts`) can be fed through the same
/// `DeepLinkCoordinator` that `AppDelegate` uses for a real tap in any of
/// the three app states (foreground/background/killed) - they all funnel
/// through this one method.
@MainActor
final class DeepLinkCoordinatorTests: XCTestCase {
    func testHandlesANotificationLevelPushPayload() {
        let coordinator = DeepLinkCoordinator()
        coordinator.handle(userInfo: [
            "aps": ["alert": ["title": "Server down", "body": "Investigating"], "sound": "default"],
            "notificationId": "notif-123",
            "channelSlug": "alerts",
        ])

        XCTAssertEqual(coordinator.pendingRoute, .notification(id: "notif-123", channelSlug: "alerts"))
    }

    func testHandlesAChannelLevelPushPayloadWithoutANotificationId() {
        let coordinator = DeepLinkCoordinator()
        coordinator.handle(userInfo: [
            "aps": ["alert": ["title": "New channel", "body": "Check it out"]],
            "channelSlug": "announcements",
        ])

        XCTAssertEqual(coordinator.pendingRoute, .channel(slug: "announcements"))
    }

    func testIgnoresAPayloadMissingTheChannelSlugContract() {
        let coordinator = DeepLinkCoordinator()
        coordinator.handle(userInfo: [
            "aps": ["alert": ["title": "Malformed", "body": "No channelSlug key"]],
        ])

        XCTAssertNil(coordinator.pendingRoute)
    }

    func testConsumingThePendingRouteClearsIt() {
        let coordinator = DeepLinkCoordinator()
        coordinator.handle(userInfo: ["channelSlug": "alerts", "notificationId": "n1"])

        let consumed = coordinator.consumePendingRoute()

        XCTAssertEqual(consumed, .notification(id: "n1", channelSlug: "alerts"))
        XCTAssertNil(coordinator.pendingRoute)
        XCTAssertNil(coordinator.consumePendingRoute())
    }

    func testASecondPushOverwritesAnUnconsumedRoute() {
        let coordinator = DeepLinkCoordinator()
        coordinator.handle(userInfo: ["channelSlug": "alerts", "notificationId": "first"])
        coordinator.handle(userInfo: ["channelSlug": "billing", "notificationId": "second"])

        XCTAssertEqual(coordinator.pendingRoute, .notification(id: "second", channelSlug: "billing"))
    }
}
