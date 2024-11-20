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

protocol StreamingClientDelegate {
    func didReceive(event: Mastodon.StreamingEvent, client: StreamingClient)
    func didStateChange(state: StreamingState, client: StreamingClient)
}

class StreamingClient {
    let account: Account
    
    private(set) public var socket: WebSocketClient?
    private(set) public var state: StreamingState = .disconnected {
        didSet {
            self.delegate?.didStateChange(state: self.state, client: self)
        }
    }
    
    var delegate: StreamingClientDelegate?
    
    init(using account: Account) {
        self.account = account
    }
    
    func start(_ configuration: FediverseServerConfiguration) {
        var url = MastodonEndpoint.streaming.url(for: configuration.streamingEndpoint)
        url = url.appending(queryItems: [
            URLQueryItem(name: "access_token", value: self.account.accessToken),
            URLQueryItem(name: "stream", value: "user")
        ])
        
        let socket = WebSocket(request: URLRequest(url: url))
        
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
            print("Received text: \(string)")
        case .binary(let data):
            print("Received data: \(data.count)")
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
            break
        case .peerClosed:
            self.state = .disconnected
            break
        }
    }
}
