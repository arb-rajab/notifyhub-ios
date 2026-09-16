import SwiftUI

/// The single navigation root: gates on auth state, and turns whatever
/// `DeepLinkCoordinator` last resolved (from a push tap in any app state)
/// into a pushed `NavigationStack` path entry - the one place push
/// delivery and in-app navigation meet.
struct RootView: View {
    @EnvironmentObject private var session: AppSession
    @EnvironmentObject private var deepLinkCoordinator: DeepLinkCoordinator
    @State private var path: [AppRoute] = []

    var body: some View {
        Group {
            if session.isRestoringSession {
                ProgressView()
            } else if session.isSignedIn {
                NavigationStack(path: $path) {
                    ChannelListView(viewModel: ChannelListViewModel(repository: session.channelRepository))
                        .navigationDestination(for: AppRoute.self) { route in
                            destination(for: route)
                        }
                }
            } else {
                LoginView()
            }
        }
        .onChange(of: deepLinkCoordinator.pendingRoute) { _ in
            applyPendingRouteIfNeeded()
        }
        .onChange(of: session.isSignedIn) { _ in
            applyPendingRouteIfNeeded()
        }
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .channelList:
            EmptyView()
        case .channel(let slug):
            ChannelDetailView(viewModel: makeChannelDetailViewModel(slug: slug, highlightNotificationId: nil))
        case .notification(let id, let channelSlug):
            ChannelDetailView(viewModel: makeChannelDetailViewModel(slug: channelSlug, highlightNotificationId: id))
        }
    }

    private func makeChannelDetailViewModel(slug: String, highlightNotificationId: String?) -> ChannelDetailViewModel {
        ChannelDetailViewModel(
            channelSlug: slug,
            highlightNotificationId: highlightNotificationId,
            channelRepository: session.channelRepository,
            notificationRepository: session.notificationRepository,
            makeSubscriptionClient: { [session] in try await session.makeSubscriptionClient() }
        )
    }

    /// A push can arrive before the user is signed in (e.g. the app was
    /// killed and cold-launched straight from the notification) - in that
    /// case the route is held by `DeepLinkCoordinator` until `isSignedIn`
    /// flips true, then applied here.
    private func applyPendingRouteIfNeeded() {
        guard session.isSignedIn, let route = deepLinkCoordinator.consumePendingRoute() else { return }
        path = [route]
    }
}
