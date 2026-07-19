//
//  PreviewSamples.swift
//  reazure
//
//  SwiftUI 프리뷰 전용 목업 데이터. 여러 타임라인 뷰의 #Preview에서 공유합니다.
//

#if DEBUG
import Foundation

enum PreviewSamples {
    static let avatarURL = "https://ppiy.ac/system/accounts/avatars/110/796/233/076/688/314/original/df6e9ebf6bb70ef2.jpg"

    /// 이미지 첨부 4개를 가진 일반 상태.
    static var rawStatus: Mastodon.Status {
        Mastodon.Status(
            id: "1",
            created_at: "2019-11-26T23:27:32.000Z",
            in_reply_to_id: nil,
            url: "",
            visibility: .publicType,
            content: "Hello, World!",
            account: Mastodon.UserProfile(
                id: "1",
                username: "cheesekun",
                acct: "cheesekun",
                url: "",
                display_name: "치즈군★",
                avatar: avatarURL,
                emojis: []
            ),
            spoiler_text: nil,
            sensitive: false,
            favourited: false,
            reblogged: false,
            reblog: nil,
            emojis: [],
            mentions: [],
            media_attachments: (1234...1237).map { id in
                Mastodon.MediaAttachment(
                    id: "\(id)",
                    type: "image",
                    url: avatarURL,
                    preview_url: avatarURL,
                    remote_url: avatarURL,
                    description: "미리보기용 첨부 이미지 #\(id)"
                )
            },
            application: Mastodon.Application(name: "re;azure")
        )
    }

    /// 멘션을 포함한 상태.
    static var rawMentionStatus: Mastodon.Status {
        Mastodon.Status(
            id: "42",
            created_at: "2019-11-26T23:27:32.000Z",
            in_reply_to_id: nil,
            url: "",
            visibility: .publicType,
            content: "@cheesekun Hello, World!",
            account: Mastodon.UserProfile(
                id: "2",
                username: "ppiyac",
                acct: "ppiyac",
                url: "",
                display_name: "삐약이",
                avatar: avatarURL,
                emojis: []
            ),
            spoiler_text: nil,
            sensitive: false,
            favourited: false,
            reblogged: false,
            reblog: nil,
            emojis: [],
            mentions: [
                Mastodon.Mention(id: "1", username: "cheesekun", acct: "cheesekun")
            ],
            media_attachments: [],
            application: Mastodon.Application(name: "re;azure")
        )
    }

    /// `rawStatus`를 리블로그한 상태.
    static var rawReblogStatus: Mastodon.Status {
        Mastodon.Status(
            id: "2",
            created_at: "2019-11-26T23:27:32.000Z",
            in_reply_to_id: nil,
            url: "",
            visibility: .publicType,
            content: "Hello, World!",
            account: Mastodon.UserProfile(
                id: "2",
                username: "ppiyac",
                acct: "ppiyac",
                url: "",
                display_name: "삐약이",
                avatar: avatarURL,
                emojis: []
            ),
            spoiler_text: nil,
            sensitive: false,
            favourited: false,
            reblogged: false,
            reblog: Box(rawStatus),
            emojis: [],
            mentions: [],
            media_attachments: [],
            application: Mastodon.Application(name: "re;azure")
        )
    }

    /// 열람 경고(CW)와 민감한 미디어가 모두 걸린 상태.
    static var rawSensitiveStatus: Mastodon.Status {
        Mastodon.Status(
            id: "3",
            created_at: "2019-11-26T23:27:32.000Z",
            in_reply_to_id: nil,
            url: "",
            visibility: .publicType,
            content: "본문은 열람 경고를 해제해야 보입니다.",
            account: Mastodon.UserProfile(
                id: "1",
                username: "cheesekun",
                acct: "cheesekun",
                url: "",
                display_name: "치즈군★",
                avatar: avatarURL,
                emojis: []
            ),
            spoiler_text: "스포일러 주의",
            sensitive: true,
            favourited: false,
            reblogged: false,
            reblog: nil,
            emojis: [],
            mentions: [],
            media_attachments: (2234...2235).map { id in
                Mastodon.MediaAttachment(
                    id: "\(id)",
                    type: "image",
                    url: avatarURL,
                    preview_url: avatarURL,
                    remote_url: avatarURL,
                    description: "미리보기용 첨부 이미지 #\(id)"
                )
            },
            application: Mastodon.Application(name: "re;azure")
        )
    }

    static var status: MastodonStatusAdaptor { MastodonStatusAdaptor(from: rawStatus) }
    static var sensitiveStatus: MastodonStatusAdaptor { MastodonStatusAdaptor(from: rawSensitiveStatus) }
    static var mentionStatus: MastodonStatusAdaptor { MastodonStatusAdaptor(from: rawMentionStatus) }
    static var reblogStatus: MastodonStatusAdaptor { MastodonStatusAdaptor(from: rawReblogStatus) }
}
#endif
