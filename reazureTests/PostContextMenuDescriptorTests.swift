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
        ownAccountId: String? = nil
    ) -> PostContextMenuDescriptor? {
        PostContextMenuDescriptor.build(
            for: StatusModel(adaptor: adaptor),
            depth: depth,
            ownAccountId: ownAccountId,
            openURL: { _ in }
        )
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

    @Test func basicStatus_hasHeaderAndSingleActionSection() throws {
        let descriptor = try #require(build(FakeStatusAdaptor()))

        #expect(descriptor.header.text == "Tester (@tester@example.com)")
        #expect(descriptor.sections.count == 1)
        #expect(actionTitles(in: descriptor.sections[0]) == [
            localized("CONTEXT_MENU_REPLY"),
            localized("CONTEXT_MENU_REBLOG"),
            localized("CONTEXT_MENU_FAVOURITE"),
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

        #expect(descriptor.sections.count == 3)

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
