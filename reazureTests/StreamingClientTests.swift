//
//  StreamingClientTests.swift
//  reazureTests
//
//  Regression coverage for the `StreamingClient` state machine (roadmap step
//  3.1). Injecting a `WebSocketProviding` factory lets us drive synthetic
//  `WebSocketEvent`s through the delegate path and pin the transport → state
//  transitions, text decoding, and the new failure channel without a network.
//

import Foundation
import Testing
import Starscream

@testable import reazure

private enum StreamingTestError: Error {
    case boom
}

struct StreamingClientTests {

    private func makeClient() -> (StreamingClient, FakeWebSocketProvider, RecordingStreamingDelegate) {
        let provider = FakeWebSocketProvider()
        let client = StreamingClient(using: .fixture(), socketProvider: provider)
        let delegate = RecordingStreamingDelegate()
        client.delegate = delegate
        return (client, provider, delegate)
    }

    // MARK: - start / stop

    @Test func start_buildsSocketWiresDelegateAndConnects() {
        let (client, provider, delegate) = makeClient()

        client.start(.fixture())

        #expect(provider.createdSockets.count == 1)
        #expect(provider.latest?.connectCount == 1)
        #expect(provider.latest?.delegate === client)
        #expect(client.state == .connecting)
        #expect(delegate.states == [.connecting])
    }

    @Test func start_encodesAccessTokenAndUserStream() throws {
        let (client, provider, _) = makeClient()

        client.start(.fixture())

        let url = try #require(provider.lastRequest?.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = components.queryItems ?? []
        #expect(items.contains(URLQueryItem(name: "access_token", value: "token")))
        #expect(items.contains(URLQueryItem(name: "stream", value: "user")))
    }

    @Test func stop_disconnectsTheLiveSocket() {
        let (client, provider, _) = makeClient()
        client.start(.fixture())

        client.stop()

        #expect(provider.latest?.disconnectCount == 1)
    }

    @Test func stop_withoutStart_isNoOp() {
        let (client, provider, _) = makeClient()

        client.stop()

        #expect(provider.createdSockets.isEmpty)
    }

    // MARK: - transport → state transitions

    @Test func connectedEvent_transitionsToConnected() {
        let (client, provider, delegate) = makeClient()
        client.start(.fixture())

        provider.latest?.emit(.connected([:]))

        #expect(client.state == .connected)
        #expect(delegate.states.last == .connected)
    }

    @Test func disconnectedEvent_transitionsToDisconnectedWithoutFailure() {
        let (client, provider, delegate) = makeClient()
        client.start(.fixture())
        provider.latest?.emit(.connected([:]))

        provider.latest?.emit(.disconnected("bye", 1000))

        #expect(client.state == .disconnected)
        #expect(delegate.states.last == .disconnected)
        #expect(delegate.failures.isEmpty)
    }

    @Test func peerClosedEvent_transitionsToDisconnected() {
        let (client, provider, delegate) = makeClient()
        client.start(.fixture())
        provider.latest?.emit(.connected([:]))

        provider.latest?.emit(.peerClosed)

        #expect(client.state == .disconnected)
        #expect(delegate.states.last == .disconnected)
    }

    /// An intentional `stop()` surfaces as `.cancelled`, which must not move the
    /// state (so a reconnect controller keyed off `.disconnected` never fires for
    /// a deliberate teardown). Pins the "stop does not reconnect" invariant.
    @Test func cancelledEvent_doesNotChangeState() {
        let (client, provider, delegate) = makeClient()
        client.start(.fixture())
        provider.latest?.emit(.connected([:]))
        let statesBefore = delegate.states.count

        provider.latest?.emit(.cancelled)

        #expect(client.state == .connected)
        #expect(delegate.states.count == statesBefore)
    }

    // MARK: - failure channel

    @Test func errorEvent_disconnectsAndReportsTransportFailure() {
        let (client, provider, delegate) = makeClient()
        client.start(.fixture())
        provider.latest?.emit(.connected([:]))

        provider.latest?.emit(.error(StreamingTestError.boom))

        #expect(client.state == .disconnected)
        #expect(delegate.states.last == .disconnected)
        #expect(delegate.failures.count == 1)
        if case .transport(let underlying) = delegate.failures.first {
            #expect(underlying is StreamingTestError)
        } else {
            Issue.record("expected a .transport failure")
        }
    }

    // MARK: - text decoding

    @Test func textEvent_decodesAndForwardsStreamingEvent() {
        let (client, provider, delegate) = makeClient()
        client.start(.fixture())

        provider.latest?.emit(.text(#"{"event":"update","payload":"hello"}"#))

        #expect(delegate.events.count == 1)
        #expect(delegate.events.first?.event == "update")
        #expect(delegate.events.first?.payload == "hello")
    }

    @Test func malformedTextEvent_isSwallowedNotForwarded() {
        let (client, provider, delegate) = makeClient()
        client.start(.fixture())

        provider.latest?.emit(.text("this is not json"))

        #expect(delegate.events.isEmpty)
    }

    // MARK: - ping / pong

    @Test func pingEvent_repliesWithPong() {
        let (client, provider, _) = makeClient()
        client.start(.fixture())

        provider.latest?.emit(.ping(nil))

        #expect(provider.latest?.sentPongs == 1)
    }

    // MARK: - delegate ownership

    /// The delegate is held weakly, so a delegate that outlives its owner does
    /// not keep the graph alive. Pins the reference semantics the reconnect
    /// controller relies on to avoid a retain cycle with its client.
    @Test func delegate_isHeldWeakly() {
        let (client, _, _) = makeClient()

        do {
            let transient = RecordingStreamingDelegate()
            client.delegate = transient
            #expect(client.delegate != nil)
        }

        #expect(client.delegate == nil)
    }
}
