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

    @Environment(\.appFontMetrics)
    var appFontMetrics: AppFontMetrics

    var status: StatusAdaptor
    
    var relatedAccount: AccountAdaptor? = nil
    var flags: PostItemFlags = []
    // var type: PostItemType = .normal
    
    var expandButtonHandler: (StatusAdaptor) -> Void = { _ in }

    /// 열람 경고(CW)가 걸린 본문의 펼침 여부. 어댑터를 마스킹하지 않고 뷰 로컬
    /// 상태로 두어, 스트리밍 갱신이 행을 다시 그려도 사용자의 선택이 유지되도록 한다.
    @State
    private var contentRevealed: Bool = false

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
    
    /// 본문. 열람 경고가 있는 경우 경고 문구만 노출하고, 사용자가 명시적으로
    /// 펼치기 전까지 본문을 감춘다.
    @ViewBuilder
    var contentBody: some View {
        if let spoilerText = status.spoilerText {
            ContentWarningBanner(spoilerText: spoilerText, revealed: contentRevealed) {
                contentRevealed.toggle()
            }

            if contentRevealed {
                ActivityPubMarkupText(element: status.parsedContent, emojos: status.emojis)
                    .equatable()
                    .foregroundColor(textColor)
            }
        } else {
            ActivityPubMarkupText(element: status.parsedContent, emojos: status.emojis)
                .equatable()
                .foregroundColor(textColor)
        }
    }

    var attachment: some View {
        Group {
            if !status.attachments.isEmpty {
                AttachmentRow(
                    attachments: status.attachments,
                    statusId: status.id,
                    sensitive: status.sensitive
                )
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

                    self.contentBody

                    self.attachment
                    
                    HStack(alignment: .firstTextBaseline) {
                        Text(verbatim: status.footerContent)
                            .font(appFontMetrics.body)
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
            // 차단된 사용자의 포스트: 서버는 더 이상 내려주지 않지만, 이미 화면에
            // 올라온 행은 남으므로 흐리게 처리한다.
            .if(status.blocked) {
                $0.strikethrough().opacity(0.35)
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
            lhs.status.blocked == rhs.status.blocked &&
            lhs.status.account.avatar == rhs.status.account.avatar &&
            lhs.relatedAccount?.avatar == rhs.relatedAccount?.avatar &&
            lhs.flags == rhs.flags
        )
    }
}

/// 열람 경고(CW) 문구와 본문 펼침/접기 토글을 겸하는 헤더입니다.
struct ContentWarningBanner: View {
    @Environment(\.appFontMetrics)
    var appFontMetrics: AppFontMetrics

    var spoilerText: String
    var revealed: Bool
    var toggleHandler: () -> Void

    var body: some View {
        Button(action: toggleHandler) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Image(systemName: revealed ? "eye.fill" : "eye.slash.fill")
                Text(verbatim: spoilerText)
                    .bold()
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                Text(revealed ? "ACTION_HIDE_CONTENT" : "ACTION_SHOW_CONTENT")
                    .underline()
            }
            .font(appFontMetrics.caption)
            .foregroundColor(.secondary)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// 첨부된 이미지 썸네일을 가로로 나열합니다.
struct AttachmentRow: View {
    @Environment(\.openWindow)
    private var openWindow

    var attachments: [AttachmentAdaptor]
    var statusId: String
    /// 민감한 콘텐츠로 표시된 첨부인지 여부. 참이면 사용자가 한 번 두드려
    /// 해제하기 전까지 썸네일을 흐리게 가리고 갤러리도 열지 않는다.
    var sensitive: Bool = false

    @State private var presentedGallery: AttachmentGalleryContext?
    @State private var mediaRevealed: Bool = false

    private var isObscured: Bool {
        sensitive && !mediaRevealed
    }

    var body: some View {
        HStack {
            ForEach(attachments, id: \.id) { attachment in
                if attachment.type == "image" {
                    AttachmentThumbnail(attachment: attachment, obscured: isObscured) {
                        if isObscured {
                            mediaRevealed = true
                        } else {
                            openGallery(tappedId: attachment.id)
                        }
                    }
                }
            }
        }
        .fullScreenCover(item: $presentedGallery) { context in
            AttachmentGalleryView(context: context)
        }
    }

    /// iPad/macOS에서는 별도 윈도우로, iPhone(멀티 씬 미지원)에서는
    /// `fullScreenCover`로 이미지 갤러리를 연다.
    private func openGallery(tappedId: String) {
        guard let context = AttachmentGalleryContext.make(
            statusId: statusId,
            attachments: attachments,
            tappedId: tappedId
        ) else {
            return
        }

        if UIApplication.shared.supportsMultipleScenes {
            openWindow(value: context)
        } else {
            presentedGallery = context
        }
    }
}

/// 개별 첨부 이미지 썸네일. 로딩/캐싱은 `RemoteImage`에 위임하며,
/// preview_url이 없거나 로딩 중일 때는 중립 placeholder를 표시합니다.
private struct AttachmentThumbnail: View {
    var attachment: AttachmentAdaptor
    /// 민감한 콘텐츠로 가려진 상태인지 여부.
    var obscured: Bool = false
    var onTap: () -> Void

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
        // blur는 뷰 경계 밖으로 번지므로, 흐리게 처리한 뒤 다시 잘라낸다.
        .blur(radius: obscured ? 16 : 0)
        .frame(width: 64, height: 64)
        .clipped()
        .overlay {
            if obscured {
                Image(systemName: "eye.slash.fill")
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
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

#if DEBUG
#Preview {
    let status = PreviewSamples.status

    VStack(spacing: 0) {
        PostItem(status: status)
        PostItem(status: PreviewSamples.reblogStatus)
        PostItem(status: status, relatedAccount: status.account, flags: .favouritedByOthers)
        PostItem(status: PreviewSamples.sensitiveStatus)
    }
}
#endif

