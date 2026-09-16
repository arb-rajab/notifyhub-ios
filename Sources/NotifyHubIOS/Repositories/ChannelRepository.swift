import Foundation

/// Wraps notifyhub's channel GraphQL operations
/// (`src/graphql/typeDefs/channel.ts`).
struct ChannelRepository {
    private let client: GraphQLClient
    private static let fields = "id slug name description subscriberCount isSubscribed createdAt"

    init(client: GraphQLClient) {
        self.client = client
    }

    func list(search: String? = nil) async throws -> [Channel] {
        struct Response: Decodable { let channels: [Channel] }
        var variables: [String: Any] = [:]
        if let search, !search.isEmpty { variables["search"] = search }
        let response: Response = try await client.perform(
            query: "query Channels($search: String) { channels(search: $search) { \(Self.fields) } }",
            variables: variables,
            as: Response.self
        )
        return response.channels
    }

    func find(slug: String) async throws -> Channel? {
        struct Response: Decodable { let channel: Channel? }
        let response: Response = try await client.perform(
            query: "query FindChannel($slug: String!) { channel(slug: $slug) { \(Self.fields) } }",
            variables: ["slug": slug],
            as: Response.self
        )
        return response.channel
    }

    @discardableResult
    func create(slug: String, name: String, description: String?) async throws -> Channel {
        struct Response: Decodable { let createChannel: Channel }
        var input: [String: Any] = ["slug": slug, "name": name]
        if let description, !description.isEmpty { input["description"] = description }
        let response: Response = try await client.perform(
            query: "mutation CreateChannel($input: CreateChannelInput!) { createChannel(input: $input) { \(Self.fields) } }",
            variables: ["input": input],
            as: Response.self
        )
        return response.createChannel
    }

    @discardableResult
    func subscribe(slug: String) async throws -> Channel {
        struct Response: Decodable { let subscribeToChannel: Channel }
        let response: Response = try await client.perform(
            query: "mutation SubscribeToChannel($slug: String!) { subscribeToChannel(slug: $slug) { \(Self.fields) } }",
            variables: ["slug": slug],
            as: Response.self
        )
        return response.subscribeToChannel
    }

    @discardableResult
    func unsubscribe(slug: String) async throws -> Channel {
        struct Response: Decodable { let unsubscribeFromChannel: Channel }
        let response: Response = try await client.perform(
            query: "mutation UnsubscribeFromChannel($slug: String!) { unsubscribeFromChannel(slug: $slug) { \(Self.fields) } }",
            variables: ["slug": slug],
            as: Response.self
        )
        return response.unsubscribeFromChannel
    }
}
