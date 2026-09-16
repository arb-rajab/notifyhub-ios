import UIKit
import UserNotifications

/// Bridges UIKit's push-notification lifecycle into the app. Used via
/// `@UIApplicationDelegateAdaptor` from `NotifyHubApp` rather than a
/// SwiftUI-only setup, because registering for remote notifications,
/// receiving the APNs device token, and handling a notification tap in
/// every app state (foreground/background/killed) are all UIKit-level
/// callbacks with no SwiftUI equivalent.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    /// Injected by `NotifyHubApp` right after this instance is created by
    /// the adaptor, before `didFinishLaunchingWithOptions` can fire.
    var deepLinkCoordinator: DeepLinkCoordinator?
    var pushRegistrationService: (() -> PushRegistrationService?)?

    private let lastDeviceTokenDefaultsKey = "notifyhub.lastAPNsDeviceToken"

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self

        // Killed-state launch directly from a push tap. On current iOS
        // this case is normally also delivered to
        // `userNotificationCenter(_:didReceive:)` below after launch
        // completes, but older OS versions and some launch paths (e.g. a
        // background push that woke the app) only deliver it here - so
        // both paths call into the same coordinator.
        if let remoteNotification = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            deepLinkCoordinator?.handle(userInfo: remoteNotification)
        }
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
        let previousToken = UserDefaults.standard.string(forKey: lastDeviceTokenDefaultsKey)
        UserDefaults.standard.set(tokenString, forKey: lastDeviceTokenDefaultsKey)

        guard let service = pushRegistrationService?() else { return }
        Task {
            // Best-effort: this can legitimately fail if the user isn't
            // signed in yet (notifyhub's registerDeviceToken/
            // rotateDeviceToken both require an authenticated caller).
            // AppSession re-registers the current APNs token once sign-in
            // completes, so a failure here isn't the last chance.
            try? await service.rotate(oldToken: previousToken, newToken: tokenString)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // Expected and harmless in the iOS Simulator, which has no path
        // to real APNs to register with - see docs/project-memory/06-ops.md.
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Foreground delivery still shows the banner/sound - deep-linking
        // happens on tap (below), matching standard iOS notification UX
        // rather than yanking the user to a new screen on arrival.
        completionHandler([.banner, .sound, .list])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Covers the tap path for background and (on current iOS) killed
        // states, in addition to a tap while foregrounded.
        deepLinkCoordinator?.handle(userInfo: response.notification.request.content.userInfo)
        completionHandler()
    }
}
