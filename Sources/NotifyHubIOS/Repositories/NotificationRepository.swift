import Foundation

/// Wraps notifyhub's notification GraphQL operations
/// (`src/graphql/typeDefs/notification.ts`), including the real-time
/// `notificationReceived` subscription over `GraphQLSubscriptionClient`.
struct NotificationRepository {
    private let client: GraphQLClient
    private static let fields = "id title body createdAt channel { slug name } author { id displayName }"

    init(client: GraphQLClient) {
        self.client = client
    }

    func list(channelSlug: String, limit: Int = 20) async throws -> [NotificationItem] {
        struct Response: Decodable { let notifications: [NotificationItem] }
        let response: Response = try await client.perform(
            query: "query Notifications($channelSlug: String!, $limit: Int) { notifications(channelSlug: $channelSlug, limit: $limit) { \(Self.fields) } }",
            variables: ["channelSlug": channelSlug, "limit": limit],
            as: Response.self
        )
        return response.notifications
    }

    @discardableResult
    func publish(channelSlug: String, title: String, body: String) async throws -> NotificationItem {
        struct Response: Decodable { let publishNotification: NotificationItem }
        let response: Response = try await client.perform(
            query: "mutation Publish($input: PublishNotificationInput!) { publishNotification(input: $input) { \(Self.fields) } }",
            variables: ["input": ["channelSlug": channelSlug, "title": title, "body": body]],
            as: Response.self
        )
        return response.publishNotification
    }

    /// Opens a live `notificationReceived(channelSlug:)` subscription and
    /// yields each newly-published `NotificationItem` as it arrives. The
    /// stream unsubscribes automatically when the consumer stops iterating
    /// (e.g. the view holding it disappears).
    func subscribeToChannel(
        slug: String,
        using subscriptionClient: GraphQLSubscriptionClient
    ) -> AsyncThrowingStream<NotificationItem, Error> {
        let subscriptionId = UUID().uuidString
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await subscriptionClient.subscribe(
                        id: subscriptionId,
                        query: "subscription NotificationReceived($channelSlug: String!) { notificationReceived(channelSlug: $channelSlug) { \(Self.fields) } }",
                        variables: ["channelSlug": slug]
                    ) { result in
                        switch result {
                        case .success(let payload):
                            guard let raw = payload["notificationReceived"] as? [String: Any] else { return }
                            do {
                                let data = try JSONSerialization.data(withJSONObject: raw)
                                let item = try JSONDecoder.notifyHub.decode(NotificationItem.self, from: data)
                                continuation.yield(item)
                            } catch {
                                continuation.finish(throwing: error)
                            }
                        case .failure(let error):
                            continuation.finish(throwing: error)
                        }
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
                Task { await subscriptionClient.unsubscribe(id: subscriptionId) }
            }
        }
    }
}
