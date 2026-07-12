//
//  MisskeyAdaptorMappingTests.swift
//  reazureTests
//
//  Unit coverage for the Misskey adaptor mappings: visibility (both directions),
//  notification types, and the account acct/displayName/flag rules.
//

import Foundation
import Testing

@testable import reazure

struct MisskeyAdaptorMappingTests {

    private func user(name: String? = "Alice", host: String? = nil) throws -> Misskey.User {
        let nameField = name.map { "\"\($0)\"" } ?? "null"
        let hostField = host.map { "\"\($0)\"" } ?? "null"
        let json = """
        {"id":"u1","username":"alice","name":\(nameField),"host":\(hostField),"avatarUrl":"https://x/a.png","isBot":true,"isLocked":true}
        """
        return try JSON.parse(json, to: Misskey.User.self)
    }

    @Test func visibility_mapsMisskeyToShared() {
        #expect(StatusVisibility(misskey: "public") == .publicType)
        #expect(StatusVisibility(misskey: "home") == .unlisted)
        #expect(StatusVisibility(misskey: "followers") == .privateType)
        #expect(StatusVisibility(misskey: "specified") == .direct)
        #expect(StatusVisibility(misskey: "unknown") == .publicType)
    }

    @Test func visibility_mapsSharedToMisskey() {
        #expect(StatusVisibility.publicType.misskeyValue == "public")
        #expect(StatusVisibility.unlisted.misskeyValue == "home")
        #expect(StatusVisibility.privateType.misskeyValue == "followers")
        #expect(StatusVisibility.direct.misskeyValue == "specified")
    }

    @Test func notificationType_mapsMisskeyTypes() {
        #expect(NotificationType(misskey: "mention") == .mention)
        #expect(NotificationType(misskey: "reply") == .mention)
        #expect(NotificationType(misskey: "renote") == .reblog)
        #expect(NotificationType(misskey: "quote") == .reblog)
        #expect(NotificationType(misskey: "reaction") == .favourite)
        #expect(NotificationType(misskey: "follow") == .follow)
        #expect(NotificationType(misskey: "receiveFollowRequest") == .followRequest)
    }

    @Test func account_acctIsUsernameForLocal() throws {
        let adaptor = MisskeyAccountAdaptor(from: try user(host: nil))
        #expect(adaptor.acct == "alice")
    }

    @Test func account_acctHasHostSuffixForRemote() throws {
        let adaptor = MisskeyAccountAdaptor(from: try user(host: "remote.example"))
        #expect(adaptor.acct == "alice@remote.example")
    }

    @Test func account_displayNameFallsBackToUsername() throws {
        let adaptor = MisskeyAccountAdaptor(from: try user(name: nil))
        #expect(adaptor.displayName == "alice")
    }

    @Test func account_mapsBotAndLockedFlags() throws {
        let adaptor = MisskeyAccountAdaptor(from: try user())
        #expect(adaptor.bot == true)
        #expect(adaptor.locked == true)
    }
}
