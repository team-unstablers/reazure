//
//  FediverseServerCodableTests.swift
//  reazureTests
//
//  Guards the `FediverseServer` Codable round-trip — in particular the Misskey
//  decode path whose absence used to crash on reloading a persisted Misskey
//  account.
//

import Foundation
import Testing

@testable import reazure

struct FediverseServerCodableTests {

    @Test func misskeyServer_roundTripsThroughCodable() throws {
        let server = FediverseServer.misskey(address: "misskey.example")
        let data = try JSONEncoder().encode(server)
        let decoded = try JSONDecoder().decode(FediverseServer.self, from: data)

        #expect(decoded == .misskey(address: "misskey.example"))
    }

    @Test func mastodonServer_roundTripsThroughCodable() throws {
        let server = FediverseServer.mastodon(address: "mastodon.example")
        let data = try JSONEncoder().encode(server)
        let decoded = try JSONDecoder().decode(FediverseServer.self, from: data)

        #expect(decoded == .mastodon(address: "mastodon.example"))
    }

    @Test func misskeyAccount_roundTripsThroughCodable() throws {
        let account = Account(id: "u1",
                              username: "alice",
                              server: .misskey(address: "misskey.example"),
                              accessToken: "tok")
        let data = try JSONEncoder().encode(account)
        let decoded = try JSONDecoder().decode(Account.self, from: data)

        #expect(decoded.server == .misskey(address: "misskey.example"))
        #expect(decoded.accessToken == "tok")
        #expect(decoded.id == "u1")
    }
}
