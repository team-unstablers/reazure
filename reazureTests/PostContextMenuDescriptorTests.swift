//
//  PostContextMenuDescriptorTests.swift
//  reazureTests
//
//  Coverage for the shared context-menu descriptor — the single source of
//  truth behind both the SwiftUI `.contextMenu` and the `UIMenu` presented
//  programmatically by the `v` shortcut. Pins the section composition for each
//  status shape and the `UIMenu` rendering of every entry kind.
//

import Testing
import UIKit

@testable import reazure

private struct FakeEmojiAdaptor: EmojiAdaptor {
    var shortcode: String
    var url: String = ""
}

@MainActor
struct PostContextMenuDescriptorTests {

    private func build(
        _ adaptor: FakeStatusAdaptor,
        depth: Int = 0,
        ownAccountId: String? = nil,
        model: StatusModel? = nil,
        supportsReportForwarding: Bool = false,
        openURL: @escaping (URL) -> Void = { _ in },
        present: @escaping (PostRowPresentation) -> Void = { _ in }
    ) -> PostContextMenuDescriptor? {
        PostContextMenuDescriptor.build(
            for: model ?? StatusModel(adaptor: adaptor),
            depth: depth,
            ownAccountId: ownAccountId,
            openURL: openURL,
            supportsReportForwarding: supportsReportForwarding,
            present: present
        )
    }

    private func reportTarget(
        for adaptor: FakeStatusAdaptor,
        supportsReportForwarding: Bool = false
    ) throws -> PostReportTarget {
        var presented: [PostRowPresentation] = []
        let descriptor = try #require(build(adaptor,
                                            ownAccountId: "me",
                                            supportsReportForwarding: supportsReportForwarding,
                                            present: { presented.append($0) }))

        try invoke(localized("CONTEXT_MENU_REPORT"), in: descriptor)

        guard case .report(let target) = try #require(presented.first) else {
            throw ReportTargetMissing()
        }
        return target
    }

    private struct ReportTargetMissing: Error {}

    /// Fires the action with `title`, wherever it sits in the menu.
    private func invoke(_ title: String, in descriptor: PostContextMenuDescriptor) throws {
        let action = descriptor.sections
            .flatMap { $0 }
            .compactMap { entry -> PostContextMenuDescriptor.Action? in
                if case .action(let action) = entry {
                    return action
                }
                return nil
            }
            .first { $0.title == title }

        try #require(action, "no action titled \(title)").handler()
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    private func actionTitles(in section: [PostContextMenuDescriptor.Entry]) -> [String] {
        section.compactMap {
            if case .action(let action) = $0 {
                return action.title
            }
            return nil
        }
    }

    /// The attachment submenu, which the descriptor prepends as its own section.
    private func attachmentSubmenu(
        in descriptor: PostContextMenuDescriptor
    ) throws -> PostContextMenuDescriptor.Submenu {
        let submenu = descriptor.sections
            .flatMap { $0 }
            .compactMap { entry -> PostContextMenuDescriptor.Submenu? in
                if case .submenu(let submenu) = entry {
                    return submenu
                }
                return nil
            }
            .first

        return try #require(submenu, "no submenu in the descriptor")
    }

    private func attachmentTitles(in descriptor: PostContextMenuDescriptor) throws -> [String] {
        actionTitles(in: try attachmentSubmenu(in: descriptor).entries)
    }

    /// Fires the attachment entry at `index` of the submenu.
    private func invokeAttachment(_ index: Int, in descriptor: PostContextMenuDescriptor) throws {
        let entries = try attachmentSubmenu(in: descriptor).entries
        try #require(entries.indices.contains(index), "no attachment entry at \(index)")

        guard case .action(let action) = entries[index] else {
            Issue.record("expected an action entry at \(index)")
            return
        }
        action.handler()
    }

    // MARK: - build

    @Test func basicStatus_hasHeaderActionSectionAndModeration() throws {
        let descriptor = try #require(build(FakeStatusAdaptor()))

        #expect(descriptor.header.text == "Tester (@tester@example.com)")
        // Someone else's post (no `ownAccountId` matches), so it is reportable.
        #expect(descriptor.sections.count == 2)
        #expect(actionTitles(in: descriptor.sections[0]) == [
            localized("CONTEXT_MENU_REPLY"),
            localized("CONTEXT_MENU_REBLOG"),
            localized("CONTEXT_MENU_FAVOURITE"),
        ])
        #expect(actionTitles(in: descriptor.sections[1]) == [
            localized("CONTEXT_MENU_REPORT"),
            localized("CONTEXT_MENU_BLOCK"),
        ])
    }

    @Test func flaggedStatus_usesUndoTitles() throws {
        let descriptor = try #require(build(FakeStatusAdaptor(favourited: true, reblogged: true)))

        #expect(actionTitles(in: descriptor.sections[0]) == [
            localized("CONTEXT_MENU_REPLY"),
            localized("CONTEXT_MENU_UNREBLOG"),
            localized("CONTEXT_MENU_UNFAVOURITE"),
        ])
    }

    @Test func privateStatus_disablesReblog() throws {
        let descriptor = try #require(build(FakeStatusAdaptor(visibility: .privateType)))

        guard case .action(let reblog) = descriptor.sections[0][1] else {
            Issue.record("expected an action entry for reblog")
            return
        }

        #expect(reblog.disabled)
    }

    @Test func statusWithURL_appendsLinkSections() throws {
        let url = "https://example.com/@tester/1"
        let descriptor = try #require(build(FakeStatusAdaptor(url: url)))

        // actions, url label, url actions, moderation
        #expect(descriptor.sections.count == 4)

        guard case .label(let text) = descriptor.sections[1][0] else {
            Issue.record("expected a label entry for the URL")
            return
        }
        #expect(text == url)

        #expect(actionTitles(in: descriptor.sections[2]) == [
            localized("CONTEXT_MENU_COPY_URL"),
            localized("CONTEXT_MENU_SHARE"),
            localized("CONTEXT_MENU_OPEN_IN_BROWSER"),
        ])
    }

    @Test func ownStatus_appendsDestructiveDelete() throws {
        let adaptor = FakeStatusAdaptor(account: FakeAccountAdaptor(id: "me"))
        let descriptor = try #require(build(adaptor, ownAccountId: "me"))

        guard case .action(let delete) = try #require(descriptor.sections.last?.first) else {
            Issue.record("expected an action entry for delete")
            return
        }

        #expect(delete.title == localized("CONTEXT_MENU_DELETE"))
        #expect(delete.destructive)
    }

    @Test func othersStatus_hasNoDelete() throws {
        let adaptor = FakeStatusAdaptor(account: FakeAccountAdaptor(id: "someone-else"))
        let descriptor = try #require(build(adaptor, ownAccountId: "me"))

        #expect(!actionTitles(in: try #require(descriptor.sections.last))
            .contains(localized("CONTEXT_MENU_DELETE")))
    }

    // MARK: - attachments

    @Test func statusWithoutAttachments_hasNoAttachmentSubmenu() throws {
        let descriptor = try #require(build(FakeStatusAdaptor()))

        let submenus = descriptor.sections.flatMap { $0 }.filter {
            if case .submenu = $0 {
                return true
            }
            return false
        }
        #expect(submenus.isEmpty)
    }

    /// The submenu leads the menu, ahead of the reply/reblog/favourite section.
    @Test func statusWithAttachments_prependsAttachmentSubmenu() throws {
        let adaptor = FakeStatusAdaptor(attachments: [FakeAttachmentAdaptor()])
        let descriptor = try #require(build(adaptor))

        #expect(descriptor.sections.count == 3)
        #expect(descriptor.sections[0].count == 1)

        guard case .submenu(let submenu) = descriptor.sections[0][0] else {
            Issue.record("expected the attachment submenu to lead the menu")
            return
        }
        #expect(submenu.title == localized("CONTEXT_MENU_ATTACHMENTS"))

        #expect(actionTitles(in: descriptor.sections[1]) == [
            localized("CONTEXT_MENU_REPLY"),
            localized("CONTEXT_MENU_REBLOG"),
            localized("CONTEXT_MENU_FAVOURITE"),
        ])
    }

    /// Each kind is numbered independently, so a photo pair plus a video reads
    /// "photo #1 / photo #2 / video #1" rather than "… / video #3".
    @Test func attachmentTitles_numberEachKindIndependently() throws {
        let adaptor = FakeStatusAdaptor(attachments: [
            FakeAttachmentAdaptor(id: "a", type: "image"),
            FakeAttachmentAdaptor(id: "b", type: "video"),
            FakeAttachmentAdaptor(id: "c", type: "image"),
            FakeAttachmentAdaptor(id: "d", type: "audio"),
            FakeAttachmentAdaptor(id: "e", type: "gifv"),
            FakeAttachmentAdaptor(id: "f", type: "something-else"),
        ])

        let descriptor = try #require(build(adaptor))

        #expect(try attachmentTitles(in: descriptor) == [
            String(format: localized("ATTACHMENT_MENU_IMAGE"), 1),
            String(format: localized("ATTACHMENT_MENU_VIDEO"), 1),
            String(format: localized("ATTACHMENT_MENU_IMAGE"), 2),
            String(format: localized("ATTACHMENT_MENU_AUDIO"), 1),
            String(format: localized("ATTACHMENT_MENU_GIF"), 1),
            String(format: localized("ATTACHMENT_MENU_FILE"), 1),
        ])
    }

    @Test func attachmentTitle_appendsAlternativeTextWhenPresent() throws {
        let adaptor = FakeStatusAdaptor(attachments: [
            FakeAttachmentAdaptor(id: "a", altText: "창가에 앉은 고양이"),
            FakeAttachmentAdaptor(id: "b", altText: nil),
            // An empty description is normalised to nil by the real adaptors;
            // guard the same shape here.
            FakeAttachmentAdaptor(id: "c", altText: ""),
        ])

        let numbered = { (ordinal: Int) in
            String(format: self.localized("ATTACHMENT_MENU_IMAGE"), ordinal)
        }

        let descriptor = try #require(build(adaptor))

        #expect(try attachmentTitles(in: descriptor) == [
            String(format: localized("ATTACHMENT_MENU_ITEM_WITH_ALT"), numbered(1), "창가에 앉은 고양이"),
            numbered(2),
            String(format: localized("ATTACHMENT_MENU_ITEM_WITH_ALT"), numbered(3), ""),
        ])
    }

    /// Menu rows are single-line, so a multi-line description is flattened rather
    /// than being cut off at its first newline.
    @Test func attachmentTitle_flattensMultilineAlternativeText() throws {
        let adaptor = FakeStatusAdaptor(attachments: [
            FakeAttachmentAdaptor(altText: "첫 줄\n둘째 줄\n셋째 줄")
        ])

        let descriptor = try #require(build(adaptor))
        let title = try #require(try attachmentTitles(in: descriptor).first)

        #expect(title.hasSuffix("첫 줄 둘째 줄 셋째 줄"))
    }

    /// An image opens the in-app viewer, positioned on the chosen attachment —
    /// the same destination a thumbnail tap reaches.
    @Test func imageAttachment_requestsTheGalleryPositionedOnIt() throws {
        let adaptor = FakeStatusAdaptor(id: "status-42", attachments: [
            FakeAttachmentAdaptor(id: "a", type: "image"),
            FakeAttachmentAdaptor(id: "b", type: "video"),
            FakeAttachmentAdaptor(id: "c", type: "image"),
        ])

        var presented: [PostRowPresentation] = []
        let descriptor = try #require(build(adaptor, present: { presented.append($0) }))

        // The third entry: the second image.
        try invokeAttachment(2, in: descriptor)

        guard case .gallery(let context) = try #require(presented.first) else {
            Issue.record("expected a gallery request")
            return
        }
        #expect(context.id == "status-42")
        // The video is not viewable, so the gallery carries the images only.
        #expect(context.items.map(\.id) == ["a", "c"])
        #expect(context.initialIndex == 1)
    }

    /// The viewer has no player, so anything that is not an image is handed to
    /// the browser instead.
    @Test func nonImageAttachment_opensItsURLExternally() throws {
        let adaptor = FakeStatusAdaptor(attachments: [
            FakeAttachmentAdaptor(id: "a", type: "video", url: "https://example.com/clip.mp4")
        ])

        var openedURLs: [URL] = []
        var presented: [PostRowPresentation] = []
        let descriptor = try #require(build(adaptor,
                                            openURL: { openedURLs.append($0) },
                                            present: { presented.append($0) }))

        try invokeAttachment(0, in: descriptor)

        #expect(openedURLs.map(\.absoluteString) == ["https://example.com/clip.mp4"])
        #expect(presented.isEmpty)
    }

    /// Boosts show the boosted post's media, not the (always empty) wrapper's.
    @Test func boostedStatus_listsTheBoostedPostsAttachments() throws {
        let inner = FakeStatusAdaptor(id: "inner", attachments: [
            FakeAttachmentAdaptor(id: "a", altText: "boosted photo")
        ])
        let outer = FakeStatusAdaptor(id: "outer", reblog: inner)

        let descriptor = try #require(build(outer))
        let titles = try attachmentTitles(in: descriptor)

        #expect(titles.count == 1)
        #expect(titles[0].hasSuffix("boosted photo"))
    }

    // MARK: - moderation

    /// Reporting or blocking yourself is meaningless — and both backends reject a
    /// self-block outright — so the moderation section is only offered for
    /// someone else's post, where `delete` is the one that disappears.
    @Test func ownStatus_hasNoModerationSection() throws {
        let adaptor = FakeStatusAdaptor(account: FakeAccountAdaptor(id: "me"))
        let descriptor = try #require(build(adaptor, ownAccountId: "me"))

        let titles = descriptor.sections.flatMap { actionTitles(in: $0) }
        #expect(!titles.contains(localized("CONTEXT_MENU_REPORT")))
        #expect(!titles.contains(localized("CONTEXT_MENU_BLOCK")))
    }

    @Test func moderationActions_areDestructive() throws {
        let descriptor = try #require(build(FakeStatusAdaptor()))
        let moderation = try #require(descriptor.sections.last)

        for entry in moderation {
            guard case .action(let action) = entry else {
                Issue.record("expected only actions in the moderation section")
                continue
            }
            #expect(action.destructive)
        }
    }

    /// Delete no longer fires straight from the menu: it asks the row to confirm
    /// first (nothing is deleted until the user says so).
    @Test func delete_requestsConfirmationRatherThanDeletingImmediately() throws {
        let performer = FakePerformer()
        let model = StatusModel(adaptor: FakeStatusAdaptor(account: FakeAccountAdaptor(id: "me")),
                                performer: performer)

        var presented: [PostRowPresentation] = []
        let descriptor = try #require(build(FakeStatusAdaptor(account: FakeAccountAdaptor(id: "me")),
                                            ownAccountId: "me",
                                            model: model,
                                            present: { presented.append($0) }))

        try invoke(localized("CONTEXT_MENU_DELETE"), in: descriptor)

        #expect(performer.deleteCount == 0)
        guard case .confirm(let confirmation) = try #require(presented.first) else {
            Issue.record("expected a confirmation request")
            return
        }
        #expect(confirmation.kind == .delete)
    }

    @Test func block_requestsConfirmationNamingTheAuthor() throws {
        let account = FakeAccountAdaptor(id: "them", acct: "villain@example.com")

        var presented: [PostRowPresentation] = []
        let descriptor = try #require(build(FakeStatusAdaptor(account: account),
                                            ownAccountId: "me",
                                            present: { presented.append($0) }))

        try invoke(localized("CONTEXT_MENU_BLOCK"), in: descriptor)

        guard case .confirm(let confirmation) = try #require(presented.first) else {
            Issue.record("expected a confirmation request")
            return
        }
        #expect(confirmation.kind == .block)
        #expect(confirmation.acct == "villain@example.com")
    }

    /// The report sheet is raised for the *boosted* post, not the boost wrapper:
    /// the offending content (and its author) is the original.
    @Test func report_targetsTheCanonicalStatusAndAuthor() throws {
        let inner = FakeStatusAdaptor(
            id: "inner",
            url: "https://example.com/@author/inner",
            account: FakeAccountAdaptor(id: "author", acct: "author@example.com")
        )
        let outer = FakeStatusAdaptor(
            id: "outer",
            account: FakeAccountAdaptor(id: "booster", acct: "booster@example.com"),
            reblog: inner
        )

        var presented: [PostRowPresentation] = []
        let descriptor = try #require(build(outer, ownAccountId: "me", present: { presented.append($0) }))

        try invoke(localized("CONTEXT_MENU_REPORT"), in: descriptor)

        guard case .report(let target) = try #require(presented.first) else {
            Issue.record("expected a report request")
            return
        }
        #expect(target.accountId == "author")
        #expect(target.statusId == "inner")
        #expect(target.statusUrl == "https://example.com/@author/inner")
    }

    /// Forwarding needs both a backend that can do it (Mastodon) and a remote
    /// account to forward to — a local account has no other instance to notify.
    @Test func report_offersForwardingOnlyForRemoteAccountsOnACapableServer() throws {
        let remote = FakeStatusAdaptor(account: FakeAccountAdaptor(id: "them", acct: "villain@other.example"))
        let local = FakeStatusAdaptor(account: FakeAccountAdaptor(id: "them", acct: "villain"))

        #expect(try reportTarget(for: remote, supportsReportForwarding: true).canForward)
        #expect(!(try reportTarget(for: remote, supportsReportForwarding: false).canForward))
        #expect(!(try reportTarget(for: local, supportsReportForwarding: true).canForward))
    }

    @Test func report_submitRoutesThroughTheModelsPerformer() async throws {
        let performer = FakePerformer()
        let model = StatusModel(adaptor: FakeStatusAdaptor(account: FakeAccountAdaptor(id: "them")),
                                performer: performer)

        var presented: [PostRowPresentation] = []
        let descriptor = try #require(build(FakeStatusAdaptor(account: FakeAccountAdaptor(id: "them")),
                                            ownAccountId: "me",
                                            model: model,
                                            present: { presented.append($0) }))

        try invoke(localized("CONTEXT_MENU_REPORT"), in: descriptor)

        guard case .report(let target) = try #require(presented.first) else {
            Issue.record("expected a report request")
            return
        }

        // Nothing is filed until the sheet submits.
        #expect(performer.reportCount == 0)

        let accepted = await target.submit(
            ReportRequest(accountId: "them", statusId: "s1", comment: "spammer", category: .spam)
        )

        #expect(accepted)
        #expect(performer.reportCount == 1)
        #expect(performer.lastReport?.accountId == "them")
        #expect(performer.lastReport?.comment == "spammer")
        #expect(performer.lastReport?.category == .spam)
    }

    @Test func report_submitReportsFailureWhenTheServerRejectsIt() async throws {
        let performer = FakePerformer()
        performer.errorToThrow = FediverseAPIError.notImplemented
        let model = StatusModel(adaptor: FakeStatusAdaptor(), performer: performer)

        var presented: [PostRowPresentation] = []
        let descriptor = try #require(build(FakeStatusAdaptor(),
                                            model: model,
                                            present: { presented.append($0) }))

        try invoke(localized("CONTEXT_MENU_REPORT"), in: descriptor)

        guard case .report(let target) = try #require(presented.first) else {
            Issue.record("expected a report request")
            return
        }

        let accepted = await target.submit(ReportRequest(accountId: "them"))
        #expect(!accepted)
    }

    @Test func boostedStatus_describesBoostedAuthor() throws {
        let inner = FakeStatusAdaptor(
            id: "inner",
            account: FakeAccountAdaptor(acct: "author@example.com", displayName: "Author")
        )
        let outer = FakeStatusAdaptor(id: "outer", reblog: inner)

        let descriptor = try #require(build(outer))

        #expect(descriptor.header.text == "Author (@author@example.com)")
    }

    @Test func unresolvedDepth_returnsNil() {
        #expect(build(FakeStatusAdaptor(), depth: 1) == nil)
    }

    // MARK: - asUIMenu

    @Test func asUIMenu_rendersInlineSectionsAndAttributes() throws {
        let adaptor = FakeStatusAdaptor(
            url: "https://example.com/@tester/1",
            account: FakeAccountAdaptor(id: "me")
        )
        let menu = try #require(build(adaptor, ownAccountId: "me")).asUIMenu()

        // header + [actions, url label, url actions, delete]
        #expect(menu.title == "Tester (@tester@example.com)")
        #expect(menu.children.count == 4)

        let sections = try #require(menu.children as? [UIMenu])
        #expect(sections.allSatisfy { $0.options.contains(.displayInline) })

        let urlLabel = try #require(sections[1].children.first as? UIAction)
        #expect(urlLabel.attributes.contains(.disabled))

        let delete = try #require(sections[3].children.first as? UIAction)
        #expect(delete.attributes.contains(.destructive))
    }

    /// The submenu must render as a real nested `UIMenu` — *not* `.displayInline`,
    /// which would spill the attachments into the parent menu instead of putting
    /// them behind a row.
    @Test func asUIMenu_rendersTheAttachmentSubmenuAsANestedMenu() throws {
        let adaptor = FakeStatusAdaptor(attachments: [
            FakeAttachmentAdaptor(id: "a", type: "image", altText: "고양이"),
            FakeAttachmentAdaptor(id: "b", type: "video"),
        ])
        let menu = try #require(build(adaptor)).asUIMenu()

        let sections = try #require(menu.children as? [UIMenu])
        let submenu = try #require(sections[0].children.first as? UIMenu)

        #expect(submenu.title == localized("CONTEXT_MENU_ATTACHMENTS"))
        #expect(!submenu.options.contains(.displayInline))
        #expect(submenu.children.compactMap { ($0 as? UIAction)?.title } == [
            String(format: localized("ATTACHMENT_MENU_ITEM_WITH_ALT"),
                   String(format: localized("ATTACHMENT_MENU_IMAGE"), 1),
                   "고양이"),
            String(format: localized("ATTACHMENT_MENU_VIDEO"), 1),
        ])
    }

    @Test func asUIMenu_stripsEmojiShortcodesFromTitle() throws {
        let account = FakeAccountAdaptor(
            acct: "len@example.com",
            displayName: "Len:len:",
            emojis: [FakeEmojiAdaptor(shortcode: "len")]
        )
        let menu = try #require(build(FakeStatusAdaptor(account: account))).asUIMenu()

        #expect(menu.title == "Len (@len@example.com)")
    }
}
