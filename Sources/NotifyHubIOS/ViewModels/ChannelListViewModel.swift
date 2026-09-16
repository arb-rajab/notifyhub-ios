import Combine
import Foundation

@MainActor
final class ChannelListViewModel: ObservableObject {
    @Published private(set) var channels: [Channel] = []
    @Published var searchText: String = ""
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let repository: ChannelRepository

    init(repository: ChannelRepository) {
        self.repository = repository
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            channels = try await repository.list(search: searchText.isEmpty ? nil : searchText)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleSubscription(for channel: Channel) async {
        do {
            let updated = channel.isSubscribed
                ? try await repository.unsubscribe(slug: channel.slug)
                : try await repository.subscribe(slug: channel.slug)
            if let index = channels.firstIndex(where: { $0.id == updated.id }) {
                channels[index] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createChannel(slug: String, name: String, description: String?) async {
        do {
            let created = try await repository.create(slug: slug, name: name, description: description)
            channels.insert(created, at: 0)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
