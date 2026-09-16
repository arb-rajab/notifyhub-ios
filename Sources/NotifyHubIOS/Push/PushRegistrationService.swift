import Foundation

/// Wraps notifyhub's device-token GraphQL mutations
/// (`src/graphql/typeDefs/deviceToken.ts`, added alongside
/// `ApnsPushChannel` on the backend) - this is the client half of that
/// same feature.
struct PushRegistrationService {
    private let client: GraphQLClient

    init(client: GraphQLClient) {
        self.client = client
    }

    @discardableResult
    func register(deviceToken: String) async throws -> DeviceTokenInfo {
        struct Response: Decodable { let registerDeviceToken: DeviceTokenInfo }
        let response: Response = try await client.perform(
            query: """
            mutation RegisterDeviceToken($input: RegisterDeviceTokenInput!) {
              registerDeviceToken(input: $input) { id platform createdAt lastSeenAt }
            }
            """,
            variables: ["input": ["token": deviceToken]],
            as: Response.self
        )
        return response.registerDeviceToken
    }

    /// Called when APNs hands the app a new token for one it previously
    /// registered - see `AppDelegate.application(_:didRegisterForRemoteNotificationsWithDeviceToken:)`.
    /// If `oldToken` is unknown (first launch), this falls back to a plain
    /// `register` - notifyhub's `rotateDeviceToken` requires the caller to
    /// already own `oldToken` (see notifyhub's `DeviceTokenService.rotate`).
    @discardableResult
    func rotate(oldToken: String?, newToken: String) async throws -> DeviceTokenInfo {
        guard let oldToken, oldToken != newToken else {
            return try await register(deviceToken: newToken)
        }
        struct Response: Decodable { let rotateDeviceToken: DeviceTokenInfo }
        let response: Response = try await client.perform(
            query: """
            mutation RotateDeviceToken($oldToken: String!, $newToken: String!) {
              rotateDeviceToken(oldToken: $oldToken, newToken: $newToken) { id platform createdAt lastSeenAt }
            }
            """,
            variables: ["oldToken": oldToken, "newToken": newToken],
            as: Response.self
        )
        return response.rotateDeviceToken
    }

    @discardableResult
    func revoke(deviceToken: String) async throws -> Bool {
        struct Response: Decodable { let revokeDeviceToken: Bool }
        let response: Response = try await client.perform(
            query: "mutation RevokeDeviceToken($token: String!) { revokeDeviceToken(token: $token) }",
            variables: ["token": deviceToken],
            as: Response.self
        )
        return response.revokeDeviceToken
    }

    func myDeviceTokens() async throws -> [DeviceTokenInfo] {
        struct Response: Decodable { let myDeviceTokens: [DeviceTokenInfo] }
        let response: Response = try await client.perform(
            query: "query { myDeviceTokens { id platform createdAt lastSeenAt } }",
            as: Response.self
        )
        return response.myDeviceTokens
    }
}
