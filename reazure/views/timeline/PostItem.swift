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
                    Text(verbatim: "\(status.account.display_name) (@\(status.account.acct))")
                        .bold()
                    Text(AttributedString(parseHTML(status.content).asNSAttributedString()))
                    Text(verbatim: "2022-11-02 00:00:00 / via reazure")
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

#Preview {
    let status = Status(
        id: "1",
        content: "Hello, World!",
        account: UserProfile(
            id: "1",
            username: "cheesekun",
            acct: "cheesekun",
            
            display_name: "치즈군★",
            
            avatar: "https://ppiy.ac/system/accounts/avatars/110/796/233/076/688/314/original/df6e9ebf6bb70ef2.jpg"
        ),
        reblog: nil
    )
    
    PostItem(status: status)
}
