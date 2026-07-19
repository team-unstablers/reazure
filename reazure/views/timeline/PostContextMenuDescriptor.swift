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

    /// A nested menu, opened from a row of the parent menu (SwiftUI `Menu` /
    /// a non-inline `UIMenu`).
    struct Submenu {
        let title: String
        let entries: [Entry]
    }

    /// Entries are grouped into sections; renderers insert a separator
    /// (SwiftUI `Divider` / inline `UIMenu`) between them.
    enum Entry {
        /// Non-interactive text row (e.g. the post URL).
        case label(String)
        case action(Action)
        case submenu(Submenu)
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

        var sections: [[Entry]] = []

        if let attachments = attachmentSubmenu(for: canonical, openURL: openURL, present: present) {
            sections.append([.submenu(attachments)])
        }

        sections.append(
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
        )

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

    /// The submenu listing the post's attachments, or `nil` when it has none.
    ///
    /// This is the only way to reach a post's media from the keyboard (the `v`
    /// shortcut), and the only way at all in compact rows, which render no
    /// thumbnails. Non-image media is unreachable otherwise: the timeline draws
    /// thumbnails for images only.
    private static func attachmentSubmenu(
        for status: any StatusAdaptor,
        openURL: @escaping (URL) -> Void,
        present: @escaping (PostRowPresentation) -> Void
    ) -> Submenu? {
        guard !status.attachments.isEmpty else {
            return nil
        }

        let attachments = status.attachments
        // Numbered per kind, so a post carrying two photos and a video reads
        // "사진 #1 / 사진 #2 / 동영상 #1".
        var ordinals: [AttachmentKind: Int] = [:]

        let entries: [Entry] = attachments.map { attachment in
            let kind = AttachmentKind(type: attachment.type)
            let ordinal = (ordinals[kind] ?? 0) + 1
            ordinals[kind] = ordinal

            return .action(Action(title: kind.title(ordinal: ordinal, altText: attachment.altText)) {
                if kind.isViewable {
                    // Deliberately bypasses the sensitive-media reveal the
                    // thumbnails enforce: picking an attachment by name out of a
                    // menu is already an explicit request to see it.
                    guard let context = AttachmentGalleryContext.make(
                        statusId: status.id,
                        attachments: attachments,
                        tappedId: attachment.id
                    ) else {
                        return
                    }

                    present(.gallery(context))
                } else if let url = URL(string: attachment.url) {
                    // The in-app viewer is image-only, so everything else is
                    // handed to the browser.
                    openURL(url)
                }
            })
        }

        return Submenu(title: NSLocalizedString("CONTEXT_MENU_ATTACHMENTS", comment: ""),
                       entries: entries)
    }
}

/// The coarse media kinds the attachment submenu labels and routes differently.
/// Both backends report `AttachmentAdaptor.type` in Mastodon's vocabulary —
/// `MisskeyAttachmentAdaptor` reduces its MIME type to the leading component.
private enum AttachmentKind: Hashable {
    case image
    case video
    /// Mastodon's silent looping MP4 (an uploaded GIF, transcoded).
    case gifv
    case audio
    case unknown

    init(type: String) {
        switch type {
        case "image":
            self = .image
        case "video":
            self = .video
        case "gifv":
            self = .gifv
        case "audio":
            self = .audio
        default:
            self = .unknown
        }
    }

    /// Whether the in-app gallery can display it. Images only; the viewer has no
    /// player.
    var isViewable: Bool {
        self == .image
    }

    private var titleKey: String {
        switch self {
        case .image:
            return "ATTACHMENT_MENU_IMAGE"
        case .video:
            return "ATTACHMENT_MENU_VIDEO"
        case .gifv:
            return "ATTACHMENT_MENU_GIF"
        case .audio:
            return "ATTACHMENT_MENU_AUDIO"
        case .unknown:
            return "ATTACHMENT_MENU_FILE"
        }
    }

    /// e.g. `사진 #1: 창가에 앉은 고양이`, falling back to `사진 #1` when the
    /// author supplied no alternative text.
    func title(ordinal: Int, altText: String?) -> String {
        let label = String(format: NSLocalizedString(titleKey, comment: ""), ordinal)

        guard let altText else {
            return label
        }

        return String(format: NSLocalizedString("ATTACHMENT_MENU_ITEM_WITH_ALT", comment: ""),
                      label,
                      altText.singleLine)
    }
}

private extension String {
    /// Menu rows are a single line; a multi-line alternative text is flattened so
    /// it does not get truncated at its first newline.
    var singleLine: String {
        split(whereSeparator: \.isNewline)
            .joined(separator: " ")
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
            UIMenu(options: .displayInline, children: section.map { $0.asUIMenuElement })
        }

        return UIMenu(title: title, children: children)
    }
}

private extension PostContextMenuDescriptor.Entry {
    var asUIMenuElement: UIMenuElement {
        switch self {
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
        case .submenu(let submenu):
            return UIMenu(title: submenu.title,
                          children: submenu.entries.map { $0.asUIMenuElement })
        }
    }
}
