//
//  PostContextMenuDescriptor.swift
//  reazure
//
//  Created by Gyuhwan Park on 7/11/26.
//

import SwiftUI
import UIKit

/// Menu-item description shared by both post context menu renderers, so the
/// item set lives in one place: the SwiftUI `.contextMenu` (long-press /
/// right-click) and the `UIMenu` presented programmatically for the `v`
/// shortcut / ExtKeypad (`ProgrammaticContextMenuHost`).
struct PostContextMenuDescriptor {
    struct Header {
        let text: String
        let emojis: [EmojiAdaptor]
    }

    struct Action {
        let title: String
        var destructive: Bool = false
        var disabled: Bool = false
        let handler: () -> Void
    }

    /// Entries are grouped into sections; renderers insert a separator
    /// (SwiftUI `Divider` / inline `UIMenu`) between them.
    enum Entry {
        /// Non-interactive text row (e.g. the post URL).
        case label(String)
        case action(Action)
    }

    let header: Header
    let sections: [[Entry]]
}

extension PostContextMenuDescriptor {
    /// Builds the menu for the status at `depth` of `model`. Returns `nil`
    /// while the status at that depth is not resolved yet.
    ///
    /// - Parameters:
    ///   - supportsReportForwarding: whether this account's server can forward a
    ///     report to the instance hosting the reported account (Mastodon can,
    ///     Misskey cannot).
    ///   - present: asks the row to present a modal. The moderation actions go
    ///     through this rather than acting immediately, because they are
    ///     destructive and are confirmed (block/delete) or composed (report) first.
    static func build(
        for model: StatusModel,
        depth: Int,
        ownAccountId: String?,
        openURL: @escaping (URL) -> Void,
        supportsReportForwarding: Bool = false,
        present: @escaping (PostRowPresentation) -> Void = { _ in }
    ) -> PostContextMenuDescriptor? {
        guard let status = model.resolve(depth: depth) else {
            return nil
        }

        let canonical = status.canonical

        let header = Header(
            text: "\(canonical.account.displayName) (@\(canonical.account.acct))",
            emojis: canonical.account.emojis
        )

        var sections: [[Entry]] = [
            [
                .action(Action(title: NSLocalizedString("CONTEXT_MENU_REPLY", comment: "")) {
                    Task {
                        try? await model.composeReply(to: depth)
                    }
                }),
                .action(Action(
                    title: NSLocalizedString(
                        canonical.reblogged ? "CONTEXT_MENU_UNREBLOG" : "CONTEXT_MENU_REBLOG",
                        comment: ""
                    ),
                    disabled: !canonical.visibility.isRebloggable
                ) {
                    Task {
                        try? await model.toggleReblog(of: depth)
                    }
                }),
                .action(Action(
                    title: NSLocalizedString(
                        canonical.favourited ? "CONTEXT_MENU_UNFAVOURITE" : "CONTEXT_MENU_FAVOURITE",
                        comment: ""
                    )
                ) {
                    Task {
                        try? await model.toggleFavourite(of: depth)
                    }
                }),
            ]
        ]

        if let urlString = canonical.url,
           let url = URL(string: urlString) {
            sections.append([.label(urlString)])

            sections.append([
                .action(Action(title: NSLocalizedString("CONTEXT_MENU_COPY_URL", comment: "")) {
                    UIPasteboard.general.string = urlString
                }),
                .action(Action(title: NSLocalizedString("CONTEXT_MENU_SHARE", comment: "")) {
                    let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                    UIApplication.shared.windows.first?.rootViewController?.present(activityVC, animated: true, completion: nil)
                }),
                .action(Action(title: NSLocalizedString("CONTEXT_MENU_OPEN_IN_BROWSER", comment: "")) {
                    openURL(url)
                }),
            ])
        }

        if canonical.account.id == ownAccountId {
            sections.append([
                .action(Action(title: NSLocalizedString("CONTEXT_MENU_DELETE", comment: ""), destructive: true) {
                    present(.confirm(PostRowConfirmation(kind: .delete, acct: canonical.account.acct) {
                        Task {
                            try? await model.delete(depth: depth)
                        }
                    }))
                })
            ])
        } else {
            // Moderation. Only ever offered for someone else's post: a report of
            // your own post is meaningless, and both backends refuse a self-block.
            sections.append([
                .action(Action(title: NSLocalizedString("CONTEXT_MENU_REPORT", comment: ""), destructive: true) {
                    present(.report(PostReportTarget(
                        accountId: canonical.account.id,
                        acct: canonical.account.acct,
                        statusId: canonical.id,
                        statusUrl: canonical.url,
                        // Only a remote account (`user@host`) has another instance
                        // a report could be forwarded to.
                        canForward: supportsReportForwarding && canonical.account.acct.contains("@"),
                        submit: { request in
                            do {
                                try await model.report(request)
                                return true
                            } catch {
                                return false
                            }
                        }
                    )))
                }),
                .action(Action(title: NSLocalizedString("CONTEXT_MENU_BLOCK", comment: ""), destructive: true) {
                    present(.confirm(PostRowConfirmation(kind: .block, acct: canonical.account.acct) {
                        Task {
                            try? await model.blockAuthor(of: depth)
                        }
                    }))
                }),
            ])
        }

        return PostContextMenuDescriptor(header: header, sections: sections)
    }
}

extension PostContextMenuDescriptor {
    /// `UIMenu` renderer for programmatic presentation. `UIMenu` cannot render
    /// custom emojis, so their shortcodes are stripped from the title.
    func asUIMenu() -> UIMenu {
        let title = header.emojis.reduce(header.text) { text, emoji in
            text.replacingOccurrences(of: ":\(emoji.shortcode):", with: "")
        }

        let children = sections.map { section in
            UIMenu(options: .displayInline, children: section.map { entry in
                switch entry {
                case .label(let text):
                    return UIAction(title: text, attributes: .disabled) { _ in }
                case .action(let action):
                    var attributes: UIMenuElement.Attributes = []
                    if action.destructive {
                        attributes.insert(.destructive)
                    }
                    if action.disabled {
                        attributes.insert(.disabled)
                    }

                    return UIAction(title: action.title, attributes: attributes) { _ in
                        action.handler()
                    }
                }
            })
        }

        return UIMenu(title: title, children: children)
    }
}
