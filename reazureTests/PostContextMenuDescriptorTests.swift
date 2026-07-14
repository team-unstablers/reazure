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
        present: @escaping (PostRowPresentation) -> Void = { _ in }
    ) -> PostContextMenuDescriptor? {
        PostContextMenuDescriptor.build(
            for: model ?? StatusModel(adaptor: adaptor),
            depth: depth,
            ownAccountId: ownAccountId,
            openURL: { _ in },
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
