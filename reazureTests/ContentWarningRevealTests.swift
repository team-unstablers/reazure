//
//  ContentWarningRevealTests.swift
//  reazureTests
//
//  `h`/`l`은 열람 경고(CW) 펼치기와 답글 트리 확장을 겸한다. 경고가 걸린
//  포스트에서는 먼저 본문을 펼치고, 그 다음 눌렀을 때 비로소 트리가 확장된다.
//  이 계층 관계와 depth별 독립성을 고정한다.
//

import Testing

@testable import reazure

@MainActor
struct ContentWarningRevealTests {

    private typealias Focus = TimelineModel.FocusState

    private func makeTimeline(_ models: [StatusModel]) -> TimelineModel {
        let timeline = TimelineModel()
        for model in models.reversed() {
            timeline.prepend(model)
        }
        return timeline
    }

    private func status(_ id: String, spoilerText: String? = nil, replyToId: String? = nil) -> StatusModel {
        StatusModel(adaptor: FakeStatusAdaptor(id: id, replyToId: replyToId, spoilerText: spoilerText))
    }

    // MARK: - expandFocused (.l)

    @Test func expandFocused_onWarnedPost_revealsBodyBeforeExpandingTree() {
        let model = status("a", spoilerText: "스포일러 주의", replyToId: "parent")
        let timeline = makeTimeline([model])
        timeline.focusState = Focus(id: "a", depth: 0)

        timeline.expandFocused()

        #expect(model.isRevealed(at: 0))
        // 첫 입력은 본문 펼치기에서 멈춰야 한다.
        #expect(model.expandedDepth == 0)

        timeline.expandFocused()

        #expect(model.isRevealed(at: 0))
        #expect(model.expandedDepth == 1)
    }

    @Test func expandFocused_withoutWarning_expandsTreeImmediately() {
        let model = status("a", replyToId: "parent")
        let timeline = makeTimeline([model])
        timeline.focusState = Focus(id: "a", depth: 0)

        timeline.expandFocused()

        #expect(model.expandedDepth == 1)
        #expect(model.revealedDepths.isEmpty)
    }

    // MARK: - collapseFocused (.h)

    @Test func collapseFocused_foldsBodyBeforeCollapsingTree() {
        let model = status("a", spoilerText: "스포일러 주의", replyToId: "parent")
        model.expandedDepth = 1
        model.revealedDepths = [0]

        let timeline = makeTimeline([model])
        timeline.focusState = Focus(id: "a", depth: 0)

        timeline.collapseFocused()

        #expect(!model.isRevealed(at: 0))
        // 본문을 접는 동안 트리는 그대로 남는다.
        #expect(model.expandedDepth == 1)

        timeline.collapseFocused()

        #expect(model.expandedDepth == 0)
    }

    @Test func collapseFocused_withoutRevealedWarning_collapsesTree() {
        let model = status("a", replyToId: "parent")
        model.expandedDepth = 1

        let timeline = makeTimeline([model])
        timeline.focusState = Focus(id: "a", depth: 1)

        timeline.collapseFocused()

        #expect(model.expandedDepth == 0)
    }

    // MARK: - depth별 독립성

    @Test func reveal_isTrackedPerDepth() {
        let model = status("a", spoilerText: "자식 경고", replyToId: "parent")
        model.parents = [FakeStatusAdaptor(id: "parent", spoilerText: "부모 경고")]
        model.expandedDepth = 1

        let timeline = makeTimeline([model])

        timeline.focusState = Focus(id: "a", depth: 0)
        timeline.expandFocused()

        #expect(model.isRevealed(at: 0))
        // 부모 글의 경고는 따로 펼쳐야 한다.
        #expect(!model.isRevealed(at: 1))

        timeline.focusState = Focus(id: "a", depth: 1)
        timeline.expandFocused()

        #expect(model.isRevealed(at: 1))
    }

    // MARK: - toggleReveal

    @Test func toggleReveal_onPostWithoutWarning_isIgnored() {
        let model = status("a")

        model.toggleReveal(at: 0)

        #expect(model.revealedDepths.isEmpty)
    }

    @Test func toggleReveal_flipsBothWays() {
        let model = status("a", spoilerText: "스포일러 주의")

        model.toggleReveal(at: 0)
        #expect(model.isRevealed(at: 0))

        model.toggleReveal(at: 0)
        #expect(!model.isRevealed(at: 0))
    }

    /// 부스트 행에서 감춰야 할 본문은 부스트한 사람의 것이 아니라 원본 쪽이다.
    @Test func hasContentWarning_onBoost_readsTheBoostedStatus() {
        let boosted = FakeStatusAdaptor(id: "inner", spoilerText: "스포일러 주의")
        let model = StatusModel(adaptor: FakeStatusAdaptor(id: "outer", reblog: boosted))

        #expect(model.hasContentWarning(at: 0))

        model.toggleReveal(at: 0)
        #expect(model.isRevealed(at: 0))
    }
}
