//
//  MaskingInvariantTests.swift
//  reazureTests
//
//  Regression coverage for the optimistic "call API, then swap in a masked copy"
//  flow (roadmap step 1.1). These pin the invariant that favourite/reblog/delete
//  route through the performer seam and overlay a `MaskedStatusAdaptor` without
//  mutating the underlying adaptor.
//

import Testing

@testable import reazure

@MainActor
struct MaskingInvariantTests {

    // MARK: - toggleFavourite

    @Test func toggleFavourite_callsPerformerAndMasksFavourited() async throws {
        let performer = FakePerformer()
        let base = FakeStatusAdaptor(id: "s", favourited: false)
        let model = StatusModel(adaptor: base, performer: performer)

        try await model.toggleFavourite(of: 0)
        await flushMainQueue()

        #expect(performer.favouriteCount == 1)
        #expect(performer.unfavouriteCount == 0)
        #expect(performer.lastFavouriteId == "s")

        #expect(model.status is MaskedStatusAdaptor)
        #expect(model.status.favourited == true)
        // The underlying adaptor must not be mutated by the optimistic overlay.
        #expect(base.favourited == false)
    }

    @Test func toggleFavourite_whenAlreadyFavourited_callsUnfavourite() async throws {
        let performer = FakePerformer()
        let base = FakeStatusAdaptor(id: "s", favourited: true)
        let model = StatusModel(adaptor: base, performer: performer)

        try await model.toggleFavourite(of: 0)
        await flushMainQueue()

        #expect(performer.unfavouriteCount == 1)
        #expect(performer.favouriteCount == 0)
        #expect(model.status.favourited == false)
        #expect(base.favourited == true)
    }

    // MARK: - toggleReblog

    @Test func toggleReblog_callsPerformerAndMasksReblogged() async throws {
        let performer = FakePerformer()
        let base = FakeStatusAdaptor(id: "s", reblogged: false)
        let model = StatusModel(adaptor: base, performer: performer)

        try await model.toggleReblog(of: 0)
        await flushMainQueue()

        #expect(performer.reblogCount == 1)
        #expect(performer.unreblogCount == 0)
        #expect(performer.lastReblogId == "s")

        #expect(model.status is MaskedStatusAdaptor)
        #expect(model.status.reblogged == true)
        #expect(base.reblogged == false)
    }

    @Test func toggleReblog_whenAlreadyReblogged_callsUnreblog() async throws {
        let performer = FakePerformer()
        let base = FakeStatusAdaptor(id: "s", reblogged: true)
        let model = StatusModel(adaptor: base, performer: performer)

        try await model.toggleReblog(of: 0)
        await flushMainQueue()

        #expect(performer.unreblogCount == 1)
        #expect(performer.reblogCount == 0)
        #expect(model.status.reblogged == false)
        #expect(base.reblogged == true)
    }

    // MARK: - delete

    @Test func delete_callsPerformerAndMasksDeleted() async throws {
        let performer = FakePerformer()
        let base = FakeStatusAdaptor(id: "s")
        let model = StatusModel(adaptor: base, performer: performer)

        try await model.delete(depth: 0)
        await flushMainQueue()

        #expect(performer.deleteCount == 1)
        #expect(performer.lastDeleteId == "s")

        #expect(model.status is MaskedStatusAdaptor)
        #expect(model.status.deleted == true)
        #expect(base.deleted == false)
    }

    @Test func delete_swallowsPerformerError_andStillMasks() async throws {
        // `StatusModelBase.delete` intentionally uses `try?`, so a failing delete
        // request must still leave the row optimistically marked as deleted.
        let performer = FakePerformer()
        performer.errorToThrow = FakePerformerError.noResolveResult
        let base = FakeStatusAdaptor(id: "s")
        let model = StatusModel(adaptor: base, performer: performer)

        try await model.delete(depth: 0)
        await flushMainQueue()

        #expect(performer.deleteCount == 1)
        #expect(model.status.deleted == true)
    }

    // MARK: - mask() merge semantics

    @Test func mask_doesNotNest_andMergesFlagsOntoUnderlying() {
        let base = FakeStatusAdaptor(id: "m", favourited: false, reblogged: false)

        let first = base.mask(favourited: true)
        #expect(first.favourited == true)
        #expect(first.reblogged == false)
        #expect(first.status === base)

        // Masking an already-masked adaptor must collapse onto the same
        // underlying status and merge, not stack a second overlay.
        let second = first.mask(reblogged: true)
        #expect(second.favourited == true)  // preserved from the first mask
        #expect(second.reblogged == true)   // newly applied
        #expect(second.status === base)
    }

    // MARK: - canonical

    @Test func canonical_returnsReblogWhenPresent() {
        let inner = FakeStatusAdaptor(id: "inner")
        let outer = FakeStatusAdaptor(id: "outer", reblog: inner)

        #expect(outer.canonical === inner)
    }

    @Test func canonical_returnsSelfWhenNoReblog() {
        let plain = FakeStatusAdaptor(id: "plain")

        #expect(plain.canonical === plain)
    }
}
