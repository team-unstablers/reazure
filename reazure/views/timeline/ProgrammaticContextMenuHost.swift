//
//  ProgrammaticContextMenuHost.swift
//  reazure
//
//  Created by Gyuhwan Park on 7/11/26.
//

import Combine
import SwiftUI
import UIKit

/// Invisible overlay that lets a timeline row present its context menu
/// programmatically (the `v` shortcut / ExtKeypad). UIKit offers no public API
/// to present a `UIContextMenuInteraction` without a gesture, so this hosts a
/// hidden `UIButton` whose `UIMenu` is shown via `performPrimaryAction()`
/// (iOS 17.4+). Long-press / right-click stays on the SwiftUI `.contextMenu`.
struct ProgrammaticContextMenuHost: UIViewRepresentable {
    @EnvironmentObject
    var sharedClient: SharedClient

    @Environment(\.openURL)
    var openURL

    @Environment(\.tlFocusState)
    var focusState: TimelineModel.FocusState?

    let model: StatusModel
    let depth: Int
    let presentRequest: AnyPublisher<TimelineModel.FocusState, Never>

    func makeUIView(context: Context) -> PassthroughMenuButton {
        let button = PassthroughMenuButton()
        button.showsMenuAsPrimaryAction = true
        button.isAccessibilityElement = false

        context.coordinator.button = button
        context.coordinator.subscribe(to: presentRequest)

        return button
    }

    func updateUIView(_ uiView: PassthroughMenuButton, context: Context) {
        let model = self.model
        let depth = self.depth
        let ownAccountId = sharedClient.account?.id
        let openURL = self.openURL

        let focusInfo = TimelineModel.FocusState(id: model.id, depth: depth)

        context.coordinator.focusInfo = focusInfo
        context.coordinator.makeMenu = {
            PostContextMenuDescriptor.build(for: model, depth: depth, ownAccountId: ownAccountId) {
                openURL($0)
            }?.asUIMenu()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        weak var button: PassthroughMenuButton?

        var focusInfo: TimelineModel.FocusState?
        var makeMenu: () -> UIMenu? = { nil }

        private var cancellable: AnyCancellable?

        func subscribe(to publisher: AnyPublisher<TimelineModel.FocusState, Never>) {
            cancellable = publisher.sink { [weak self] focusState in
                guard let self = self, focusState == self.focusInfo else {
                    return
                }

                self.present()
            }
        }

        private func present() {
            // `button.window != nil` filters out stale hosts: List keeps
            // detached row views alive in its reuse cache (collapse/expand of
            // a thread churns rows), and those must not answer the request —
            // otherwise one keypress stacks one menu per dead copy.
            guard let button = self.button,
                  button.window != nil,
                  let menu = makeMenu()
            else {
                return
            }

            // The menu is rebuilt on every presentation so it reflects the
            // current favourited/reblogged state of the (masked) status.
            button.menu = menu
            button.performPrimaryAction()
        }
    }
}

/// Hidden anchor button: `hitTest` returns `nil` so the row's tap gesture and
/// `.contextMenu` interaction stay untouched, while `isUserInteractionEnabled`
/// remains true for the menu presentation machinery. The presented menu lives
/// in its own window and is unaffected by this override.
class PassthroughMenuButton: UIButton {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return nil
    }
}
