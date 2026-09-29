import XCTest
@testable import NotifyHubIOS

/// Covers the shared state that the three formerly-silent push-setup
/// failure sites (`NotifyHubApp`'s denied permission, `AppSession`'s
/// post-sign-in registration, `AppDelegate`'s token rotation) now feed.
/// Real APNs delivery can't be exercised here (docs/project-memory/08-risk.md
/// R-1), so these drive the state directly and through `AppSession` against
/// a stubbed GraphQL endpoint.
@MainActor
final class PushStatusTests: XCTestCase {
    private struct Boom: Error {}

    func testStartsWithNoIssue() {
        XCTAssertNil(PushStatus().visibleIssue)
    }

    func testAFailedRegistrationIsRecorded() async {
        let status = PushStatus()

        await status.recordRegistration { () async throws -> Int in throw Boom() }

        XCTAssertEqual(status.visibleIssue, .registrationFailed)
    }

    func testASuccessfulRegistrationClearsAPriorFailure() async {
        let status = PushStatus()
        await status.recordRegistration { () async throws -> Int in throw Boom() }

        await status.recordRegistration { () async throws -> Int in 1 }

        XCTAssertNil(status.visibleIssue)
    }

    func testDeniedPermissionWinsOverARegistrationFailure() async {
        let status = PushStatus()
        await status.recordRegistration { () async throws -> Int in throw Boom() }
        status.setPermissionDenied(true)

        XCTAssertEqual(status.visibleIssue, .permissionDenied)

        status.setPermissionDenied(false)
        XCTAssertEqual(status.visibleIssue, .registrationFailed)
    }

    func testDismissHidesTheBannerUntilTheNextFailure() async {
        let status = PushStatus()
        await status.recordRegistration { () async throws -> Int in throw Boom() }

        status.dismiss()
        XCTAssertNil(status.visibleIssue)

        await status.recordRegistration { () async throws -> Int in throw Boom() }
        XCTAssertEqual(status.visibleIssue, .registrationFailed)
    }

    func testDismissedDeniedPermissionReappearsWhenReportedAgain() {
        let status = PushStatus()
        status.setPermissionDenied(true)
        status.dismiss()
        XCTAssertNil(status.visibleIssue)

        status.setPermissionDenied(true)
        XCTAssertEqual(status.visibleIssue, .permissionDenied)
    }
}

/// `AppSession.registerCurrentAPNsTokenIfNeeded` end to end: sign in
/// through a stubbed `login`, with a stubbed `registerDeviceToken` that
/// either succeeds or fails.
@MainActor
final class AppSessionPushRegistrationTests: XCTestCase {
    private let endpoint = URL(string: "https://notifyhub.test/graphql")!
    private let tokenDefaultsKey = "notifyhub.lastAPNsDeviceToken"
    private let keychain = KeychainStore(service: "com.notifyhub.ios.tests.appsession")
    private var previousToken: String?

    private let authPayloadJSON = """
    {"token":"jwt-abc","user":{"id":"u1","email":"a@example.com","displayName":"A","role":"USER","createdAt":"2026-09-16T00:00:00.000Z"}}
    """
    private let deviceTokenJSON = """
    {"id":"dt-1","platform":"IOS","createdAt":"2026-09-16T00:00:00.000Z","lastSeenAt":"2026-09-16T00:00:00.000Z"}
    """

    override func setUp() {
        super.setUp()
        previousToken = UserDefaults.standard.string(forKey: tokenDefaultsKey)
        UserDefaults.standard.set("apns-token", forKey: tokenDefaultsKey)
    }

    override func tearDown() {
        StubURLProtocol.handler = nil
        keychain.clear()
        if let previousToken {
            UserDefaults.standard.set(previousToken, forKey: tokenDefaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: tokenDefaultsKey)
        }
        super.tearDown()
    }

    private func makeSession(registerSucceeds: Bool) -> AppSession {
        StubURLProtocol.handler = { request in
            let query = request.capturedBodyJSON()?["query"] as? String ?? ""
            let statusCode = query.contains("registerDeviceToken") && !registerSucceeds ? 500 : 200
            let response = HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
            let body: String
            if query.contains("registerDeviceToken") {
                body = "{\"data\":{\"registerDeviceToken\":\(self.deviceTokenJSON)}}"
            } else {
                body = "{\"data\":{\"login\":\(self.authPayloadJSON)}}"
            }
            return (body.data(using: .utf8)!, response)
        }
        let client = GraphQLClient(endpoint: endpoint, session: StubURLProtocol.makeSession())
        return AppSession(graphQLClient: client, keychain: keychain)
    }

    func testAFailedPostSignInRegistrationSurfacesAnIssue() async {
        let session = makeSession(registerSucceeds: false)

        await session.login(email: "a@example.com", password: "password123")

        XCTAssertTrue(session.isSignedIn)
        XCTAssertEqual(session.pushStatus.visibleIssue, .registrationFailed)
    }

    func testASuccessfulPostSignInRegistrationLeavesNoIssue() async {
        let session = makeSession(registerSucceeds: true)

        await session.login(email: "a@example.com", password: "password123")

        XCTAssertTrue(session.isSignedIn)
        XCTAssertNil(session.pushStatus.visibleIssue)
    }

    func testSigningOutClearsARegistrationFailure() async {
        let session = makeSession(registerSucceeds: false)
        await session.login(email: "a@example.com", password: "password123")
        XCTAssertEqual(session.pushStatus.visibleIssue, .registrationFailed)

        session.signOut()

        XCTAssertNil(session.pushStatus.visibleIssue)
    }
}
