import Combine
import Foundation

/// Where a push (or an in-app tap) should take the user. `Hashable` so it
/// can be used directly as a `NavigationStack` path element.
enum AppRoute: Hashable {
    case channelList
    case channel(slug: String)
    case notification(id: String, channelSlug: String)
}

/// Turns a raw APNs payload (from any of the three delivery states -
/// foreground presentation, a background/killed-state tap handled by
/// `UNUserNotificationCenterDelegate`, or a killed-state cold launch via
/// `didFinishLaunchingWithOptions`) into an `AppRoute`, and holds the most
/// recent one until a view is ready to consume it.
///
/// This is deliberately the single place that understands the push
/// payload shape - `AppDelegate` and the SwiftUI views never parse
/// `userInfo` themselves, they call into this coordinator.
@MainActor
final class DeepLinkCoordinator: ObservableObject {
    @Published private(set) var pendingRoute: AppRoute?

    func handle(userInfo: [AnyHashable: Any]) {
        guard let payload = NotificationPayload(userInfo: userInfo) else { return }
        if let notificationId = payload.notificationId {
            pendingRoute = .notification(id: notificationId, channelSlug: payload.channelSlug)
        } else {
            pendingRoute = .channel(slug: payload.channelSlug)
        }
    }

    /// Views call this once they've navigated, so the same route doesn't
    /// re-trigger navigation on the next view update.
    func consumePendingRoute() -> AppRoute? {
        defer { pendingRoute = nil }
        return pendingRoute
    }
}
