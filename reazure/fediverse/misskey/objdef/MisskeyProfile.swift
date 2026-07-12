//
//  Profile.swift
//  reazure
//
//  Misskey account adaptor bridging `Misskey.User` to `AccountAdaptor`.
//

class MisskeyAccountAdaptor: AccountAdaptor {
    let _user: Misskey.User

    var id: String { _user.id }
    var username: String { _user.username }
    /// `username` for local users; `username@host` for remote ones.
    var acct: String {
        if let host = _user.host {
            return "\(_user.username)@\(host)"
        }
        return _user.username
    }

    var url: String? { nil }

    var displayName: String { _user.name ?? _user.username }
    var locked: Bool { _user.isLocked ?? false }
    var bot: Bool { _user.isBot ?? false }

    var avatar: String { _user.avatarUrl ?? "" }

    // Custom emoji rendering is out of scope.
    var emojis: [EmojiAdaptor] { [] }

    init(from user: Misskey.User) {
        self._user = user
    }
}
