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

    @Test func internalHandlers_dispatchThroughInjectedRouter() async throws {
        let router = RecordingShortcutRouter()
        let controller = ShortcutHandlerInternal(router: router)

        controller.handlerH()
        controller.handlerJ()
        controller.handlerK()
        controller.handlerL()
        controller.handlerF()
        controller.handlerR()
        controller.handlerT()
        controller.handlerU()

        // 동기 핸들러는 즉시 라우터로 전달된다.
        #expect(router.received == ["h", "j", "k", "l", "f", "r", "t", "u"])

        // handlerV는 UIKit 무한 루프 우회를 위해 약 0.2초 지연 후 라우팅된다
        // (ShortcutHandler.handlerV 참조). 도착할 때까지 여유를 두고 기다린다.
        controller.handlerV()

        for _ in 0..<50 where !router.received.contains("v") {
            try await Task.sleep(for: .milliseconds(20))
        }

        #expect(router.received == ["h", "j", "k", "l", "f", "r", "t", "u", "v"])
    }
}
