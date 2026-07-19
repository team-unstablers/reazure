//
//  Status.swift
//  reazure
//
//  Misskey status/notification adaptors + the visibility / notification-type
//  bridges. Mirrors the Mastodon adaptor factory in `mastodon/objdef/Status.swift`.
//

import Foundation

extension StatusVisibility {
    /// Maps a Misskey note visibility (`public`/`home`/`followers`/`specified`)
    /// onto the server-agnostic visibility.
    init(misskey visibility: String) {
        switch visibility {
        case "public":
            self = .publicType
        case "home":
            self = .unlisted
        case "followers":
            self = .privateType
        case "specified":
            self = .direct
        default:
            self = .publicType
        }
    }

    /// The Misskey wire value for this visibility (reverse of `init(misskey:)`).
    var misskeyValue: String {
        switch self {
        case .publicType:
            return "public"
        case .unlisted:
            return "home"
        case .privateType:
            return "followers"
        case .direct:
            return "specified"
        }
    }
}

extension NotificationType {
    /// Maps a Misskey notification type onto the server-agnostic type. `reaction`
    /// surfaces as `favourite` (per product decision); types without an attached
    /// note (e.g. `follow`) map to a placeholder and are later dropped by
    /// `NotificationModel` when their status is nil — matching Mastodon's
    /// follow-notification drop behaviour.
    init(misskey type: String) {
        switch type {
        case "mention", "reply":
            self = .mention
        case "renote", "quote":
            self = .reblog
        case "reaction":
            self = .favourite
        case "follow":
            self = .follow
        case "receiveFollowRequest":
            self = .followRequest
        default:
            self = .mention
        }
    }
}

/// Escapes the HTML metacharacters in a plaintext Misskey note. `&` must be
/// replaced first so the entities introduced by the later replacements are not
/// double-escaped.
func misskeyHTMLEscape(_ text: String) -> String {
    return text
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "'", with: "&#39;")
}

class MisskeyAttachmentAdaptor: AttachmentAdaptor {
    let _file: Misskey.DriveFile

    var id: String { _file.id }
    /// The leading MIME type component (`image/png` → `image`), matching the
    /// coarse `type` values Mastodon attachments expose that the views branch on.
    var type: String { _file.type.split(separator: "/").first.map(String.init) ?? _file.type }
    var url: String { _file.url }
    var previewUrl: String? { _file.thumbnailUrl }
    var originUrl: String? { nil }

    init(from file: Misskey.DriveFile) {
        self._file = file
    }
}

class MisskeyStatusAdaptor: StatusAdaptor {
    let _note: Misskey.Note

    var id: String { _note.id }
    var createdAt: String { _note.createdAt }

    var replyToId: String? { _note.replyId }

    var url: String? { _note.url ?? _note.uri }

    var visibility: StatusVisibility

    var content: String
    var parsedContent: HTMLElement

    /// Misskey's `cw` is the direct counterpart of Mastodon's `spoiler_text`; an
    /// empty string is normalized to `nil` the same way.
    var spoilerText: String? {
        guard let cw = _note.cw, !cw.isEmpty else {
            return nil
        }
        return cw
    }
    /// Misskey flags sensitivity per drive file rather than per note, so the note
    /// counts as sensitive when any of its attachments is.
    var sensitive: Bool { (_note.files ?? []).contains { $0.isSensitive == true } }

    var account: AccountAdaptor

    /// Misskey has no Mastodon-style favourite; the app maps favourite onto a
    /// `⭐` reaction, so "favourited" ⇔ the current user has any reaction.
    var favourited: Bool { _note.myReaction != nil }
    /// Misskey notes carry no "did I renote this" flag, so the initial state is
    /// always `false` and the pressed state is driven purely by optimistic
    /// masking; un-renote goes through `notes/unrenote`.
    var reblogged: Bool { false }

    var deleted: Bool { false }

    var reblog: (any StatusAdaptor)?

    // Custom emoji / mention autolinking is out of scope (no MFM).
    var emojis: [EmojiAdaptor] { [] }
    var mentions: [MentionAdaptor] { [] }

    var attachments: [AttachmentAdaptor]
    var application: ApplicationAdaptor? { nil }

    init(from note: Misskey.Note) {
        self._note = note

        self.visibility = StatusVisibility(misskey: note.visibility)

        // No MFM parsing: escape the plaintext and turn newlines into <br>, then
        // reuse the shared HTML parser. The `cw` text itself is surfaced through
        // `spoilerText` and rendered as plain text by the views.
        let html = misskeyHTMLEscape(note.text ?? "")
            .replacingOccurrences(of: "\n", with: "<br>")
        self.content = html
        self.parsedContent = parseHTML(html)

        self.account = MisskeyAccountAdaptor(from: note.user)
        self.attachments = (note.files ?? []).map { MisskeyAttachmentAdaptor(from: $0) }

        // A pure renote (boost): no text, just a renoteId + the embedded renote.
        // Map it like Mastodon's `status.reblog`. A quote (text present alongside
        // a renoteId) is treated as a plain note for basic parity.
        if note.text == nil, note.renoteId != nil, let renote = note.renote {
            self.reblog = MisskeyStatusAdaptor(from: renote.wrappedValue)
        }
    }
}

class MisskeyNotificationAdaptor: NotificationAdaptor {
    let _notification: Misskey.Notification

    var id: String { _notification.id }
    var createdAt: String { _notification.createdAt }

    var type: NotificationType { NotificationType(misskey: _notification.type) }

    var account: AccountAdaptor?
    var status: StatusAdaptor?

    init(from notification: Misskey.Notification) {
        self._notification = notification

        if let user = notification.user {
            self.account = MisskeyAccountAdaptor(from: user)
        }

        if let note = notification.note {
            self.status = MisskeyStatusAdaptor(from: note)
        }
    }
}
