//
//  StreamingClient.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/9/24.
//

import Foundation
import Starscream

enum StreamingState {
    case connecting
    case connected
    case disconnected
}

/// A transport-level failure surfaced separately from an ordinary `.disconnected`
/// transition, so a reconnect controller can treat a genuine error (handshake
/// rejection, network drop) differently from a routine disconnect. Resolves the
/// former `// FIXME: error handler`.
enum StreamingClientError: Error {
    case transport(Error?)
}

protocol StreamingClientDelegate: AnyObject {
    func didReceive(event: Mastodon.StreamingEvent, client: StreamingClient)
    func didStateChange(state: StreamingState, client: StreamingClient)
    func streamingClient(_ client: StreamingClient, didFailWith error: StreamingClientError)
}

extension StreamingClientDelegate {
    /// Default no-op so conformers adopt the failure channel incrementally; the
    /// reconnect controller consumes it.
    func streamingClient(_ client: StreamingClient, didFailWith error: StreamingClientError) {}
}

/// The slice of a Starscream `WebSocket` that `StreamingClient` drives, declared
/// as a protocol (refining Starscream's `WebSocketClient`) so a synthetic socket
/// can be injected in tests. The concrete `WebSocket` conforms as-is.
protocol WebSocketConnecting: WebSocketClient {
    var delegate: WebSocketDelegate? { get set }
}

extension WebSocket: WebSocketConnecting {}

/// Factory seam producing a `WebSocketConnecting` for a request. Injected into
/// `StreamingClient` so `start()` no longer hard-instantiates a `WebSocket`,
/// which was the only barrier to exercising the state machine without a network.
protocol WebSocketProviding {
    func webSocket(with request: URLRequest) -> WebSocketConnecting
}

/// Live factory backed by Starscream.
struct StarscreamWebSocketProvider: WebSocketProviding {
    func webSocket(with request: URLRequest) -> WebSocketConnecting {
        let socket = WebSocket(request: request)
        // Pin delivery to the main queue explicitly. `StreamingCoordinator`
        // confines its state to the main thread and relies on delegate callbacks
        // arriving there; this makes that guarantee local rather than an implicit
        // dependency on Starscream's default `callbackQueue`.
        socket.callbackQueue = .main
        return socket
    }
}

/// Per-server strategy for the otherwise shared `StreamingClient` state machine.
///
/// The reconnect/backoff/ping-pong/delegate machinery is identical across
/// backends; only three things differ — the socket URL, an optional on-connect
/// step (Mastodon needs none; Misskey subscribes to channels), and how an inbound
/// text frame becomes a `Mastodon.StreamingEvent` envelope. Keeping this a
/// strategy (rather than protocolizing the whole client) leaves the delegate
/// signatures — and every streaming test — unchanged.
protocol StreamingProtocolAdapter {
    /// The WebSocket URL to dial for this account/configuration.
    func url(account: Account, configuration: FediverseServerConfiguration) -> URL
    /// Called once the socket connects. `send` writes a text frame back over the
    /// socket. Mastodon is a no-op; Misskey sends its channel-subscription frames.
    func onConnected(send: (String) -> Void)
    /// Translates an inbound text frame into the shared streaming envelope, or
    /// `nil` to drop the frame.
    func translate(text: String) -> Mastodon.StreamingEvent?
}

/// Mastodon strategy: the `user` stream over `/api/v1/streaming`, no on-connect
/// step, and a straight envelope parse — i.e. the pre-strategy behaviour.
struct MastodonStreamingAdapter: StreamingProtocolAdapter {
    func url(account: Account, configuration: FediverseServerConfiguration) -> URL {
        var url = MastodonEndpoint.streaming.url(for: configuration.streamingEndpoint)
        url = url.appending(queryItems: [
            URLQueryItem(name: "access_token", value: account.accessToken),
            URLQueryItem(name: "stream", value: "user")
        ])
        return url
    }

    func onConnected(send: (String) -> Void) {}

    func translate(text: String) -> Mastodon.StreamingEvent? {
        try? JSON.parse(text, to: Mastodon.StreamingEvent.self)
    }
}

class StreamingClient {
    let account: Account

    private let socketProvider: WebSocketProviding
    private let adapter: StreamingProtocolAdapter

    private(set) public var socket: WebSocketConnecting?
    private(set) public var state: StreamingState = .disconnected {
        didSet {
            self.delegate?.didStateChange(state: self.state, client: self)
        }
    }

    weak var delegate: StreamingClientDelegate?

    init(using account: Account,
         socketProvider: WebSocketProviding = StarscreamWebSocketProvider(),
         adapter: StreamingProtocolAdapter = MastodonStreamingAdapter()) {
        self.account = account
        self.socketProvider = socketProvider
        self.adapter = adapter
    }

    func start(_ configuration: FediverseServerConfiguration) {
        let url = adapter.url(account: self.account, configuration: configuration)

        let socket = socketProvider.webSocket(with: URLRequest(url: url))

        self.state = .connecting

        socket.delegate = self
        socket.connect()

        self.socket = socket
    }

    func stop() {
        guard let socket = self.socket else {
            return
        }

        socket.disconnect()
    }
}

extension StreamingClient: WebSocketDelegate {
    func didReceive(event: WebSocketEvent, client: WebSocketClient) {
        switch event {
        case .connected(let headers):
            self.state = .connected
            // Per-server on-connect step (Mastodon: none; Misskey: subscribe to
            // its `homeTimeline` / `main` channels).
            self.adapter.onConnected(send: { [weak self] message in
                self?.socket?.write(string: message, completion: nil)
            })
        case .disconnected(let reason, let code):
            self.state = .disconnected
        case .text(let string):
            if let event = self.adapter.translate(text: string) {
                self.delegate?.didReceive(event: event, client: self)
            }
        case .binary(let data):
            break
        case .ping(_):
            self.socket?.write(pong: Data())
            break
        case .pong(_):
            break
        case .viabilityChanged(_):
            break
        case .reconnectSuggested(_):
            break
        case .cancelled:
            break
        case .error(let error):
            self.state = .disconnected
            self.delegate?.streamingClient(self, didFailWith: .transport(error))
            break
        case .peerClosed:
            self.state = .disconnected
            break
        }
    }
}
