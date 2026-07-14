//
//  BlockMaskTests.swift
//  reazureTests
//
//  Coverage for blocking. A block is the one write action whose effect is not
//  confined to the row that raised it: the server stops delivering the account's
//  posts, but everything already on screen has to be hidden in place (there is no
//  offline cache to reload the timeline from). These pin both halves — the
//  performer only sweeps once the server has accepted the block, and the sweep
//  masks every row the account authored *or* boosted.
//

import Combine
import Testing

@testable import reazure

@MainActor
struct BlockMaskTests {

    private func performer(client: FakeFediverseClient,
                           didBlockAccount: @escaping (String) -> Void = { _ in }) -> FediverseActionPerformer {
        FediverseActionPerformer(client: client,
                                 replyTo: .init(nil),
                                 didBlockAccount: didBlockAccount)
    }

    // MARK: - performer

    @Test func block_callsTheClientThenAnnouncesTheBlockedAccount() async throws {
        let client = FakeFediverseClient()
        var announced: [String] = []
        let performer = performer(client: client) { announced.append($0) }

        let status = FakeStatusAdaptor(account: FakeAccountAdaptor(id: "villain"))
        let model = StatusModel(adaptor: status)

        try await performer.statusModel(wantsBlockAuthorOf: status, model: model)

        #expect(client.blockedAccountIds == ["villain"])
        #expect(announced == ["villain"])
    }

    /// A block that the server rejected must not grey anything out — the posts are
    /// still coming.
    @Test func block_whenTheServerRejectsIt_announcesNothing() async {
        let client = FakeFediverseClient()
        client.errorToThrow = FediverseAPIError.notImplemented

        var announced: [String] = []
        let performer = performer(client: client) { announced.append($0) }

        let status = FakeStatusAdaptor(account: FakeAccountAdaptor(id: "villain"))
        let model = StatusModel(adaptor: status)

        await #expect(throws: (any Error).self) {
            try await performer.statusModel(wantsBlockAuthorOf: status, model: model)
        }

        #expect(announced.isEmpty)
    }

    /// `blockAuthor(of:)` targets the boosted author, not the booster — the same
    /// canonical status every other context-menu action acts on.
    @Test func blockAuthor_onABoost_blocksTheBoostedAuthor() async throws {
        let client = FakeFediverseClient()
        // `StatusModel.performer` is weak, so the performer has to be held here for
        // the duration of the call.
        let performer = performer(client: client)
        let model = StatusModel(
            adaptor: FakeStatusAdaptor(
                account: FakeAccountAdaptor(id: "booster"),
                reblog: FakeStatusAdaptor(account: FakeAccountAdaptor(id: "author"))
            ),
            performer: performer
        )

        try await model.blockAuthor(of: 0)

        #expect(client.blockedAccountIds == ["author"])
    }

    // MARK: - masking

    @Test func applyBlock_masksTheAuthorsOwnPost() {
        let adaptor = FakeStatusAdaptor(account: FakeAccountAdaptor(id: "villain"))
        let model = StatusModel(adaptor: adaptor)

        model.applyBlock(accountId: "villain")

        #expect(model.status.blocked)
        // Masking overlays; it never mutates the underlying adaptor.
        #expect(!adaptor.blocked)
    }

    @Test func applyBlock_leavesOtherAuthorsAlone() {
        let model = StatusModel(adaptor: FakeStatusAdaptor(account: FakeAccountAdaptor(id: "someone-else")))

        model.applyBlock(accountId: "villain")

        #expect(!model.status.blocked)
    }

    /// A boost is shown on the booster's behalf, so blocking *either* side has to
    /// hide the row.
    @Test func applyBlock_masksBoostsFromEitherSide() {
        func boost() -> StatusModel {
            StatusModel(adaptor: FakeStatusAdaptor(
                account: FakeAccountAdaptor(id: "booster"),
                reblog: FakeStatusAdaptor(account: FakeAccountAdaptor(id: "author"))
            ))
        }

        let blockedAuthor = boost()
        blockedAuthor.applyBlock(accountId: "author")
        #expect(blockedAuthor.status.blocked)

        let blockedBooster = boost()
        blockedBooster.applyBlock(accountId: "booster")
        #expect(blockedBooster.status.blocked)
    }

    /// The mask has to show through `reblog`, since that is the adaptor the boost
    /// row actually renders.
    @Test func applyBlock_onABoost_isVisibleThroughTheReblog() {
        let model = StatusModel(adaptor: FakeStatusAdaptor(
            account: FakeAccountAdaptor(id: "booster"),
            reblog: FakeStatusAdaptor(account: FakeAccountAdaptor(id: "author"))
        ))

        model.applyBlock(accountId: "author")

        #expect(model.status.reblog?.blocked == true)
    }

    @Test func applyBlock_masksResolvedParents() {
        let model = StatusModel(adaptor: FakeStatusAdaptor(account: FakeAccountAdaptor(id: "me")))
        model.parents = [
            FakeStatusAdaptor(id: "p1", account: FakeAccountAdaptor(id: "villain")),
            FakeStatusAdaptor(id: "p2", account: FakeAccountAdaptor(id: "innocent")),
        ]

        model.applyBlock(accountId: "villain")

        #expect(!model.status.blocked)
        #expect(model.parents[0].blocked)
        #expect(!model.parents[1].blocked)
    }

    /// Blocking must not clobber the flags an earlier optimistic action masked in.
    @Test func applyBlock_preservesExistingMaskedFlags() {
        let model = StatusModel(adaptor: FakeStatusAdaptor(account: FakeAccountAdaptor(id: "villain")))
        model.status = model.status.mask(favourited: true)

        model.applyBlock(accountId: "villain")

        #expect(model.status.blocked)
        #expect(model.status.favourited)
    }

    // MARK: - timeline sweep

    @Test func timelineApplyBlock_masksEveryRowByThatAccount() {
        let timeline = TimelineModel()
        timeline.statuses = [
            StatusModel(adaptor: FakeStatusAdaptor(id: "s1", account: FakeAccountAdaptor(id: "villain"))),
            StatusModel(adaptor: FakeStatusAdaptor(id: "s2", account: FakeAccountAdaptor(id: "innocent"))),
            StatusModel(adaptor: FakeStatusAdaptor(id: "s3", account: FakeAccountAdaptor(id: "villain"))),
        ]

        timeline.applyBlock(accountId: "villain")

        let blocked = timeline.statuses.map { $0.status.blocked }
        #expect(blocked == [true, false, true])
    }
}
