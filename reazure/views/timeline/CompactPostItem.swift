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
                    ProfileImageStack(
                        primary: status.account.avatar,
                        secondary: relatedAccount?.avatar,
                        compact: true
                    )
                }.padding(.trailing, 2)
                ActivityPubMarkupText(element: status.parsedContent, emojos: status.emojis)
                    .equatable()
                    .foregroundColor(textColor)
                    .lineLimit(1)
            }
            .if(status.deleted) {
                $0.strikethrough()
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
            lhs.status.deleted == rhs.status.deleted &&
            lhs.status.account.avatar == rhs.status.account.avatar &&
            lhs.relatedAccount?.avatar == rhs.relatedAccount?.avatar &&
            lhs.flags == rhs.flags
        )
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 0) {
        CompactPostItem(status: PreviewSamples.status)
    }
}
#endif
