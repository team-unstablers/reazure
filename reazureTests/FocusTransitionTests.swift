//
//  FocusTransitionTests.swift
//  reazureTests
//
//  Regression coverage for the j/k/h/l focus arithmetic in
//  `TimelineModel+shortcuts.swift` (roadmap step 1.1). Depth stepping lets j/k
//  walk an expanded reply chain within a single row before moving between rows,
//  so these lock down the off-by-one and boundary behaviour.
//

import Testing

@testable import reazure

@MainActor
struct FocusTransitionTests {

    private typealias Focus = TimelineModel.FocusState

    /// Builds a timeline whose display order matches `models` (index 0 first).
    private func makeTimeline(_ models: [StatusModel]) -> TimelineModel {
        let timeline = TimelineModel(with: SharedClient.shared)
        for model in models.reversed() {
            timeline.prepend(model)
        }
        return timeline
    }

    private func status(_ id: String, replyToId: String? = nil) -> StatusModel {
        StatusModel(adaptor: FakeStatusAdaptor(id: id, replyToId: replyToId))
    }

    // MARK: - focusNext

    @Test func focusNext_fromNoFocus_focusesFirstRow() {
        let timeline = makeTimeline([status("a"), status("b"), status("c")])
        timeline.focusState = nil

        timeline.focusNext()

        #expect(timeline.focusState?.id == "a")
        #expect(timeline.focusState?.depth == 0)
    }

    @Test func focusNext_advancesToNextRow() {
        let timeline = makeTimeline([status("a"), status("b"), status("c")])
        timeline.focusState = Focus(id: "a", depth: 0)

        timeline.focusNext()

        #expect(timeline.focusState?.id == "b")
        #expect(timeline.focusState?.depth == 0)
    }

    @Test func focusNext_atLastRow_clampsToLastRow() {
        let timeline = makeTimeline([status("a"), status("b"), status("c")])
        timeline.focusState = Focus(id: "c", depth: 0)

        timeline.focusNext()

        #expect(timeline.focusState?.id == "c")
        #expect(timeline.focusState?.depth == 0)
    }

    @Test func focusNext_stepsIntoExpandedDepthBeforeMovingRow() {
        let a = status("a")
        let b = status("b")
        a.expandedDepth = 1
        let timeline = makeTimeline([a, b])
        timeline.focusState = Focus(id: "a", depth: 0)

        // depth 0 < expandedDepth 1 → step into the reply chain, same row.
        timeline.focusNext()
        #expect(timeline.focusState?.id == "a")
        #expect(timeline.focusState?.depth == 1)

        // depth 1 is the tail → move to the next row.
        timeline.focusNext()
        #expect(timeline.focusState?.id == "b")
        #expect(timeline.focusState?.depth == 0)
    }

    // MARK: - focusPrevious

    @Test func focusPrevious_movesToPreviousRow() {
        let timeline = makeTimeline([status("a"), status("b"), status("c")])
        timeline.focusState = Focus(id: "c", depth: 0)

        timeline.focusPrevious()

        #expect(timeline.focusState?.id == "b")
        #expect(timeline.focusState?.depth == 0)
    }

    @Test func focusPrevious_atFirstRowDepthZero_staysPut() {
        let timeline = makeTimeline([status("a"), status("b"), status("c")])
        timeline.focusState = Focus(id: "a", depth: 0)

        timeline.focusPrevious()

        #expect(timeline.focusState?.id == "a")
        #expect(timeline.focusState?.depth == 0)
    }

    @Test func focusPrevious_stepsDownDepthWithinRow() {
        let a = status("a")
        a.expandedDepth = 1
        let timeline = makeTimeline([a, status("b")])
        timeline.focusState = Focus(id: "a", depth: 1)

        timeline.focusPrevious()

        #expect(timeline.focusState?.id == "a")
        #expect(timeline.focusState?.depth == 0)
    }

    @Test func focusPrevious_landsOnExpandedTailOfPreviousRow() {
        let a = status("a")
        let b = status("b")
        b.expandedDepth = 2
        let timeline = makeTimeline([a, b, status("c")])
        timeline.focusState = Focus(id: "c", depth: 0)

        // Moving up into an expanded row lands on its deepest expanded depth.
        timeline.focusPrevious()

        #expect(timeline.focusState?.id == "b")
        #expect(timeline.focusState?.depth == 2)
    }

    // MARK: - expandFocused

    @Test func expandFocused_withReplyParent_increasesDepth() {
        let a = status("a", replyToId: "parent-1")
        let timeline = makeTimeline([a])
        timeline.focusState = Focus(id: "a", depth: 0)

        timeline.expandFocused()

        #expect(a.expandedDepth == 1)
    }

    @Test func expandFocused_withoutReplyParent_isNoOp() {
        let a = status("a", replyToId: nil)
        let timeline = makeTimeline([a])
        timeline.focusState = Focus(id: "a", depth: 0)

        timeline.expandFocused()

        #expect(a.expandedDepth == 0)
    }

    // MARK: - collapseFocused

    @Test func collapseFocused_decrementsDepth() {
        let a = status("a")
        a.expandedDepth = 2
        let timeline = makeTimeline([a])
        timeline.focusState = Focus(id: "a", depth: 2)

        timeline.collapseFocused()

        #expect(a.expandedDepth == 1)
        #expect(timeline.focusState?.id == "a")
        #expect(timeline.focusState?.depth == 1)
    }

    @Test func collapseFocused_atDepthZero_staysAtZero() {
        let a = status("a")
        a.expandedDepth = 0
        let timeline = makeTimeline([a])
        timeline.focusState = Focus(id: "a", depth: 0)

        timeline.collapseFocused()

        #expect(a.expandedDepth == 0)
        #expect(timeline.focusState?.depth == 0)
    }
}
