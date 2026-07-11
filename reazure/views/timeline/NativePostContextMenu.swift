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

    var body: some View {
        if let descriptor = PostContextMenuDescriptor.build(
            for: model,
            depth: depth,
            ownAccountId: sharedClient.account?.id,
            openURL: { openURL($0) }
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

    @ViewBuilder
    private func render(_ entry: PostContextMenuDescriptor.Entry) -> some View {
        switch entry {
        case .label(let text):
            Text(text)
        case .action(let action):
            Button(action.title, role: action.destructive ? .destructive : nil) {
                action.handler()
            }
            .disabled(action.disabled)
        }
    }
}
