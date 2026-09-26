import XCTest
@testable import NotifyHubIOS

final class EndpointsSchemeTests: XCTestCase {
    func testDefaultLocalhostHostUsesPlaintext() {
        XCTAssertTrue(
            NotifyHubEndpoint.usesPlaintext(host: "localhost:4000", isDefaultHost: true, allowInsecureOverride: false)
        )
    }

    func testConfiguredProductionHostUsesEncryptedScheme() {
        XCTAssertFalse(
            NotifyHubEndpoint.usesPlaintext(host: "api.notifyhub.example.com", isDefaultHost: false, allowInsecureOverride: false)
        )
    }

    func testConfiguredHostIsEncryptedEvenIfItLooksLikeLocalhost() {
        // A staging/production deployment that happens to be reachable at a
        // "localhost"-shaped address must still be explicit about opting
        // into plaintext - the default-host check alone isn't enough.
        XCTAssertFalse(
            NotifyHubEndpoint.usesPlaintext(host: "localhost:4000", isDefaultHost: false, allowInsecureOverride: false)
        )
    }

    func testExplicitOptInAllowsPlaintextForNonDefaultHost() {
        XCTAssertTrue(
            NotifyHubEndpoint.usesPlaintext(host: "192.168.1.50:4000", isDefaultHost: false, allowInsecureOverride: true)
        )
    }

    func testDefaultHostRemoteLoopbackVariantsStayPlaintext() {
        XCTAssertTrue(
            NotifyHubEndpoint.usesPlaintext(host: "127.0.0.1:4000", isDefaultHost: true, allowInsecureOverride: false)
        )
    }
}
