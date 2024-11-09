//
//  PostItem.swift
//  reazure
//
//  Created by cheesekun on 11/2/24.
//

import SwiftUI

struct PostItem: View {
    var status: Status
    
    var body: some View {
        if let reblog = status.reblog {
            PostItem(status: reblog.wrappedValue)
        } else {
            HStack(alignment: .top) {
                ProfileImage(url: status.account.avatar)
                VStack(alignment: .leading, spacing: 2) {
                    ActivityPubMarkupText(content: "\(status.account.display_name) (@\(status.account.acct))",
                                          emojos: status.account.emojis)
                        .bold()
                    ActivityPubMarkupText(content: status.content, emojos: status.emojis)
                    Text(verbatim: status.footerContent)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            // .containerRelativeFrame([.horizontal], alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
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
        application: Application(name: "re;azure")
    )
    
    PostItem(status: status)
}


