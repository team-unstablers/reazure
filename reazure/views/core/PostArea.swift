//
//  PostArea.swift
//  reazure
//
//  Created by cheesekun on 11/5/24.
//

import SwiftUI

fileprivate let FEEDBACK_FORM_URL = "https://docs.google.com/forms/d/e/1FAIpQLSfIKbkLUpy9oPXUlBgNQrCLc09C1vb6Eim69zOvVXtHYkS1NQ/viewform?usp=sf_link"

struct PostRequest: Codable {
    var content: String
    var visibility: Mastodon.Visibility
    
    var replyTo: String?
}

typealias PostSubmitHandler = (PostRequest) -> Void

struct PostArea: View {
    @Environment(\.openURL)
    var openURL
    
    @EnvironmentObject
    var sharedClient: SharedClient
    
    
    @State
    var visibility: Mastodon.Visibility = .publicType
    
    @State
    var content: String = ""
    
    @State
    var replyTo: StatusAdaptor? = nil {
        didSet {
            if let replyTo = replyTo {
                visibilityMask = replyTo.visibility.__DONOTUSE__asMastodonVisibility()
            } else {
                visibilityMask = nil
            }
        }
    }

    @State
    var visibilityMask: Mastodon.Visibility? = nil

    @State
    var visibilityMenuVisible: Bool = false
    
    @FocusState
    var isFocused: Bool
    
    var handler: PostSubmitHandler
    
    var maxPostLength: Int {
        sharedClient.configuration?.maxPostLength ?? 500
    }

    var remaining: Int {
        maxPostLength - content.count
    }
    
    
    var background: Color {
        if remaining < 0 {
            return .init(uiColor: UIColor(r8: 245, g8: 81, b8: 66, a: 0.2))
        }
        
        /*
        if replyTo != nil {
            return .init(uiColor: UIColor(r8: 135, g8: 245, b8: 66, a: 0.2))
        }
         */
        
        return .white
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("Left: \(remaining)")
                Text((visibilityMask ?? visibility).asLocalizedText)
                    .overlay {
                        if visibilityMenuVisible {
                            GeometryReader { geom in
                                ContextMenu {
                                    Group {
                                        Text("POST_VISIBILITY_PUBLIC")
                                            .onTapGesture {
                                                if visibilityMask != nil {
                                                    visibilityMask = .publicType
                                                } else {
                                                    visibility = .publicType
                                                }
                                                visibilityMenuVisible.toggle()
                                            }
                                        Text("POST_VISIBILITY_UNLISTED")
                                            .onTapGesture {
                                                if visibilityMask != nil {
                                                    visibilityMask = .unlisted
                                                } else {
                                                    visibility = .unlisted
                                                }
                                                visibilityMenuVisible.toggle()
                                            }
                                        Text("POST_VISIBILITY_PRIVATE")
                                            .onTapGesture {
                                                if visibilityMask != nil {
                                                    visibilityMask = .privateType
                                                } else {
                                                    visibility = .privateType
                                                }
                                                visibilityMenuVisible.toggle()
                                            }
                                        Text("POST_VISIBILITY_DIRECT")
                                            .onTapGesture {
                                                if visibilityMask != nil {
                                                    visibilityMask = .direct
                                                } else {
                                                    visibility = .direct
                                                }
                                                visibilityMenuVisible.toggle()
                                            }
                                    }
                                }
                                .fixedSize()
                                .offset(x: 0, y: geom.size.height)
                                .zIndex(100)
                            }
                            .allowsHitTesting(true)
                            .zIndex(100)
                        }
                    }
                    .onTapGesture {
                        visibilityMenuVisible.toggle()
                    }
                Spacer()
                Text("SEND_FEEDBACK")
                    .onTapGesture {
                        openURL(URL(string: FEEDBACK_FORM_URL)!)
                    }
                Text(sharedClient.streamingState.asLocalizedText)
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 4)
            .zIndex(100)
            
            VStack(spacing: 0) {
                if let replyTo = replyTo {
                    CompactPostItem(status: replyTo)
                }
                
                TextField(text: $content) {}
                    .foregroundStyle(.black)
                    // .focusable(false)
                    .focused($isFocused)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(background)
                    .border(.black, width: 1)
                    .onSubmit {
                        let request = PostRequest(content: content, visibility: visibilityMask ?? visibility, replyTo: replyTo?.id)
                        
                        content = ""
                        replyTo = nil
                        
                        handler(request)
                        
                        isFocused = true
                    }
                    .onKeyPress(.downArrow) {
                        DispatchQueue.main.async {
                            isFocused = false
                        }

                        return .handled
                    }
            }
        }
        .background(AzureaTheme.win32Background)
        .onAppear {
            isFocused = false
        }
        .onReceive(sharedClient.replyTo) { status in
            guard let status = status else {
                return
            }
            
            replyTo = status
            content = status.buildMentionString(me: sharedClient.account!)
            
            DispatchQueue.main.async {
                isFocused = true
            }
        }
        .onChange(of: content) { content in
            if (content.isEmpty) {
                replyTo = nil
            }
        }
        .onChange(of: isFocused) { focused in
            if (sharedClient.postAreaFocused != focused) {
                sharedClient.postAreaFocused = focused
            }
        }
        .onChange(of: sharedClient.postAreaFocused) { focused in
            if (self.isFocused != focused) {
                self.isFocused = focused
            }
        }
        
    }
}

fileprivate extension StatusAdaptor {
    func buildMentionString(me: Account) -> String {
        if (self.account.id == me.id) {
            return "@\(self.account.username) "
        } else {
            let mentions = ([self.account.acct] + self.mentions.filter { $0.id != me.id }.map { $0.acct }).map { "@" + $0 }.deduplicated()
            
            return mentions.joined(separator: " ") + " "
        }
    }
}

fileprivate extension StreamingState {
    var asLocalizedText: String {
        switch self {
        case .connecting:
            return NSLocalizedString("STREAMING_STATE_CONNECTING", comment: "")
        case .connected:
            return NSLocalizedString("STREAMING_STATE_CONNECTED", comment: "")
        case .disconnected:
            return NSLocalizedString("STREAMING_STATE_DISCONNECTED", comment: "")
        }
    }
}

fileprivate extension Mastodon.Visibility {
    var asLocalizedText: String {
        switch self {
        case .publicType:
            return NSLocalizedString("POST_VISIBILITY_PUBLIC", comment: "")
        case .unlisted:
            return NSLocalizedString("POST_VISIBILITY_UNLISTED", comment: "")
        case .privateType:
            return NSLocalizedString("POST_VISIBILITY_PRIVATE", comment: "")
        case .direct:
            return NSLocalizedString("POST_VISIBILITY_DIRECT", comment: "")
        default:
            return NSLocalizedString("POST_VISIBILITY_PUBLIC", comment: "")
        }
    }
}

fileprivate extension Array {
    func deduplicated() -> [Element] where Element: Hashable {
        var new = [Element]()
        
        for element in self {
            if !new.contains(element) {
                new.append(element)
            }
        }
        
        return new
    }
}

/*
#Preview {
    let status = Status(
        id: "1",
        created_at: "2019-11-26T23:27:32.000Z",
        url: "",
        visibility: "public",
        content: "Hello, World!",
        account: UserProfile(
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
            MediaAttachment(
                id: "1234",
                type: "image",
                url: "https://ppiy.ac/system/accounts/avatars/110/796/233/076/688/314/original/df6e9ebf6bb70ef2.jpg",
                preview_url: "https://ppiy.ac/system/accounts/avatars/110/796/233/076/688/314/original/df6e9ebf6bb70ef2.jpg",
                remote_url: "https://ppiy.ac/system/accounts/avatars/110/796/233/076/688/314/original/df6e9ebf6bb70ef2.jpg"
            ),
            MediaAttachment(
                id: "1235",
                type: "image",
                url: "https://ppiy.ac/system/accounts/avatars/110/796/233/076/688/314/original/df6e9ebf6bb70ef2.jpg",
                preview_url: "https://ppiy.ac/system/accounts/avatars/110/796/233/076/688/314/original/df6e9ebf6bb70ef2.jpg",
                remote_url: "https://ppiy.ac/system/accounts/avatars/110/796/233/076/688/314/original/df6e9ebf6bb70ef2.jpg"
            ),
            MediaAttachment(
                id: "1236",
                type: "image",
                url: "https://ppiy.ac/system/accounts/avatars/110/796/233/076/688/314/original/df6e9ebf6bb70ef2.jpg",
                preview_url: "https://ppiy.ac/system/accounts/avatars/110/796/233/076/688/314/original/df6e9ebf6bb70ef2.jpg",
                remote_url: "https://ppiy.ac/system/accounts/avatars/110/796/233/076/688/314/original/df6e9ebf6bb70ef2.jpg"
            ),
            MediaAttachment(
                id: "1237",
                type: "image",
                url: "https://ppiy.ac/system/accounts/avatars/110/796/233/076/688/314/original/df6e9ebf6bb70ef2.jpg",
                preview_url: "https://ppiy.ac/system/accounts/avatars/110/796/233/076/688/314/original/df6e9ebf6bb70ef2.jpg",
                remote_url: "https://ppiy.ac/system/accounts/avatars/110/796/233/076/688/314/original/df6e9ebf6bb70ef2.jpg"
            ),
        ],
        application: Application(name: "re;azure")
    )
    
    VStack {
        Text("without reply:")
        PostArea { request in
        }
        .environmentObject(SharedClient())
    }
    
    VStack {
        Text("with reply:")
        PostArea(replyTo: status) { request in
        }
        .environmentObject(SharedClient())
    }
}
*/
