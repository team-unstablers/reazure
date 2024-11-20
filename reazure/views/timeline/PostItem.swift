//
//  PostItem.swift
//  reazure
//
//  Created by cheesekun on 11/2/24.
//

import SwiftUI

/*
 enum PostItemType {
 case normal
 case reblog
 case favourite
 }
 */

struct PostItemFlags: RawRepresentable, OptionSet {
    let rawValue: UInt8
    
    static let mentioned = PostItemFlags(rawValue: 0b1)
    
    // NOTE: '타인'으로부터 내 포스트가 fav/reblog된 경우
    static let favouritedByOthers = PostItemFlags(rawValue: 0b10)
    static let rebloggedByOthers = PostItemFlags(rawValue: 0b100)
    
    static let reblogged = PostItemFlags(rawValue: 0b1000)
    
    static let expanded = PostItemFlags(rawValue: 0b10000)
}

struct PostItem: View, Equatable {
    @Environment(\.openURL)
    var openURL
    
    var status: StatusAdaptor
    
    var relatedAccount: AccountAdaptor? = nil
    var flags: PostItemFlags = []
    // var type: PostItemType = .normal
    
    var expandButtonHandler: (StatusAdaptor) -> Void = { _ in }
    
    var background: Color {
        if flags.contains(.rebloggedByOthers) {
            return .init(uiColor: UIColor(r8: 135, g8: 245, b8: 66, a: 0.2))
        } else if flags.contains(.favouritedByOthers) {
            return .init(uiColor: UIColor(r8: 245, g8: 239, b8: 66, a: 0.2))
        }
        
        return .clear
    }
    
    var textColor: Color {
        if flags.contains(.mentioned) {
            return .init(uiColor: UIColor(r8: 66, g8: 78, b8: 245, a: 1.0))
        }
        
        return .primary
    }
    
    var attachment: some View {
        Group {
            if !status.attachments.isEmpty {
                HStack {
                    ForEach(status.attachments, id: \.id) { attachment in
                        // FIXME: preview_url에 가드를 넣는 것보단 흰색 placeholder라도 표시하는게 좋아
                        if attachment.type == "image",
                           let previewUrl = attachment.previewUrl
                        {
                            AsyncImage(url: URL(string: previewUrl)) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 64, height: 64)
                                    .clipped()
                                    .contentShape(Rectangle())
                            } placeholder: {
                                ProgressView()
                                    .frame(width: 64, height: 64)
                            }
                            .onTapGesture {
                                guard let url = URL(string: attachment.originUrl ?? attachment.url) else {
                                    return
                                }
                                
                                openURL(url)
                            }
                        }
                    }
                }
            }
            
            if let relatedAccount = self.relatedAccount {
                if self.flags.contains(.favouritedByOthers) {
                    ActivityPubMarkupText(content: "Favourited by \(relatedAccount.displayName) (@\(relatedAccount.acct))", emojos: relatedAccount.emojis)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else if (self.flags.contains(.rebloggedByOthers) || self.flags.contains(.reblogged)) {
                    ActivityPubMarkupText(content: "Boosted by \(relatedAccount.displayName) (@\(relatedAccount.acct))", emojos: relatedAccount.emojis)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else {
                    EmptyView()
                }
            }
        }
    }
    
    var body: some View {
        if let reblog = status.reblog {
            PostItem(status: reblog, relatedAccount: status.account, flags: flags, expandButtonHandler: expandButtonHandler)
        } else {
            HStack(alignment: .top, spacing: 0) {
                HStack(spacing: 0) {
                    if let relatedAccount = self.relatedAccount {
                        ZStack {
                            Rectangle()
                                .foregroundStyle(.clear)
                                .frame(width: 56, height: 56)
                            ProfileImage(url: status.account.avatar, size: 48)
                                .equatable()
                                .offset(x: -4, y: -4)
                            ProfileImage(url: relatedAccount.avatar, size: 32)
                                .equatable()
                                .offset(x: 12, y: 12)
                        }
                    } else {
                        ProfileImage(url: status.account.avatar)
                            .equatable()
                    }
                }
                    .padding(.trailing, 12)
                    .fixedSize()
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline) {
                        ActivityPubMarkupText(content: "\(status.account.displayName) (@\(status.account.acct))",
                                              emojos: status.account.emojis)
                        .bold()
                        Spacer()
                        if status.favourited {
                            Text("⭐️").lineSpacing(1)
                        }
                        if status.reblogged {
                            Text("🔁").lineSpacing(1)
                        }
                        if status.visibility == .unlisted {
                            Text("🌙").lineSpacing(1)
                        }
                        if status.visibility == .privateType {
                            Text("🔒").lineSpacing(1)
                        }
                    }
                    .lineLimit(1)
                    ActivityPubMarkupText(content: status.content, emojos: status.emojis)
                        .foregroundColor(textColor)
                    
                    
                    self.attachment
                    
                    HStack(alignment: .firstTextBaseline) {
                        Text(verbatim: status.footerContent)
                            .foregroundColor(.secondary)
                        
                        
                        if status.replyToId != nil {
                            Spacer()
                            Button {
                                expandButtonHandler(status)
                            } label: {
                                if flags.contains(.expanded) {
                                    Image("tl_depth_minus")
                                        .resizable()
                                        .frame(width: 16, height: 16)
                                } else {
                                    Image("tl_depth_plus")
                                        .resizable()
                                        .frame(width: 16, height: 16)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            // .containerRelativeFrame([.horizontal], alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .contentShape(Rectangle())
            .background(background)
            .overlay(Divider(), alignment: .bottom)
        }

    }
    
    static func == (lhs: PostItem, rhs: PostItem) -> Bool {
        return (
            lhs.status.id == rhs.status.id &&
            lhs.status.favourited == rhs.status.favourited &&
            lhs.status.reblogged == rhs.status.reblogged &&
            lhs.flags == rhs.flags
        )
    }
}

fileprivate extension StatusAdaptor {
    var footerContent: String {
        let prettyDate = createdAt.prettyDate()
        
        if let application = application {
            return "\(prettyDate) / via \(application.name)"
        }
        
        return prettyDate
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
        PostItem(status: status)
        PostItem(status: reblogStatus)
        PostItem(status: status, relatedAccount: status.account, flags: .favouritedByOthers)
        /*
         Button {} label: {
         PostItem(status: mentionStatus, selfId: "1", type: .favourite, relatedUser: status.account)
         }
         .buttonStyle(.plain)
         */
    }
}


