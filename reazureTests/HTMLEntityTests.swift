//
//  HTMLEntityTests.swift
//  reazureTests
//
//  Regression coverage for decoding HTML entities from federated content.
//

import Testing

@testable import reazure

struct HTMLEntityTests {

    @Test func decodesNamedAndNumericEntities() {
        let encoded = "&lt;&quot;re;azure&quot;&gt; &#38; &#x1F34A; &#X1f34b; &apos;"

        #expect(encoded.decodeHTMLEntity() == "<\"re;azure\"> & 🍊 🍋 '")
    }

    @Test func preservesUnknownAndIncompleteEntities() {
        #expect("a &unknown; b".decodeHTMLEntity() == "a &unknown; b")
        #expect("a &amp b".decodeHTMLEntity() == "a &amp b")
        #expect("trailing &".decodeHTMLEntity() == "trailing &")
    }

    @Test func preservesInvalidUnicodeScalarsWithoutCrashing() {
        #expect("surrogate: &#xD800;".decodeHTMLEntity() == "surrogate: &#xD800;")
        #expect("too large: &#1114112;".decodeHTMLEntity() == "too large: &#1114112;")
        #expect("not a number: &#xnope;".decodeHTMLEntity() == "not a number: &#xnope;")
    }

    @Test func malformedCandidateDoesNotHideFollowingEntity() {
        #expect("&broken &amp;".decodeHTMLEntity() == "&broken &")
    }
}
