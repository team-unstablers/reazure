//
//  BoostMaskTests.swift
//  reazureTests
//
//  Regression coverage for masking a boosted (reblogged) status (roadmap step
//  1.2). Pins two things: the inner boosted row reflects the outer overlay's
//  flags, and the overlay pair does not form a retain cycle once `_parent` is
//  `unowned`.
//

import Testing

@testable import reazure

@MainActor
struct BoostMaskTests {

    @Test func boostMask_innerRowReflectsOuterFlags() {
        let inner = FakeStatusAdaptor(id: "inner", favourited: false, reblogged: false)
        let outer = FakeStatusAdaptor(id: "outer", favourited: false, reblogged: false, reblog: inner)

        let masked = outer.mask(reblogged: true)

        #expect(masked.reblogged == true)
        // The boosted row is re-wrapped and mirrors the outer overlay's flags.
        #expect(masked.reblog != nil)
        #expect(masked.reblog?.id == "inner")
        #expect(masked.reblog?.reblogged == true)

        // The underlying boosted adaptor is never mutated.
        #expect(inner.reblogged == false)
    }

    @Test func boostMask_doesNotRetainCycle() {
        weak var weakMasked: MaskedStatusAdaptor?

        do {
            let inner = FakeStatusAdaptor(id: "inner")
            let outer = FakeStatusAdaptor(id: "outer", reblog: inner)
            let masked = outer.mask(reblogged: true)

            weakMasked = masked
            // Sanity: the boost overlay pair exists while `masked` is alive.
            #expect(weakMasked != nil)
            #expect(masked.reblog != nil)
        }

        // With `ReblogMaskedStatusAdaptor._parent` held `unowned`, the overlay
        // pair deallocates once the last strong reference leaves scope. A strong
        // `_parent` would keep this alive and fail the expectation.
        #expect(weakMasked == nil)
    }
}
