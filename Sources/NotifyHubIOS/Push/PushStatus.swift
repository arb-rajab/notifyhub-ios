import Combine
import Foundation

/// Why push notifications aren't working on this device, as far as the app
/// can tell. Only these two are distinguished because they need different
/// responses from the user: a denied permission is fixed in iOS Settings,
/// while a failed registration is a network/server problem the app itself
/// retries (at the next sign-in or APNs token change).
enum PushIssue: Equatable {
    case permissionDenied
    case registrationFailed
}

/// The one place every push-setup failure lands, so `RootView` can tell the
/// user about it instead of the failure being swallowed at the call site.
/// Fed by `NotifyHubApp` (permission), `AppSession` (post-sign-in
/// registration) and `AppDelegate` (token rotation).
///
/// Observed separately from `AppSession` via its own `environmentObject` -
/// nested `ObservableObject`s don't propagate changes through their parent
/// (same reason `DeepLinkCoordinator` is injected separately).
@MainActor
final class PushStatus: ObservableObject {
    @Published private(set) var permissionDenied = false
    @Published private(set) var registrationFailed = false
    @Published private(set) var isDismissed = false

    /// What the banner should show right now, if anything. A denied
    /// permission wins over a registration failure: registering can't
    /// succeed usefully until the user fixes the permission anyway.
    var visibleIssue: PushIssue? {
        guard !isDismissed else { return nil }
        if permissionDenied { return .permissionDenied }
        if registrationFailed { return .registrationFailed }
        return nil
    }

    func setPermissionDenied(_ denied: Bool) {
        permissionDenied = denied
        if denied { isDismissed = false }
    }

    func clearRegistrationFailure() {
        registrationFailed = false
    }

    /// Hides the banner until the next failure is reported.
    func dismiss() {
        isDismissed = true
    }

    /// Runs a device-token registration/rotation and records the outcome.
    /// Never rethrows: callers used to discard the error with `try?`, and
    /// this keeps them fire-and-forget while still leaving a trace.
    func recordRegistration<T>(_ operation: () async throws -> T) async {
        do {
            _ = try await operation()
            registrationFailed = false
        } catch {
            registrationFailed = true
            isDismissed = false
        }
    }
}
