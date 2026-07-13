//
//  SharedClientSessionTests.swift
//  reazureTests
//
//  End-to-end coverage of the facade's session wiring (roadmap step 4.3's
//  injectable initializer, over 4.2's `use(account:)` / `signOut()`). The
//  injectable `SharedClient.init` lets a non-`.shared` instance run the whole
//  session/streaming path with fakes, so the facade mirroring — account / client
//  / performer sync / timelines / streamingState — is pinned without a network.
//

import Foundation
import Testing

@testable import reazure

@MainActor
struct SharedClientSessionTests {

    private func makeHub(_ provider: FakeWebSocketProvider) -> SharedClient {
        SharedClient(
            socketProvider: provider,
            scheduler: ManualReconnectScheduler(),
            configurationProvider: { _ in .fixture() },
            pathMonitorFactory: { FakePathMonitor() }
        )
    }

    private func eventually(iterations: Int = 500, _ condition: () -> Bool) async {
        for _ in 0..<iterations {
            if condition() { return }
            await flushMainQueue()
        }
    }

    /// AppRootView force-unwraps `timeline[.home]!` / `[.notifications]!` on every
    /// render, including cold launch before any account is selected. A fresh hub
    /// must seed both keys from `init` alone — with no `use()`/`signOut()` first.
    @Test func freshHub_seedsBothTimelinesBeforeAnySession() {
        let hub = makeHub(FakeWebSocketProvider())

        #expect(hub.timeline[.home] != nil)
        #expect(hub.timeline[.notifications] != nil)
        #expect(hub.account == nil)

        withExtendedLifetime(hub) {}
    }

    @Test func use_mirrorsSessionOntoFacadeSurface() async {
        let provider = FakeWebSocketProvider()
        let hub = makeHub(provider)

        hub.use(account: .fixture())

        #expect(hub.account != nil)
        #expect(hub.client != nil)
        #expect(hub.actionPerformer.client === hub.client)   // client → performer mirror
        #expect(hub.timeline[.home] != nil)
        #expect(hub.timeline[.notifications] != nil)

        await eventually { provider.createdSockets.count == 1 }
        #expect(provider.createdSockets.count == 1)          // streaming started

        withExtendedLifetime(hub) {}
    }

    @Test func signOut_returnsFacadeToIdleState() async {
        let provider = FakeWebSocketProvider()
        let hub = makeHub(provider)

        hub.use(account: .fixture())
        await eventually { provider.createdSockets.count == 1 }
        let socket = provider.createdSockets[0]

        hub.signOut()

        #expect(hub.account == nil)
        #expect(hub.client == nil)
        #expect(hub.actionPerformer.client == nil)
        #expect(hub.streamingState == .disconnected)
        #expect(hub.timeline[.home] != nil)                  // idle timelines reseeded
        #expect(hub.timeline[.notifications] != nil)
        #expect(socket.disconnectCount == 1)                 // previous streaming torn down

        withExtendedLifetime(hub) {}
    }

    /// Foreground return drives an immediate reconnect through the facade: a
    /// dropped stream is reopened via `resumeFromBackground()` without
    /// waiting on the backoff.
    @Test func resumeFromBackground_reconnectsCurrentSession() async {
        let provider = FakeWebSocketProvider()
        let hub = makeHub(provider)

        hub.use(account: .fixture())
        await eventually { provider.createdSockets.count == 1 }
        provider.latest?.emit(.connected([:]))
        provider.latest?.emit(.disconnected("x", 1006))   // stream drops

        hub.resumeFromBackground()                   // app returns to foreground

        #expect(provider.createdSockets.count == 2)        // reconnected immediately

        withExtendedLifetime(hub) {}
    }

    @Test func switchingAccounts_tearsDownPreviousStream() async {
        let provider = FakeWebSocketProvider()
        let hub = makeHub(provider)
        let a = Account(id: "a", username: "a", server: .mastodon(address: "a.example"), accessToken: "ta")
        let b = Account(id: "b", username: "b", server: .mastodon(address: "b.example"), accessToken: "tb")

        hub.use(account: a)
        await eventually { provider.createdSockets.count == 1 }
        let socketA = provider.createdSockets[0]

        hub.use(account: b)

        #expect(socketA.disconnectCount == 1)
        #expect(hub.account == b)
        await eventually { provider.createdSockets.count == 2 }

        withExtendedLifetime(hub) {}
    }
}
