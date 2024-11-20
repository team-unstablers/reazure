//
//  PostItem.swift
//  reazure
//
//  Created by cheesekun on 11/2/24.
//

import SwiftUI

struct CompactPostItem: View, Equatable {
    @Environment(\.openURL)
    var openURL

    var status: StatusAdaptor
    
    var relatedAccount: AccountAdaptor? = nil
    var flags: PostItemFlags = []
    
    var background: Color {
        if flags.contains(.rebloggedByOthers) {
            return .init(uiColor: UIColor(r8: 135, g8: 245, b8: 66, a: 0.2))
        } else if flags.contains(.favouritedByOthers) {
            return .init(uiColor: UIColor(r8: 245, g8: 239, b8: 66, a: 0.2))
        }
        
        return .init(uiColor: .systemBackground)
    }
    
    var textColor: Color {
        if flags.contains(.mentioned) {
            return .init(uiColor: UIColor(r8: 66, g8: 78, b8: 245, a: 1.0))
        }
        
        return .primary
    }
    
    var body: some View {
        if let reblog = status.reblog {
            CompactPostItem(status: reblog, relatedAccount: status.account, flags: flags)
        } else {
            HStack(alignment: .center) {
                VStack {
                    if let relatedAccount = relatedAccount {
                        ZStack {
                            // crop left 24 pixels
                            
                            ProfileImage(url: status.account.avatar, size: 48, compact: true)
                                .equatable()
                                .clipShape(Rectangle().size(width: 24, height: 24))
                                
                            ProfileImage(url: relatedAccount.avatar, size: 48, compact: true)
                                .equatable()
                                .clipShape(Rectangle().size(width: 24, height: 24).offset(x: 24))
                        }
                    } else {
                        ProfileImage(url: status.account.avatar, size: 48, compact: true)
                            .equatable()
                    }
                }.padding(.trailing, 2)
                ActivityPubMarkupText(element: status.parsedContent, emojos: status.emojis)
                    .equatable()
                    .foregroundColor(textColor)
                    .lineLimit(1)
            }
            // .containerRelativeFrame([.horizontal], alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .contentShape(Rectangle())
            .background(background)
            .overlay(Divider(), alignment: .bottom)
        }
    }
    
    static func == (lhs: CompactPostItem, rhs: CompactPostItem) -> Bool {
        return (
            lhs.status.id == rhs.status.id &&
            lhs.status.favourited == rhs.status.favourited &&
            lhs.status.reblogged == rhs.status.reblogged &&
            lhs.flags == rhs.flags
        )
    }
}


fileprivate extension String {
    func parseDate() -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        return formatter.date(from: self)
    }
    
    func prettyDate() -> String {
        guard let date = parseDate() else {
            return self
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        
        return formatter.string(from: date)
    }
}

#Preview {
    let status = MastodonStatusAdaptor(from: Mastodon.Status(
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
            
            avatar: "https://ppiy.ac/system/accounts/avatars/110/796/233/076/688/314/original/df6e9ebf6bb70ef2.jpg",
            emojis: []
        ),
        
        favourited: false,
        reblogged: false,
        
        reblog: nil,
        emojis: [],
        mentions: [],
        media_attachments: [
            Mastodon.MediaAttachment(
                id: "1234",
                type: "image",
                url: "https://ppiy.ac/system/accounts/avatars/110/796/233/076/688/314/original/df6e9ebf6bb70ef2.jpg",
                preview_url: "https://ppiy.ac/system/accounts/avatars/110/796/233/076/688/314/original/df6e9ebf6bb70ef2.jpg",
                remote_url: "https://ppiy.ac/system/accounts/avatars/110/796/233/076/688/314/original/df6e9ebf6bb70ef2.jpg"
            ),
            Mastodon.MediaAttachment(
                id: "1235",
                type: "image",
                url: "https://ppiy.ac/system/accounts/avatars/110/796/233/076/688/314/original/df6e9ebf6bb70ef2.jpg",
                preview_url: "https://ppiy.ac/system/accounts/avatars/110/796/233/076/688/314/original/df6e9ebf6bb70ef2.jpg",
                remote_url: "https://ppiy.ac/system/accounts/avatars/110/796/233/076/688/314/original/df6e9ebf6bb70ef2.jpg"
            ),
            Mastodon.MediaAttachment(
                id: "1236",
                type: "image",
                url: "https://ppiy.ac/system/accounts/avatars/110/796/233/076/688/314/original/df6e9ebf6bb70ef2.jpg",
                preview_url: "https://ppiy.ac/system/accounts/avatars/110/796/233/076/688/314/original/df6e9ebf6bb70ef2.jpg",
                remote_url: "https://ppiy.ac/system/accounts/avatars/110/796/233/076/688/314/original/df6e9ebf6bb70ef2.jpg"
            ),
            Mastodon.MediaAttachment(
                id: "1237",
                type: "image",
                url: "https://ppiy.ac/system/accounts/avatars/110/796/233/076/688/314/original/df6e9ebf6bb70ef2.jpg",
                preview_url: "https://ppiy.ac/system/accounts/avatars/110/796/233/076/688/314/original/df6e9ebf6bb70ef2.jpg",
                remote_url: "https://ppiy.ac/system/accounts/avatars/110/796/233/076/688/314/original/df6e9ebf6bb70ef2.jpg"
            ),
        ],
        application: Mastodon.Application(name: "re;azure")
    ))
    
    let mentionStatus = MastodonStatusAdaptor(from: Mastodon.Status(
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
            
            avatar: "https://ppiy.ac/system/accounts/avatars/110/796/233/076/688/314/original/df6e9ebf6bb70ef2.jpg",
            emojis: []
        ),
        
        favourited: false,
        reblogged: false,
        
        reblog: nil,
        emojis: [],
        mentions: [
            Mastodon.Mention(id: "1", username: "cheesekun", acct: "cheesekun")
        ],
        media_attachments: [],
        application: Mastodon.Application(name: "re;azure")
    ))
    
    let reblogStatus = MastodonStatusAdaptor(from: Mastodon.Status(
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
            
            avatar: "https://ppiy.ac/system/accounts/avatars/110/796/233/076/688/314/original/df6e9ebf6bb70ef2.jpg",
            emojis: []
        ),
        
        favourited: false,
        reblogged: false,
        
        reblog: Box(status._status),
        emojis: [],
        mentions: [],
        media_attachments: [],
        application: Mastodon.Application(name: "re;azure")
    ))
    
    VStack(spacing: 0) {
        CompactPostItem(status: status)
        /*
        Button {} label: {
            PostItem(status: mentionStatus, selfId: "1", type: .favourite, relatedUser: status.account)
        }
        .buttonStyle(.plain)
         */
    }
}


