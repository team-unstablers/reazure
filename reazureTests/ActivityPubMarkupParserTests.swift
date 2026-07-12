//
//  ActivityPubMarkupParserTests.swift
//  reazureTests
//
//  Regression coverage for tolerant parsing of federated status markup.
//

import Testing

@testable import reazure

private struct MarkupEmojiAdaptor: EmojiAdaptor {
    let shortcode: String
    let url: String
}

struct ActivityPubMarkupParserTests {

    @Test func acceptsOnlySafeAbsoluteWebLinks() {
        #expect(validatedActivityPubLinkURL("https://example.com/@len") != nil)
        #expect(validatedActivityPubLinkURL("http://localhost:8080/status/1") != nil)

        #expect(validatedActivityPubLinkURL("javascript:alert(1)") == nil)
        #expect(validatedActivityPubLinkURL("reazure://status/1") == nil)
        #expect(validatedActivityPubLinkURL("file:///etc/passwd") == nil)
        #expect(validatedActivityPubLinkURL("/relative/status/1") == nil)
        #expect(validatedActivityPubLinkURL("https://user@example.com/status/1") == nil)
        #expect(validatedActivityPubLinkURL(" https://example.com/status/1") == nil)
    }

    @Test func parsesSupportedMarkupAndAttributes() throws {
        let root = parseHTML(
            "<P>Hello <STRONG>world</STRONG><BR/>" +
            "<a href = 'https://example.com/?a=1&amp;b=2' title=example>link</a></P>"
        )
        let paragraph = try #require(root.children.first)
        let link = try #require(paragraph.children.last)

        #expect(paragraph.name == "p")
        #expect(paragraph.innerText == "Hello world\nlink")
        #expect(link.name == "a")
        #expect(link.attributes["href"] == "https://example.com/?a=1&b=2")
        #expect(link.attributes["title"] == "example")
    }

    @Test func quotedGreaterThanSignDoesNotEndTag() throws {
        let root = parseHTML("<a href=\"https://example.com/?q=1>0\">result</a>")
        let link = try #require(root.children.first)

        #expect(link.attributes["href"] == "https://example.com/?q=1>0")
        #expect(link.innerText == "result")
    }

    @Test func mismatchedAndUnexpectedClosingTagsDoNotCrash() {
        let root = parseHTML("before</unknown><p><strong>inside</p>after</strong>")

        #expect(root.innerText == "beforeinside\n\nafter")
    }

    @Test func unclosedElementsKeepTheirContent() {
        let root = parseHTML("<p>kept <strong>content")

        #expect(root.innerText == "kept content")
    }

    @Test func incompleteTagIsPreservedAsText() {
        let root = parseHTML("one < unfinished")

        #expect(root.innerText == "one < unfinished")
    }

    @Test func commentsCanContainGreaterThanSigns() {
        let root = parseHTML("before<!-- 2 > 1 -->after")

        #expect(root.innerText == "beforeafter")
    }

    @Test func excessiveNestingIsBoundedWithoutLosingText() {
        let openingTags = String(repeating: "<span>", count: 256)
        let closingTags = String(repeating: "</span>", count: 256)
        let root = parseHTML(openingTags + "still visible" + closingTags)

        #expect(root.innerText == "still visible")
    }

    @Test func separatesNestedBlockElementsWithoutTrailingBreaks() {
        let root = parseHTML("<div><p>one</p><p>two</p></div><div>three</div>")

        #expect(root.innerText == "one\n\ntwo\n\nthree")
    }

    @Test func blockSeparationDoesNotDuplicateExistingBreaks() {
        let root = parseHTML("<p>one<br><br></p><p>two</p>")

        #expect(root.innerText == "one\n\ntwo")
    }

    @Test func collectsOnlyReferencedEmojisAndDeduplicatesShortcodes() {
        let root = parseHTML(":lemon: :lemon: :unknown: <a href='https://example.com'>:orange:</a>")
        let definitions = activityPubEmojiDefinitions([
            MarkupEmojiAdaptor(shortcode: "lemon", url: "https://example.com/lemon.png"),
            MarkupEmojiAdaptor(shortcode: "orange", url: "https://example.com/orange.png"),
            MarkupEmojiAdaptor(shortcode: "unused", url: "https://example.com/unused.png"),
        ])

        #expect(referencedActivityPubEmojos(in: root, definitions: definitions) == [
            ActivityPubEmojiDefinition(shortcode: "lemon", url: "https://example.com/lemon.png"),
            ActivityPubEmojiDefinition(shortcode: "orange", url: "https://example.com/orange.png"),
        ])
    }

    @Test func markupViewEqualityIncludesEmojiDefinitions() {
        let first = ActivityPubMarkupTextSimple(
            content: ":lemon:",
            emojos: [MarkupEmojiAdaptor(shortcode: "lemon", url: "https://example.com/v1.png")]
        )
        let same = ActivityPubMarkupTextSimple(
            content: ":lemon:",
            emojos: [MarkupEmojiAdaptor(shortcode: "lemon", url: "https://example.com/v1.png")]
        )
        let changed = ActivityPubMarkupTextSimple(
            content: ":lemon:",
            emojos: [MarkupEmojiAdaptor(shortcode: "lemon", url: "https://example.com/v2.png")]
        )

        #expect(first == same)
        #expect(first != changed)
    }
}
