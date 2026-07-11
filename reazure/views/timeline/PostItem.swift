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
    @Environment(\.palette)
    var palette: AppPalette
    
    var status: StatusAdaptor
    
    var relatedAccount: AccountAdaptor? = nil
    var flags: PostItemFlags = []
    // var type: PostItemType = .normal
    
    var expandButtonHandler: (StatusAdaptor) -> Void = { _ in }
    
    var background: Color {
        if flags.contains(.rebloggedByOthers) {
            return palette.postItemRebloggedBackground
        } else if flags.contains(.favouritedByOthers) {
            return palette.postItemFavouritedBackground
        }
        
        return .clear
    }
    
    var textColor: Color {
        if flags.contains(.mentioned) {
            return palette.postItemMentionForeground
        }
        
        return palette.postItemNormalForeground
    }
    
    var attachment: some View {
        Group {
            if !status.attachments.isEmpty {
                AttachmentRow(attachments: status.attachments)
            }

            if let relatedAccount = self.relatedAccount {
                if self.flags.contains(.favouritedByOthers) {
                    ActivityPubMarkupTextSimple(content: "Favourited by \(relatedAccount.displayName) (@\(relatedAccount.acct))", emojos: relatedAccount.emojis)
                        .equatable()
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else if (self.flags.contains(.rebloggedByOthers) || self.flags.contains(.reblogged)) {
                    ActivityPubMarkupTextSimple(content: "Boosted by \(relatedAccount.displayName) (@\(relatedAccount.acct))", emojos: relatedAccount.emojis)
                        .equatable()
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
            PostItem(status: reblog, relatedAccount: status.account, flags: flags.union(.reblogged), expandButtonHandler: expandButtonHandler)
        } else {
            HStack(alignment: .top, spacing: 0) {
                HStack(spacing: 0) {
                    ProfileImageStack(
                        primary: status.account.avatar,
                        secondary: relatedAccount?.avatar
                    )
                }
                    .padding(.trailing, 12)
                    .fixedSize()
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline) {
                        ActivityPubMarkupTextSimple(content: "\(status.account.displayName) (@\(status.account.acct))",
                                              emojos: status.account.emojis)
                            .equatable()
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
                        if status.visibility == .direct {
                            Text("✉️").lineSpacing(1)
                        }
                    }
                    .lineLimit(1)
                    ActivityPubMarkupText(element: status.parsedContent, emojos: status.emojis)
                        .equatable()
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
            .if(status.deleted) {
                $0.strikethrough()
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
            lhs.status.deleted == rhs.status.deleted &&
            lhs.status.account.avatar == rhs.status.account.avatar &&
            lhs.relatedAccount?.avatar == rhs.relatedAccount?.avatar &&
            lhs.flags == rhs.flags
        )
    }
}

/// 첨부된 이미지 썸네일을 가로로 나열합니다.
struct AttachmentRow: View {
    var attachments: [AttachmentAdaptor]

    var body: some View {
        HStack {
            ForEach(attachments, id: \.id) { attachment in
                if attachment.type == "image" {
                    AttachmentThumbnail(attachment: attachment)
                }
            }
        }
    }
}

/// 개별 첨부 이미지 썸네일. 로딩/캐싱은 `RemoteImage`에 위임하며,
/// preview_url이 없거나 로딩 중일 때는 중립 placeholder를 표시합니다.
private struct AttachmentThumbnail: View {
    @Environment(\.openURL)
    var openURL

    var attachment: AttachmentAdaptor

    var body: some View {
        RemoteImage(url: attachment.previewUrl ?? "") { image in
            image
                .resizable()
                .scaledToFill()
                .aspectRatio(contentMode: .fit)
                .frame(width: 64, height: 64)
                .clipped()
                .contentShape(Rectangle())
        } placeholder: {
            Rectangle()
                .fill(Color(uiColor: .systemGray5))
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
    let status = PreviewSamples.status

    VStack(spacing: 0) {
        PostItem(status: status)
        PostItem(status: PreviewSamples.reblogStatus)
        PostItem(status: status, relatedAccount: status.account, flags: .favouritedByOthers)
    }
}


