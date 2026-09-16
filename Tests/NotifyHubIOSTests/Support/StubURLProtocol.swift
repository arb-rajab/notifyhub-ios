import Foundation

/// A `URLProtocol` stub for exercising `GraphQLClient` against canned
/// HTTP responses without any real network access - lets tests assert on
/// the exact outgoing request (body, headers) as well as how the client
/// reacts to a given response, the same "verify the real request/response
/// contract" spirit as notifyhub's own APNs HTTP/2 tests
/// (`tests/unit/apnsHttpClient.test.ts`), adapted to what's practical on
/// this side without a local server.
final class StubURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Data, HTTPURLResponse))?

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        do {
            let (data, response) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

extension URLRequest {
    /// `URLSession` sometimes hands a custom `URLProtocol` the request
    /// body as `httpBodyStream` instead of `httpBody`, even when the
    /// caller set `httpBody` directly - a known quirk of testing via
    /// `URLProtocol`. This reads whichever one is actually present.
    func capturedBodyData() -> Data {
        if let body = httpBody { return body }
        guard let stream = httpBodyStream else { return Data() }

        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 4096
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        while stream.hasBytesAvailable {
            let bytesRead = stream.read(&buffer, maxLength: bufferSize)
            guard bytesRead > 0 else { break }
            data.append(buffer, count: bytesRead)
        }
        return data
    }

    func capturedBodyJSON() -> [String: Any]? {
        try? JSONSerialization.jsonObject(with: capturedBodyData()) as? [String: Any]
    }
}
