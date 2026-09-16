import XCTest
@testable import NotifyHubIOS

/// Verifies `PushRegistrationService` sends the request shape notifyhub's
/// device-token mutations expect (`src/graphql/typeDefs/deviceToken.ts`) -
/// the client half of the same contract Part 1's backend tests
/// (`tests/integration/deviceTokens.test.ts`) verify server-side.
final class PushRegistrationServiceTests: XCTestCase {
    private let endpoint = URL(string: "https://notifyhub.test/graphql")!

    override func tearDown() {
        StubURLProtocol.handler = nil
        super.tearDown()
    }

    private func stubResponse(fieldName: String, json: String) {
        StubURLProtocol.handler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = "{\"data\":{\"\(fieldName)\":\(json)}}".data(using: .utf8)!
            return (body, response)
        }
    }

    private let deviceTokenJSON = """
    {"id":"dt-1","platform":"IOS","createdAt":"2026-09-16T00:00:00.000Z","lastSeenAt":"2026-09-16T00:00:00.000Z"}
    """

    func testRegisterSendsTheDeviceTokenUnderInput() async throws {
        var capturedRequest: URLRequest?
        StubURLProtocol.handler = { request in
            capturedRequest = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = "{\"data\":{\"registerDeviceToken\":\(self.deviceTokenJSON)}}".data(using: .utf8)!
            return (body, response)
        }

        let client = GraphQLClient(endpoint: endpoint, session: StubURLProtocol.makeSession())
        let service = PushRegistrationService(client: client)
        let info = try await service.register(deviceToken: "abc123")

        XCTAssertEqual(info.id, "dt-1")
        let body = capturedRequest?.capturedBodyJSON()
        let input = (body?["variables"] as? [String: Any])?["input"] as? [String: Any]
        XCTAssertEqual(input?["token"] as? String, "abc123")
        XCTAssertTrue((body?["query"] as? String)?.contains("registerDeviceToken") == true)
    }

    func testRotateFallsBackToRegisterWithoutAnOldToken() async throws {
        var capturedRequest: URLRequest?
        StubURLProtocol.handler = { request in
            capturedRequest = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = "{\"data\":{\"registerDeviceToken\":\(self.deviceTokenJSON)}}".data(using: .utf8)!
            return (body, response)
        }

        let client = GraphQLClient(endpoint: endpoint, session: StubURLProtocol.makeSession())
        let service = PushRegistrationService(client: client)
        _ = try await service.rotate(oldToken: nil, newToken: "new-token")

        let query = capturedRequest?.capturedBodyJSON()?["query"] as? String
        XCTAssertTrue(query?.contains("registerDeviceToken") == true)
        XCTAssertFalse(query?.contains("rotateDeviceToken") == true)
    }

    func testRotateSendsBothTokensWhenAnOldTokenIsKnown() async throws {
        var capturedRequest: URLRequest?
        StubURLProtocol.handler = { request in
            capturedRequest = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = "{\"data\":{\"rotateDeviceToken\":\(self.deviceTokenJSON)}}".data(using: .utf8)!
            return (body, response)
        }

        let client = GraphQLClient(endpoint: endpoint, session: StubURLProtocol.makeSession())
        let service = PushRegistrationService(client: client)
        _ = try await service.rotate(oldToken: "old-token", newToken: "new-token")

        let body = capturedRequest?.capturedBodyJSON()
        let variables = body?["variables"] as? [String: Any]
        XCTAssertEqual(variables?["oldToken"] as? String, "old-token")
        XCTAssertEqual(variables?["newToken"] as? String, "new-token")
        XCTAssertTrue((body?["query"] as? String)?.contains("rotateDeviceToken") == true)
    }

    func testRevokeReturnsTheServerBoolean() async throws {
        StubURLProtocol.handler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = #"{"data":{"revokeDeviceToken":true}}"#.data(using: .utf8)!
            return (body, response)
        }

        let client = GraphQLClient(endpoint: endpoint, session: StubURLProtocol.makeSession())
        let service = PushRegistrationService(client: client)

        let result = try await service.revoke(deviceToken: "abc123")

        XCTAssertTrue(result)
    }
}
