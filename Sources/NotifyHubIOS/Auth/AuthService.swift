import Foundation

/// Wraps notifyhub's `register`/`login`/`me` GraphQL operations
/// (`src/graphql/typeDefs/user.ts`). Holds no state of its own - the
/// caller (`AppSession`) is responsible for persisting the returned token.
struct AuthService {
    private let client: GraphQLClient

    init(client: GraphQLClient) {
        self.client = client
    }

    func register(email: String, password: String, displayName: String) async throws -> AuthPayload {
        struct Response: Decodable { let register: AuthPayload }
        let response: Response = try await client.perform(
            query: """
            mutation Register($input: RegisterInput!) {
              register(input: $input) {
                token
                user { id email displayName role createdAt }
              }
            }
            """,
            variables: ["input": ["email": email, "password": password, "displayName": displayName]],
            as: Response.self
        )
        return response.register
    }

    func login(email: String, password: String) async throws -> AuthPayload {
        struct Response: Decodable { let login: AuthPayload }
        let response: Response = try await client.perform(
            query: """
            mutation Login($input: LoginInput!) {
              login(input: $input) {
                token
                user { id email displayName role createdAt }
              }
            }
            """,
            variables: ["input": ["email": email, "password": password]],
            as: Response.self
        )
        return response.login
    }

    func currentUser() async throws -> User? {
        struct Response: Decodable { let me: User? }
        let response: Response = try await client.perform(
            query: "query { me { id email displayName role createdAt } }",
            as: Response.self
        )
        return response.me
    }
}
