//
//  NativePostContextMenu.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/25/24.
//

import SwiftUI

/// SwiftUI renderer of `PostContextMenuDescriptor`, used as the `.contextMenu`
/// content (long-press / right-click). The `v` shortcut renders the same
/// descriptor as a `UIMenu` instead (`ProgrammaticContextMenuHost`).
struct NativePostContextMenuInner: View {
    @EnvironmentObject
    var sharedClient: SharedClient

    @Environment(\.openURL)
    var openURL

    @ObservedObject
    var model: StatusModel

    let depth: Int

    /// Asks the row to present a modal (confirmation / report sheet).
    let present: (PostRowPresentation) -> Void

    var body: some View {
        if let descriptor = PostContextMenuDescriptor.build(
            for: model,
            depth: depth,
            ownAccountId: sharedClient.account?.id,
            openURL: { openURL($0) },
            supportsReportForwarding: sharedClient.account?.server.supportsReportForwarding ?? false,
            present: present
        ) {
            Group {
                ActivityPubMarkupText(content: descriptor.header.text,
                                      emojos: descriptor.header.emojis)

                ForEach(Array(descriptor.sections.enumerated()), id: \.offset) { _, section in
                    Divider()

                    ForEach(Array(section.enumerated()), id: \.offset) { _, entry in
                        render(entry)
                    }
                }
            }
        }
    }

    /// Erased to `AnyView` because `.submenu` renders its own entries: an opaque
    /// return type cannot recursively reference itself. Menus hold a handful of
    /// rows and are rebuilt per presentation, so the erasure costs nothing here.
    private func render(_ entry: PostContextMenuDescriptor.Entry) -> AnyView {
        switch entry {
        case .label(let text):
            return AnyView(Text(text))
        case .action(let action):
            return AnyView(
                Button(action.title, role: action.destructive ? .destructive : nil) {
                    action.handler()
                }
                .disabled(action.disabled)
            )
        case .submenu(let submenu):
            return AnyView(
                Menu(submenu.title) {
                    ForEach(Array(submenu.entries.enumerated()), id: \.offset) { _, entry in
                        render(entry)
                    }
                }
            )
        }
    }
}
