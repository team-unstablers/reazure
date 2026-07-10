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
        WebSocket(request: request)
    }
}

class StreamingClient {
    let account: Account

    private let socketProvider: WebSocketProviding

    private(set) public var socket: WebSocketConnecting?
    private(set) public var state: StreamingState = .disconnected {
        didSet {
            self.delegate?.didStateChange(state: self.state, client: self)
        }
    }

    weak var delegate: StreamingClientDelegate?

    init(using account: Account, socketProvider: WebSocketProviding = StarscreamWebSocketProvider()) {
        self.account = account
        self.socketProvider = socketProvider
    }

    func start(_ configuration: FediverseServerConfiguration) {
        var url = MastodonEndpoint.streaming.url(for: configuration.streamingEndpoint)
        url = url.appending(queryItems: [
            URLQueryItem(name: "access_token", value: self.account.accessToken),
            URLQueryItem(name: "stream", value: "user")
        ])

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
        case .disconnected(let reason, let code):
            self.state = .disconnected
        case .text(let string):
            do {
                let event = try JSON.parse(string, to: Mastodon.StreamingEvent.self)
                self.delegate?.didReceive(event: event, client: self)
            } catch {
                print("StreamingClient Error: \(error)")
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
