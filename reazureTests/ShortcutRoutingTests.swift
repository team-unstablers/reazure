//
//  ShortcutRoutingTests.swift
//  reazureTests
//
//  Regression coverage for the `ShortcutRouting` seam (roadmap step 2.3). The
//  UIKit `ShortcutHandlerInternal` used to hard-reference `SharedClient.shared`;
//  it now dispatches through an injected router, so this pins that key presses
//  reach whatever router was wired in.
//

import Testing

@testable import reazure

/// Records the shortcut keys dispatched through the routing seam. Keys are
/// captured as their case description to avoid depending on `ShortcutKey`
/// `Equatable` synthesis.
@MainActor
final class RecordingShortcutRouter: ShortcutRouting {
    private(set) var received: [String] = []

    func handleShortcut(key: ShortcutKey) {
        received.append(String(describing: key))
    }
}

@MainActor
struct ShortcutRoutingTests {

    @Test func internalHandlers_dispatchThroughInjectedRouter() {
        let router = RecordingShortcutRouter()
        let controller = ShortcutHandlerInternal(router: router)

        controller.handlerH()
        controller.handlerJ()
        controller.handlerK()
        controller.handlerL()
        controller.handlerF()
        controller.handlerR()
        controller.handlerT()
        controller.handlerV()
        controller.handlerU()

        #expect(router.received == ["h", "j", "k", "l", "f", "r", "t", "v", "u"])
    }
}
