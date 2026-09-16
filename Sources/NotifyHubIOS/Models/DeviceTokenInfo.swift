import Foundation

/// Mirrors notifyhub's `DeviceToken` GraphQL type
/// (`src/graphql/typeDefs/deviceToken.ts`). Deliberately does not carry the
/// raw APNs token string - the server never echoes it back, only metadata.
struct DeviceTokenInfo: Codable, Identifiable, Sendable {
    let id: String
    let platform: String
    let createdAt: Date
    let lastSeenAt: Date
}
