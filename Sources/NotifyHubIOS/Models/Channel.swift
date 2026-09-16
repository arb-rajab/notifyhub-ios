import Foundation

/// Mirrors notifyhub's `Channel` GraphQL type
/// (`src/graphql/typeDefs/channel.ts`).
struct Channel: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let slug: String
    let name: String
    let description: String?
    let subscriberCount: Int
    let isSubscribed: Bool
    let createdAt: Date
}
