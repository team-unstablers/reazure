//
//  OptimisticActionRaceTests.swift
//  reazureTests
//
//  Regression coverage for the optimistic-action race (option C). Previously the
//  favourite/reblog flow captured a status snapshot *before* the API `await` and
//  built the mask from that stale snapshot, so two actions fired in quick
//  succession clobbered each other (only one indicator stuck) and rapid repeats
//  of the same action misjudged the toggle direction. The rewrite applies the
//  optimistic overlay in a serialized main-queue critical section (read → decide
//  → mask) before the API call, and rolls back on failure.
//

import Testing

@testable import reazure

@MainActor
struct OptimisticActionRaceTests {

    // MARK: - concurrent, distinct actions

    @Test func concurrentFavouriteAndReblog_bothIndicatorsStick() async throws {
        let performer = FakePerformer()
        let base = FakeStatusAdaptor(id: "s", favourited: false, reblogged: false)
        let model = StatusModel(adaptor: base, performer: performer)

        // Fire favourite and reblog concurrently, mimicking `f` and `t` pressed
        // almost simultaneously (each is dispatched on its own Task in the app).
        async let fav: Void = model.toggleFavourite(of: 0)
        async let boost: Void = model.toggleReblog(of: 0)
        _ = try await (fav, boost)
        await flushMainQueue()

        // Both overlays must survive — the whole point of the fix.
        #expect(model.status.favourited == true)
        #expect(model.status.reblogged == true)

        #expect(performer.favouriteCount == 1)
        #expect(performer.reblogCount == 1)

        // The underlying adaptor is never mutated.
        #expect(base.favourited == false)
        #expect(base.reblogged == false)
    }

    // MARK: - rapid repeat of the same action (decision race)

    @Test func rapidDoubleFavourite_endsUnfavourited() async throws {
        let performer = FakePerformer()
        let base = FakeStatusAdaptor(id: "s", favourited: false)
        let model = StatusModel(adaptor: base, performer: performer)

        // Two favourite toggles racing. Because the direction is decided against
        // the *current* overlay (not a stale snapshot), the second toggle must
        // observe the first's `favourited = true` and flip back to false.
        async let first: Void = model.toggleFavourite(of: 0)
        async let second: Void = model.toggleFavourite(of: 0)
        _ = try await (first, second)
        await flushMainQueue()

        #expect(model.status.favourited == false)
        #expect(performer.favouriteCount == 1)
        #expect(performer.unfavouriteCount == 1)
    }

    // MARK: - rollback on API failure

    @Test func toggleFavourite_rollsBackWhenApiFails() async {
        let performer = FakePerformer()
        performer.errorToThrow = FakePerformerError.noResolveResult
        let base = FakeStatusAdaptor(id: "s", favourited: false)
        let model = StatusModel(adaptor: base, performer: performer)

        // The overlay flips to `true` optimistically, then the failing API rolls
        // it back to `false`. `toggleFavourite` rethrows after rolling back.
        try? await model.toggleFavourite(of: 0)
        await flushMainQueue()

        #expect(performer.favouriteCount == 1)
        #expect(model.status.favourited == false)
        #expect(base.favourited == false)
    }

    @Test func toggleReblog_rollsBackWhenApiFails() async {
        let performer = FakePerformer()
        performer.errorToThrow = FakePerformerError.noResolveResult
        let base = FakeStatusAdaptor(id: "s", reblogged: false)
        let model = StatusModel(adaptor: base, performer: performer)

        try? await model.toggleReblog(of: 0)
        await flushMainQueue()

        #expect(performer.reblogCount == 1)
        #expect(model.status.reblogged == false)
        #expect(base.reblogged == false)
    }
}
