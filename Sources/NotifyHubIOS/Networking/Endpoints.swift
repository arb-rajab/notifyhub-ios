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

    /// Plaintext (`http://`/`ws://`) is only ever used for the conventional
    /// local dev address, and only when the app wasn't given an explicit
    /// `NotifyHubHost` at all. Any configured host - staging, production, or
    /// anything else an operator points this at - always gets an encrypted
    /// scheme. A genuine plaintext local backend on a non-default host must
    /// opt in explicitly via the `NotifyHubAllowInsecureHTTP` Info.plist key;
    /// this is never a silent default.
    static var usesPlaintext: Bool {
        usesPlaintext(
            host: host,
            isDefaultHost: Bundle.main.object(forInfoDictionaryKey: "NotifyHubHost") as? String == nil,
            allowInsecureOverride: Bundle.main.object(forInfoDictionaryKey: "NotifyHubAllowInsecureHTTP") as? Bool == true
        )
    }

    static var httpURL: URL {
        URL(string: "\(usesPlaintext ? "http" : "https")://\(host)/graphql")!
    }

    static var webSocketURL: URL {
        URL(string: "\(usesPlaintext ? "ws" : "wss")://\(host)/graphql")!
    }

    /// Pure decision logic, factored out so it can be unit-tested without a
    /// real `Bundle.main` Info.plist (see `EndpointsSchemeTests`).
    static func usesPlaintext(host: String, isDefaultHost: Bool, allowInsecureOverride: Bool) -> Bool {
        if allowInsecureOverride {
            return true
        }
        return isDefaultHost && isLocalDevHost(host)
    }

    private static func isLocalDevHost(_ host: String) -> Bool {
        let hostname = host.split(separator: ":").first.map(String.init) ?? host
        return hostname == "localhost" || hostname == "127.0.0.1" || hostname == "::1"
    }
}
