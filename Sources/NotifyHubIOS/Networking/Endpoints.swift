import Foundation

/// notifyhub's own endpoint layout is fixed (ADR-001: GraphQL as the entire
/// API surface, one path for everything). The only thing that varies by
/// deployment is the host, so that's the only thing configurable here.
enum NotifyHubEndpoint {
    /// Defaults to the conventional local dev address
    /// (`npm run dev` in notifyhub listens on :4000). Override at build
    /// time via the `NOTIFYHUB_HOST` Info.plist key/build setting for a
    /// staging or production deployment - never hardcode a real host here.
    static var host: String {
        Bundle.main.object(forInfoDictionaryKey: "NotifyHubHost") as? String ?? "localhost:4000"
    }

    static var httpURL: URL {
        URL(string: "http://\(host)/graphql")!
    }

    static var webSocketURL: URL {
        URL(string: "ws://\(host)/graphql")!
    }
}
