import XCTest
@testable import NotifyHubIOS

final class AuthServiceTests: XCTestCase {
    private let endpoint = URL(string: "https://notifyhub.test/graphql")!

    override func tearDown() {
        StubURLProtocol.handler = nil
        super.tearDown()
    }

    private let authPayloadJSON = """
    {"token":"jwt-abc","user":{"id":"u1","email":"a@example.com","displayName":"A","role":"USER","createdAt":"2026-09-16T00:00:00.000Z"}}
    """

    func testRegisterSendsEmailPasswordDisplayNameAndDecodesThePayload() async throws {
        var capturedRequest: URLRequest?
        StubURLProtocol.handler = { request in
            capturedRequest = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = "{\"data\":{\"register\":\(self.authPayloadJSON)}}".data(using: .utf8)!
            return (body, response)
        }

        let client = GraphQLClient(endpoint: endpoint, session: StubURLProtocol.makeSession())
        let service = AuthService(client: client)
        let payload = try await service.register(email: "a@example.com", password: "password123", displayName: "A")

        XCTAssertEqual(payload.token, "jwt-abc")
        XCTAssertEqual(payload.user.email, "a@example.com")

        let input = (capturedRequest?.capturedBodyJSON()?["variables"] as? [String: Any])?["input"] as? [String: Any]
        XCTAssertEqual(input?["email"] as? String, "a@example.com")
        XCTAssertEqual(input?["password"] as? String, "password123")
        XCTAssertEqual(input?["displayName"] as? String, "A")
    }

    func testLoginSendsEmailAndPassword() async throws {
        var capturedRequest: URLRequest?
        StubURLProtocol.handler = { request in
            capturedRequest = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = "{\"data\":{\"login\":\(self.authPayloadJSON)}}".data(using: .utf8)!
            return (body, response)
        }

        let client = GraphQLClient(endpoint: endpoint, session: StubURLProtocol.makeSession())
        let service = AuthService(client: client)
        _ = try await service.login(email: "a@example.com", password: "password123")

        let input = (capturedRequest?.capturedBodyJSON()?["variables"] as? [String: Any])?["input"] as? [String: Any]
        XCTAssertEqual(input?["email"] as? String, "a@example.com")
        XCTAssertEqual(input?["password"] as? String, "password123")
        XCTAssertNil(input?["displayName"])
    }

    func testCurrentUserReturnsNilWhenMeIsNull() async throws {
        StubURLProtocol.handler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = #"{"data":{"me":null}}"#.data(using: .utf8)!
            return (body, response)
        }

        let client = GraphQLClient(endpoint: endpoint, session: StubURLProtocol.makeSession())
        let service = AuthService(client: client)

        let user = try await service.currentUser()

        XCTAssertNil(user)
    }
}
