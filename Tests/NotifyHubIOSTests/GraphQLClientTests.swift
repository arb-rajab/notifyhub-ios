import XCTest
@testable import NotifyHubIOS

final class GraphQLClientTests: XCTestCase {
    private let endpoint = URL(string: "https://notifyhub.test/graphql")!

    override func tearDown() {
        StubURLProtocol.handler = nil
        super.tearDown()
    }

    func testSendsQueryAndVariablesAsJSONAndDecodesData() async throws {
        struct Payload: Decodable, Equatable { let value: Int }
        var capturedRequest: URLRequest?

        StubURLProtocol.handler = { request in
            capturedRequest = request
            let body = #"{"data":{"value":42}}"#.data(using: .utf8)!
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (body, response)
        }

        let client = GraphQLClient(endpoint: endpoint, session: StubURLProtocol.makeSession())
        let result = try await client.perform(
            query: "query { value }",
            variables: ["foo": "bar"],
            as: Payload.self
        )

        XCTAssertEqual(result, Payload(value: 42))
        XCTAssertEqual(capturedRequest?.httpMethod, "POST")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Content-Type"), "application/json")

        let sentBody = capturedRequest?.capturedBodyJSON()
        XCTAssertEqual(sentBody?["query"] as? String, "query { value }")
        XCTAssertEqual((sentBody?["variables"] as? [String: Any])?["foo"] as? String, "bar")
    }

    func testSendsBearerAuthorizationHeaderWhenTokenIsSet() async throws {
        var capturedRequest: URLRequest?
        StubURLProtocol.handler = { request in
            capturedRequest = request
            let body = #"{"data":{"value":1}}"#.data(using: .utf8)!
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (body, response)
        }

        struct Payload: Decodable { let value: Int }
        let client = GraphQLClient(endpoint: endpoint, session: StubURLProtocol.makeSession())
        client.authToken = "test-jwt"
        _ = try await client.perform(query: "query { value }", as: Payload.self)

        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer test-jwt")
    }

    func testThrowsGraphQLErrorWithCodeFromExtensions() async {
        StubURLProtocol.handler = { request in
            let body = #"""
            {"data":null,"errors":[{"message":"You must be signed in to do this.","extensions":{"code":"UNAUTHENTICATED"}}]}
            """#.data(using: .utf8)!
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (body, response)
        }

        struct Payload: Decodable { let value: Int }
        let client = GraphQLClient(endpoint: endpoint, session: StubURLProtocol.makeSession())

        do {
            _ = try await client.perform(query: "query { value }", as: Payload.self)
            XCTFail("Expected a GraphQLClientError")
        } catch let error as GraphQLClientError {
            XCTAssertTrue(error.isUnauthenticated)
        } catch {
            XCTFail("Expected GraphQLClientError, got \(error)")
        }
    }

    func testThrowsHTTPStatusErrorOnNon2xx() async {
        StubURLProtocol.handler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        struct Payload: Decodable { let value: Int }
        let client = GraphQLClient(endpoint: endpoint, session: StubURLProtocol.makeSession())

        do {
            _ = try await client.perform(query: "query { value }", as: Payload.self)
            XCTFail("Expected a GraphQLClientError")
        } catch GraphQLClientError.httpStatus(let status) {
            XCTAssertEqual(status, 500)
        } catch {
            XCTFail("Expected .httpStatus, got \(error)")
        }
    }
}
