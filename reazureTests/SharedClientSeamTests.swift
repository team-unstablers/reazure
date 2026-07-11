//
//  SharedClientSeamTests.swift
//  reazureTests
//
//  Integration coverage that pins the Phase 2 wiring on the `SharedClient`
//  facade itself, not just the extracted collaborators in isolation. An
//  adversarial review of the decomposition flagged that the earlier per-seam
//  tests could stay green even if the facade mis-wired the collaborator (a nil
//  mirror, a private reply subject, a removed `.u` handler). These lock the
//  facade side of each seam.
//
//  These touch the `SharedClient.shared` singleton, so the suite is
//  `.serialized` and every test restores the state it mutates in a `defer`.
//

import Testing

@testable import reazure

@Suite(.serialized)
@MainActor
struct SharedClientSeamTests {

    // MARK: - 2.1 client → performer mirror

    /// The performer only reaches the network because `SharedClient.client`'s
    /// `didSet` mirrors the active client into it. If that wiring is dropped,
    /// every write action silently no-ops — so pin it at the facade.
    @Test func settingClient_mirrorsIntoActionPerformer() {
        let hub = SharedClient.shared
        let previousClient = hub.client
        defer { hub.client = previousClient }

        let account = Account(id: "acc-1",
                              username: "tester",
                              server: .mastodon(address: "example.com"),
                              accessToken: "token")
        let client = MastodonClient(using: account)

        hub.client = client

        #expect(hub.actionPerformer.client === client)
    }

    // MARK: - 2.1 replyTo facade identity (intentionally not pinned here)
    //
    // The other high-value seam is that the performer publishes onto the *same*
    // `replyTo` subject `PostArea` subscribes to. It cannot be pinned against the
    // live `SharedClient.shared`: publishing a non-nil reply target onto the real
    // subject synchronously runs the app's live `PostArea.onReceive` subscriber,
    // which force-unwraps `sharedClient.account!` (PostArea.swift) — nil in the
    // test host — and traps. (That trap is itself evidence the wiring is correct:
    // the send reached PostArea, so `actionPerformer.replyTo === hub.replyTo`.)
    // Pinning it cleanly needs either a client/account seam (Phase 4) or hardening
    // that force-unwrap, both out of scope for this structural refactor. The
    // performer-side publish is covered in `MastodonActionPerformerTests`.

    // MARK: - 2.4 production .u handler

    /// In production `.u` is intercepted by `SharedClient.handleShortcut` (it
    /// never reaches `TimelineModel`), toggling the composer focus. That real
    /// path had no coverage; pin it here.
    @Test func handleShortcutU_togglesPostAreaFocused() {
        let hub = SharedClient.shared
        let previous = hub.postAreaFocused
        defer { hub.postAreaFocused = previous }

        hub.postAreaFocused = false
        hub.handleShortcut(key: .u)

        #expect(hub.postAreaFocused == true)
    }

    // MARK: - 2.4 focusPostArea is .u-only

    /// The injected `focusPostArea` closure must fire for `.u` only; a stray
    /// fallthrough that toggled the composer on j/k/h/l would be a regression.
    @Test func handleShortcut_nonUKeys_doNotInvokeFocusPostArea() {
        var toggleCount = 0
        let timeline = TimelineModel(focusPostArea: { toggleCount += 1 })

        for key in [ShortcutKey.h, .j, .k, .l, .f, .r, .t, .v] {
            timeline.handleShortcut(key)
        }

        #expect(toggleCount == 0)
    }
}
