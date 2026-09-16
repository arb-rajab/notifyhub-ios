import Foundation

/// Mirrors notifyhub's `User` GraphQL type (`src/graphql/typeDefs/user.ts`).
struct User: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let email: String
    let displayName: String
    let role: String
    let createdAt: Date
}

/// Mirrors notifyhub's `AuthPayload` (returned by `register`/`login`).
struct AuthPayload: Codable, Sendable {
    let token: String
    let user: User
}
