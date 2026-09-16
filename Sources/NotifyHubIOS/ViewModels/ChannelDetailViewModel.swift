import Combine
import Foundation

@MainActor
final class ChannelDetailViewModel: ObservableObject {
    let channelSlug: String
    /// The highlighted notification from a deep link, if the user arrived
    /// here via a push tap for a specific notification rather than
    /// browsing in from the channel list.
    let highlightNotificationId: String?

    @Published private(set) var channel: Channel?
    @Published private(set) var notifications: [NotificationItem] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var composeTitle = ""
    @Published var composeBody = ""

    private let channelRepository: ChannelRepository
    private let notificationRepository: NotificationRepository
    private let makeSubscriptionClient: () async throws -> GraphQLSubscriptionClient

    private var liveUpdatesTask: Task<Void, Never>?
    private var subscriptionClient: GraphQLSubscriptionClient?

    init(
        channelSlug: String,
        highlightNotificationId: String? = nil,
        channelRepository: ChannelRepository,
        notificationRepository: NotificationRepository,
        makeSubscriptionClient: @escaping () async throws -> GraphQLSubscriptionClient
    ) {
        self.channelSlug = channelSlug
        self.highlightNotificationId = highlightNotificationId
        self.channelRepository = channelRepository
        self.notificationRepository = notificationRepository
        self.makeSubscriptionClient = makeSubscriptionClient
    }

    func loadInitial() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let fetchedChannel = channelRepository.find(slug: channelSlug)
            async let fetchedNotifications = notificationRepository.list(channelSlug: channelSlug)
            channel = try await fetchedChannel
            notifications = try await fetchedNotifications
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startLiveUpdates() {
        guard liveUpdatesTask == nil else { return }
        liveUpdatesTask = Task { [weak self] in
            guard let self else { return }
            do {
                let client = try await self.makeSubscriptionClient()
                self.subscriptionClient = client
                let stream = self.notificationRepository.subscribeToChannel(slug: self.channelSlug, using: client)
                for try await item in stream {
                    if !self.notifications.contains(where: { $0.id == item.id }) {
                        self.notifications.insert(item, at: 0)
                    }
                }
            } catch is CancellationError {
                // Expected when the view disappears - see stopLiveUpdates().
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func stopLiveUpdates() {
        liveUpdatesTask?.cancel()
        liveUpdatesTask = nil
        let client = subscriptionClient
        subscriptionClient = nil
        Task { await client?.disconnect() }
    }

    func toggleSubscription() async {
        guard let channel else { return }
        do {
            self.channel = channel.isSubscribed
                ? try await channelRepository.unsubscribe(slug: channelSlug)
                : try await channelRepository.subscribe(slug: channelSlug)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func publish() async {
        let title = composeTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = composeBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !body.isEmpty else { return }
        do {
            // The live subscription (if active) delivers this notification
            // back automatically - publishing requires being subscribed to
            // the channel (notifyhub's NotificationService.publish), so no
            // separate local insert is needed here.
            try await notificationRepository.publish(channelSlug: channelSlug, title: title, body: body)
            composeTitle = ""
            composeBody = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
