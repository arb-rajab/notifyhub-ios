import Foundation

/// Mirrors notifyhub's `Notification` GraphQL type
/// (`src/graphql/typeDefs/notification.ts`). Named `NotificationItem`
/// rather than `Notification` to avoid colliding with Foundation's
/// `Notification` (NSNotification) throughout the app.
struct NotificationItem: Codable, Identifiable, Equatable, Sendable {
    struct ChannelRef: Codable, Equatable, Sendable {
        let slug: String
        let name: String
    }

    struct AuthorRef: Codable, Equatable, Sendable {
        let id: String
        let displayName: String
    }

    let id: String
    let title: String
    let body: String
    let createdAt: Date
    let channel: ChannelRef
    let author: AuthorRef
}
