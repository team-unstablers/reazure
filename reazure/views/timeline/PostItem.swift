//
//  PostItem.swift
//  reazure
//
//  Created by cheesekun on 11/2/24.
//

import SwiftUI

enum PostItemType {
    case normal
    case reblog
    case favourite
}

struct PostItem: View {
    var status: Status
    
    /// 현재 사용자의 ID: mention 판정을 위해 사용
    var selfId: String = ""
    
    var type: PostItemType = .normal
    var relatedUser: UserProfile? = nil
    
    var background: Color {
        switch type {
        case .reblog:
            return .init(uiColor: UIColor(r8: 135, g8: 245, b8: 66, a: 0.2))
        case .favourite:
            return .init(uiColor: UIColor(r8: 245, g8: 239, b8: 66, a: 0.2))
        default:
            return .clear
        }
    }
    
    var textColor: Color {
        if status.mentions(id: selfId) {
            return .init(uiColor: UIColor(r8: 66, g8: 78, b8: 245, a: 1.0))
        }
        
        return .primary
    }
    
    var body: some View {
        if let reblog = status.reblog {
            PostItem(status: reblog.wrappedValue, type: .reblog, relatedUser: status.account)
        } else {
            HStack(alignment: .top) {
                if let relatedUser = self.relatedUser {
                    ZStack {
                        ProfileImage(url: status.account.avatar)
                        ProfileImage(url: relatedUser.avatar, size: 32)
                            .offset(x: 16, y: 16)
                    }
                } else {
                    ProfileImage(url: status.account.avatar)
                }
                VStack(alignment: .leading, spacing: 2) {
                    ActivityPubMarkupText(content: "\(status.account.display_name) (@\(status.account.acct))",
                                          emojos: status.account.emojis)
                        .bold()
                    ActivityPubMarkupText(content: status.content, emojos: status.emojis)
                        .foregroundColor(textColor)
                    
                    if let relatedUser = self.relatedUser {
                        switch type {
                        case .favourite:
                            ActivityPubMarkupText(content: "Favourited by \(relatedUser.display_name) (@\(relatedUser.acct))", emojos: relatedUser.emojis)
                                .foregroundColor(.secondary)
                        case .reblog:
                            ActivityPubMarkupText(content: "Boosted by \(relatedUser.display_name) (@\(relatedUser.acct))", emojos: relatedUser.emojis)
                                .foregroundColor(.secondary)
                        default:
                            EmptyView()
                        }
                    }
                    
                    Text(verbatim: status.footerContent)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            // .containerRelativeFrame([.horizontal], alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(background)
            .overlay(Divider(), alignment: .bottom)
        }
    }
}

fileprivate extension Status {
    var footerContent: String {
        let prettyDate = created_at.prettyDate()
        
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
    let status = Status(
        id: "1",
        created_at: "2019-11-26T23:27:32.000Z",
        visibility: "public",
        content: "Hello, World!",
        account: UserProfile(
            id: "1",
            username: "cheesekun",
            acct: "cheesekun",
            
            display_name: "치즈군★",
            
            avatar: "https://ppiy.ac/system/accounts/avatars/110/796/233/076/688/314/original/df6e9ebf6bb70ef2.jpg",
            emojis: []
        ),
        reblog: nil,
        emojis: [],
        mentions: [],
        application: Application(name: "re;azure")
    )
    
    let mentionStatus = Status(
        id: "42",
        created_at: "2019-11-26T23:27:32.000Z",
        visibility: "public",
        content: "@cheesekun Hello, World!",
        account: UserProfile(
            id: "2",
            username: "ppiyac",
            acct: "ppiyac",
            
            display_name: "삐약이",
            
            avatar: "https://ppiy.ac/system/accounts/avatars/110/796/233/076/688/314/original/df6e9ebf6bb70ef2.jpg",
            emojis: []
        ),
        reblog: nil,
        emojis: [],
        mentions: [
            Mention(id: "1", username: "cheesekun", acct: "cheesekun")
        ],
        application: Application(name: "re;azure")
    )
    
    let reblogStatus = Status(
        id: "2",
        created_at: "2019-11-26T23:27:32.000Z",
        visibility: "public",
        content: "Hello, World!",
        account: UserProfile(
            id: "2",
            username: "ppiyac",
            acct: "ppiyac",
            
            display_name: "삐약이",
            
            avatar: "https://ppiy.ac/system/accounts/avatars/110/796/233/076/688/314/original/df6e9ebf6bb70ef2.jpg",
            emojis: []
        ),
        reblog: Box(status),
        emojis: [],
        mentions: [],
        application: Application(name: "re;azure")
    )
    
    VStack(spacing: 0) {
        PostItem(status: status)
        PostItem(status: reblogStatus)
        PostItem(status: status, type: .favourite, relatedUser: status.account)
        PostItem(status: mentionStatus, selfId: "1")
        PostItem(status: mentionStatus, selfId: "1", type: .favourite, relatedUser: status.account)
    }
}


