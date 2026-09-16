import Combine
import Foundation
import UIKit
import UserNotifications

/// The app's composition root: owns the GraphQL HTTP/WebSocket clients,
/// the Keychain-backed JWT, and every repository/service built on top of
/// them. One instance lives for the app's lifetime, injected into the
/// SwiftUI environment from `NotifyHubApp`.
@MainActor
final class AppSession: ObservableObject {
    @Published private(set) var currentUser: User?
    @Published private(set) var isRestoringSession = true
    @Published var lastErrorMessage: String?

    let channelRepository: ChannelRepository
    let notificationRepository: NotificationRepository
    let deepLinkCoordinator: DeepLinkCoordinator

    private let graphQLClient: GraphQLClient
    private let keychain: KeychainStore
    private let authService: AuthService
    private let pushRegistrationService: PushRegistrationService
    private var lastKnownDeviceToken: String? {
        UserDefaults.standard.string(forKey: "notifyhub.lastAPNsDeviceToken")
    }

    var isSignedIn: Bool { currentUser != nil }

    init(
        graphQLClient: GraphQLClient = GraphQLClient(endpoint: NotifyHubEndpoint.httpURL),
        keychain: KeychainStore = KeychainStore(),
        deepLinkCoordinator: DeepLinkCoordinator = DeepLinkCoordinator()
    ) {
        self.graphQLClient = graphQLClient
        self.keychain = keychain
        self.deepLinkCoordinator = deepLinkCoordinator
        self.authService = AuthService(client: graphQLClient)
        self.pushRegistrationService = PushRegistrationService(client: graphQLClient)
        self.channelRepository = ChannelRepository(client: graphQLClient)
        self.notificationRepository = NotificationRepository(client: graphQLClient)
    }

    /// Called once at launch: if a token is already in the Keychain from a
    /// previous session, validate it against `me` rather than trusting it
    /// blindly (it may have expired - ADR-003's 15-minute default).
    func restoreSession() async {
        defer { isRestoringSession = false }
        guard let token = keychain.loadToken() else { return }
        graphQLClient.authToken = token
        do {
            currentUser = try await authService.currentUser()
            if currentUser == nil {
                signOut()
            }
        } catch {
            signOut()
        }
    }

    func register(email: String, password: String, displayName: String) async {
        await performAuth { try await self.authService.register(email: email, password: password, displayName: displayName) }
    }

    func login(email: String, password: String) async {
        await performAuth { try await self.authService.login(email: email, password: password) }
    }

    private func performAuth(_ operation: @escaping () async throws -> AuthPayload) async {
        lastErrorMessage = nil
        do {
            let payload = try await operation()
            graphQLClient.authToken = payload.token
            try keychain.save(token: payload.token)
            currentUser = payload.user
            await registerCurrentAPNsTokenIfNeeded()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func signOut() {
        graphQLClient.authToken = nil
        keychain.clear()
        currentUser = nil
    }

    /// Called after sign-in completes, in case `AppDelegate` already
    /// received an APNs device token while the user was signed out (device
    /// push registration requires an authenticated caller - see
    /// notifyhub's `DeviceTokenService`).
    func registerCurrentAPNsTokenIfNeeded() async {
        guard isSignedIn, let token = lastKnownDeviceToken else { return }
        try? await pushRegistrationService.register(deviceToken: token)
    }

    func makePushRegistrationService() -> PushRegistrationService {
        pushRegistrationService
    }

    func makeSubscriptionClient() async throws -> GraphQLSubscriptionClient {
        let client = GraphQLSubscriptionClient(url: NotifyHubEndpoint.webSocketURL)
        let authorization = graphQLClient.authToken.map { "Bearer \($0)" }
        try await client.connect(authorization: authorization)
        return client
    }
}
