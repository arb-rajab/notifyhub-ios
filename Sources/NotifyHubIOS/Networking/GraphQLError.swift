import Foundation

enum GraphQLClientError: Error, LocalizedError, Equatable {
    case transport(String)
    case httpStatus(Int)
    case decoding(String)
    /// Mirrors notifyhub's `extensions.code` on a GraphQL error - see
    /// `src/utils/errors.ts` for the exact set (`UNAUTHENTICATED`,
    /// `FORBIDDEN`, `NOT_FOUND`, `BAD_USER_INPUT`, `CONFLICT`).
    case graphQL(message: String, code: String?)
    case noData

    var errorDescription: String? {
        switch self {
        case .transport(let message): return message
        case .httpStatus(let status): return "Unexpected HTTP status \(status)."
        case .decoding(let message): return "Failed to decode response: \(message)"
        case .graphQL(let message, _): return message
        case .noData: return "The server returned no data."
        }
    }

    var isUnauthenticated: Bool {
        if case .graphQL(_, let code) = self { return code == "UNAUTHENTICATED" }
        return false
    }
}
