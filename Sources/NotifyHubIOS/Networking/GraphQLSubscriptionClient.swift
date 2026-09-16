import Foundation

/// A minimal `graphql-transport-ws` client (the protocol notifyhub's own
/// server speaks - see notifyhub's ADR-002 and `src/graphql/wsServer.ts`),
/// built on `URLSessionWebSocketTask` rather than a GraphQL client
/// dependency. The protocol surface notifyhub actually uses is small:
/// `connection_init` -> `connection_ack`, then `subscribe` -> a stream of
/// `next` messages -> `complete`, plus `ping`/`pong` keepalives.
actor GraphQLSubscriptionClient {
    enum ClientError: Error, LocalizedError {
        case connectionClosed
        case invalidMessage
        case serverError(String)

        var errorDescription: String? {
            switch self {
            case .connectionClosed: return "The real-time connection closed unexpectedly."
            case .invalidMessage: return "Received a malformed message from the server."
            case .serverError(let message): return message
            }
        }
    }

    private let url: URL
    private var webSocketTask: URLSessionWebSocketTask?
    private var subscriptionHandlers: [String: (Result<[String: Any], Error>) -> Void] = [:]
    private var didReceiveAck = false
    private var ackWaiters: [CheckedContinuation<Void, Error>] = []
    private var receiveLoopTask: Task<Void, Never>?

    init(url: URL) {
        self.url = url
    }

    /// `authorization` matches notifyhub's expected
    /// `connectionParams.authorization` value: `"Bearer <token>"`, the
    /// same format as the HTTP header (see notifyhub's
    /// `authenticateFromConnectionParams`).
    func connect(authorization: String?) async throws {
        var request = URLRequest(url: url)
        request.setValue("graphql-transport-ws", forHTTPHeaderField: "Sec-WebSocket-Protocol")
        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: request)
        webSocketTask = task
        task.resume()

        receiveLoopTask = Task { [weak self] in
            await self?.receiveLoop()
        }

        var initPayload: [String: Any] = [:]
        if let authorization {
            initPayload["authorization"] = authorization
        }
        try await sendJSON(["type": "connection_init", "payload": initPayload])

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            if didReceiveAck {
                continuation.resume()
            } else {
                ackWaiters.append(continuation)
            }
        }
    }

    func subscribe(
        id: String,
        query: String,
        variables: [String: Any] = [:],
        onEvent: @escaping (Result<[String: Any], Error>) -> Void
    ) async throws {
        subscriptionHandlers[id] = onEvent
        try await sendJSON([
            "type": "subscribe",
            "id": id,
            "payload": ["query": query, "variables": variables],
        ])
    }

    func unsubscribe(id: String) async {
        subscriptionHandlers[id] = nil
        try? await sendJSON(["type": "complete", "id": id])
    }

    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        receiveLoopTask?.cancel()
        failAllSubscriptions(with: ClientError.connectionClosed)
    }

    private func sendJSON(_ object: [String: Any]) async throws {
        guard let task = webSocketTask else { throw ClientError.connectionClosed }
        let data = try JSONSerialization.data(withJSONObject: object)
        guard let text = String(data: data, encoding: .utf8) else { throw ClientError.invalidMessage }
        try await task.send(.string(text))
    }

    private func receiveLoop() async {
        guard let task = webSocketTask else { return }
        while !Task.isCancelled {
            do {
                let message = try await task.receive()
                await handle(message: message)
            } catch {
                failAllSubscriptions(with: error)
                return
            }
        }
    }

    private func handle(message: URLSessionWebSocketTask.Message) async {
        let text: String
        switch message {
        case .string(let string):
            text = string
        case .data(let data):
            text = String(decoding: data, as: UTF8.self)
        default:
            return
        }

        guard
            let data = text.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let type = object["type"] as? String
        else {
            return
        }

        switch type {
        case "connection_ack":
            didReceiveAck = true
            ackWaiters.forEach { $0.resume() }
            ackWaiters.removeAll()

        case "ping":
            try? await sendJSON(["type": "pong"])

        case "next":
            guard let id = object["id"] as? String, let payload = object["payload"] as? [String: Any] else { return }
            if let dataPayload = payload["data"] as? [String: Any] {
                subscriptionHandlers[id]?(.success(dataPayload))
            } else if
                let errors = payload["errors"] as? [[String: Any]],
                let message = errors.first?["message"] as? String
            {
                subscriptionHandlers[id]?(.failure(ClientError.serverError(message)))
            }

        case "error":
            guard let id = object["id"] as? String else { return }
            let message = (object["payload"] as? [[String: Any]])?.first?["message"] as? String ?? "Subscription error."
            subscriptionHandlers[id]?(.failure(ClientError.serverError(message)))
            subscriptionHandlers[id] = nil

        case "complete":
            guard let id = object["id"] as? String else { return }
            subscriptionHandlers[id] = nil

        default:
            break
        }
    }

    private func failAllSubscriptions(with error: Error) {
        for (_, handler) in subscriptionHandlers {
            handler(.failure(error))
        }
        subscriptionHandlers.removeAll()
        for waiter in ackWaiters {
            waiter.resume(throwing: error)
        }
        ackWaiters.removeAll()
    }
}
