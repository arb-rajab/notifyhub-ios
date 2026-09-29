import SwiftUI
import UIKit
import UserNotifications

@main
struct NotifyHubApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var session = AppSession()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                // Observed separately from `session` so that SwiftUI
                // re-renders RootView when a deep link arrives - nested
                // `ObservableObject`s don't propagate change
                // notifications through their parent automatically.
                .environmentObject(session.deepLinkCoordinator)
                .environmentObject(session.pushStatus)
                .task {
                    // The adaptor constructs `appDelegate` before this
                    // task can run, but `session` (a `@StateObject`) only
                    // becomes available once the view's task starts - so
                    // wiring happens here rather than in an initializer.
                    appDelegate.deepLinkCoordinator = session.deepLinkCoordinator
                    appDelegate.pushRegistrationService = { [weak session] in session?.makePushRegistrationService() }
                    appDelegate.pushStatus = session.pushStatus

                    await session.restoreSession()
                    await requestPushAuthorizationIfNeeded()
                }
        }
    }

    @MainActor
    private func requestPushAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            session.pushStatus.setPermissionDenied(false)
            UIApplication.shared.registerForRemoteNotifications()
        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                if granted {
                    session.pushStatus.setPermissionDenied(false)
                    UIApplication.shared.registerForRemoteNotifications()
                } else {
                    session.pushStatus.setPermissionDenied(true)
                }
            } catch {
                // The app remains fully usable without push if this fails
                // or is denied - it just won't receive any. Surface that
                // via the same banner as an explicit denial.
                session.pushStatus.setPermissionDenied(true)
            }
        case .denied:
            // Same: fully usable, but tell the user push won't arrive.
            session.pushStatus.setPermissionDenied(true)
        @unknown default:
            break
        }
    }
}
