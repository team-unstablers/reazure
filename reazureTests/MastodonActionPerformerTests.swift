//
//  MastodonActionPerformerTests.swift
//  reazureTests
//
//  Regression coverage for the `MastodonActionPerformer` seam extracted from
//  `SharedClient` (roadmap step 2.1). The compose-reply path is the one write
//  action that does not require a live `MastodonClient`, so it pins that the
//  performer publishes onto the shared `replyTo` subject owned by the facade.
//

import Testing

import Combine

@testable import reazure

@MainActor
struct MastodonActionPerformerTests {

    @Test func composeReplyTo_publishesOntoInjectedReplySubject() async throws {
        let subject = CurrentValueSubject<StatusAdaptor?, Never>(nil)
        let performer = MastodonActionPerformer(replyTo: subject)

        let target = FakeStatusAdaptor(id: "reply-target")
        let model = StatusModel(adaptor: FakeStatusAdaptor(id: "carrier"))

        try await performer.statusModel(wantsComposeReplyTo: target, model: model)

        #expect(subject.value?.id == "reply-target")
    }

    @Test func composeReplyTo_isThreadedThroughTheSameSubjectSharedClientVends() async throws {
        // The performer must not own a private subject: `PostArea` subscribes to
        // the facade's `replyTo`, so publishing must be visible on that instance.
        let subject = CurrentValueSubject<StatusAdaptor?, Never>(nil)
        let performer = MastodonActionPerformer(replyTo: subject)

        var received: [String?] = []
        let cancellable = subject.sink { received.append($0?.id) }
        defer { cancellable.cancel() }

        let model = StatusModel(adaptor: FakeStatusAdaptor(id: "carrier"))
        try await performer.statusModel(wantsComposeReplyTo: FakeStatusAdaptor(id: "s1"), model: model)

        // `nil` seed from the CurrentValueSubject, then the published reply target.
        #expect(received == [nil, "s1"])
    }
}
