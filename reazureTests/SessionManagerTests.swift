//
//  SessionManagerTests.swift
//  reazureTests
//
//  Regression coverage for `SessionManager` / `AccountSession` (roadmap step
//  4.2). The per-account collaborators (client, timelines, streaming coordinator,
//  event ingestor) are now built and torn down as a unit. Injecting the streaming
//  seams lets the whole lifecycle run without a network.
//

import Foundation
import Combine
import Testing

@testable import reazure

@MainActor
struct SessionManagerTests {

    // MARK: - harness

    private final class Recorder {
        var states: [StreamingState] = []
        var configurations: [FediverseServerConfiguration] = []
        var backfillCount = 0
    }

    private func silentPreferences() -> PreferencesManager {
        let prefs = PreferencesManager()
        prefs.playSoundOnNotification = false
        prefs.vibrateOnNotification = false
        return prefs
    }

    private func makeEnvironment(_ recorder: Recorder) -> SessionManager.Environment {
        SessionManager.Environment(
            performer: MastodonActionPerformer(replyTo: CurrentValueSubject(nil)),
            presenter: NotificationPresenter(
                preferences: silentPreferences(),
                effects: NotificationPresenter.Effects(playSound: { _ in }, vibrate: {}),
                incrementUnread: {}
            ),
            focusPostArea: {},
            stateDidChange: { recorder.states.append($0) },
            configurationDidLoad: { recorder.configurations.append($0) },
            isNotificationTabActive: { false },
            backfillHome: { recorder.backfillCount += 1 }
        )
    }

    private struct Harness {
        let manager: SessionManager
        let provider: FakeWebSocketProvider
        let scheduler: ManualReconnectScheduler
        let recorder: Recorder
    }

    private func makeManager() -> Harness {
        let provider = FakeWebSocketProvider()
        let scheduler = ManualReconnectScheduler()
        let recorder = Recorder()
        let manager = SessionManager(
            environment: makeEnvironment(recorder),
            socketProvider: provider,
            scheduler: scheduler,
            configurationProvider: { _ in .fixture() },
            pathMonitorFactory: { FakePathMonitor() }
        )
        return Harness(manager: manager, provider: provider, scheduler: scheduler, recorder: recorder)
    }

    private func eventually(iterations: Int = 500, _ condition: () -> Bool) async {
        for _ in 0..<iterations {
            if condition() { return }
            await flushMainQueue()
        }
    }

    private func statusJSON(id: String) -> String {
        let account = #"{"id":"a1","username":"bob","acct":"bob@example.com","url":null,"display_name":"Bob","avatar":"","emojis":[]}"#
        return """
        {"id":"\(id)","created_at":"2024-01-01T00:00:00.000Z","in_reply_to_id":null,"url":null,"visibility":"public","content":"hi","account":\(account),"favourited":false,"reblogged":false,"reblog":null,"emojis":[],"mentions":[],"media_attachments":[],"application":null}
        """
    }

    // MARK: - build

    @Test func use_buildsSessionWithSeededTimelinesAndClient() async {
        let h = makeManager()

        let session = h.manager.use(account: .fixture())

        #expect(h.manager.current === session)
        #expect(session.timelines[.home] != nil)
        #expect(session.timelines[.notifications] != nil)
        await eventually { h.provider.createdSockets.count == 1 }
        #expect(h.provider.createdSockets.count == 1)      // streaming started
        #expect(h.recorder.configurations.count == 1)      // config mirrored
    }

    // MARK: - switch

    @Test func use_again_tearsDownPreviousSessionBeforeBuildingNext() async {
        let h = makeManager()
        let a = Account(id: "a", username: "a", server: .mastodon(address: "a.example"), accessToken: "ta")
        let b = Account(id: "b", username: "b", server: .mastodon(address: "b.example"), accessToken: "tb")

        h.manager.use(account: a)
        await eventually { h.provider.createdSockets.count == 1 }
        let socketA = h.provider.createdSockets[0]

        h.manager.use(account: b)

        #expect(socketA.disconnectCount == 1)              // previous streaming torn down
        #expect(h.manager.current?.account == b)
        await eventually { h.provider.createdSockets.count == 2 }
        #expect(h.provider.createdSockets.count == 2)      // new session connected
    }

    // MARK: - sign out

    @Test func signOut_stopsStreamingAndClearsCurrent() async {
        let h = makeManager()

        h.manager.use(account: .fixture())
        await eventually { h.provider.createdSockets.count == 1 }
        let socket = h.provider.createdSockets[0]

        h.manager.signOut()

        #expect(h.manager.current == nil)
        #expect(socket.disconnectCount == 1)
    }

    @Test func signOut_withoutSession_isNoOp() {
        let h = makeManager()

        h.manager.signOut()

        #expect(h.manager.current == nil)
        #expect(h.provider.createdSockets.isEmpty)
    }

    // MARK: - end-to-end wiring

    /// The coordinator → ingestor → timeline chain, wired entirely inside the
    /// session: a decoded `update` event lands in the session's home timeline.
    @Test func decodedUpdateEvent_landsInSessionHomeTimeline() async {
        let h = makeManager()

        let session = h.manager.use(account: .fixture())
        await eventually { h.provider.createdSockets.count == 1 }

        h.provider.latest?.emit(.connected([:]))
        h.provider.latest?.emit(.text(#"{"event":"update","payload":\#(jsonString(statusJSON(id: "s-1")))}"#))
        await flushMainQueue()

        #expect(session.timelines[.home]?.statuses.count == 1)
        #expect(session.timelines[.home]?.statuses.first?.id == "s-1")
    }

    /// Encodes a JSON document as a JSON string literal (Mastodon nests the status
    /// payload as a string inside the streaming envelope).
    private func jsonString(_ raw: String) -> String {
        let data = try! JSONSerialization.data(withJSONObject: raw, options: [.fragmentsAllowed])
        return String(data: data, encoding: .utf8)!
    }
}
