import Foundation

extension JSONDecoder {
    /// notifyhub's `DateTime` scalar is ISO-8601 with milliseconds
    /// (e.g. `2026-09-15T21:00:00.000Z` - see notifyhub's
    /// `src/graphql/typeDefs/scalars.ts`). `.iso8601` alone rejects the
    /// fractional-seconds component, so this decodes with fractional
    /// seconds first and falls back to without them.
    static let notifyHub: JSONDecoder = {
        let decoder = JSONDecoder()
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let withoutFractional = ISO8601DateFormatter()
        withoutFractional.formatOptions = [.withInternetDateTime]

        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = withFractional.date(from: string) ?? withoutFractional.date(from: string) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected ISO-8601 date string, got \(string)"
            )
        }
        return decoder
    }()
}
