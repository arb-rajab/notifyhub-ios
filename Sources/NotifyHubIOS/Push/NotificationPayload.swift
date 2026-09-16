import Foundation

/// The custom keys notifyhub's `ApnsPushChannel` puts on every push
/// payload alongside the standard `aps` dictionary - see notifyhub's
/// `buildApnsPayload` in `src/services/push/apnsChannel.ts`. Keep both
/// sides of this contract in sync if either changes.
struct NotificationPayload: Equatable {
    let notificationId: String?
    let channelSlug: String

    init?(userInfo: [AnyHashable: Any]) {
        guard let channelSlug = userInfo["channelSlug"] as? String else { return nil }
        self.channelSlug = channelSlug
        self.notificationId = userInfo["notificationId"] as? String
    }
}
