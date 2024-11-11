//
//  PostArea.swift
//  reazure
//
//  Created by cheesekun on 11/5/24.
//

import SwiftUI

struct PostRequest: Codable {
    var content: String
    var visibility: Visibility
    
    var replyTo: String?
}

typealias PostSubmitHandler = (PostRequest) -> Void

struct PostArea: View {
    @EnvironmentObject
    var sharedClient: SharedClient
    
    var handler: PostSubmitHandler
    
    @State
    var visibility: Visibility = .publicType
    
    @State
    var content: String = ""
    
    @State
    var replyTo: String? = nil
    
    @State
    var visibilityMenuVisible: Bool = false
    
    @FocusState
    var isFocused: Bool
    
    var remaining: Int {
        // FIXME: 인스턴스마다 이 제한은 다름
        500 - content.count
    }
    
    
    var background: Color {
        if remaining < 0 {
            return .init(uiColor: UIColor(r8: 245, g8: 81, b8: 66, a: 0.2))
        }
        
        if replyTo != nil {
            return .init(uiColor: UIColor(r8: 135, g8: 245, b8: 66, a: 0.2))
        }
        
        return .white
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("Left: \(remaining)")
                Text(visibility.asLocalizedText)
                    .overlay {
                        if visibilityMenuVisible {
                            GeometryReader { geom in
                                ContextMenu {
                                    Group {
                                        Text("POST_VISIBILITY_PUBLIC")
                                            .onTapGesture {
                                                visibility = .publicType
                                                visibilityMenuVisible.toggle()
                                            }
                                        Text("POST_VISIBILITY_UNLISTED")
                                            .onTapGesture {
                                                visibility = .unlisted
                                                visibilityMenuVisible.toggle()
                                            }
                                        Text("POST_VISIBILITY_PRIVATE")
                                            .onTapGesture {
                                                visibility = .privateType
                                                visibilityMenuVisible.toggle()
                                            }
                                        Text("POST_VISIBILITY_DIRECT")
                                            .onTapGesture {
                                                visibility = .direct
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
                Text(sharedClient.streamingState.asLocalizedText)
            }
            .padding(.horizontal, 4)
            .zIndex(100)
            TextField(text: $content) {}
                .focused($isFocused)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(background)
                .border(.black, width: 1)
                .onSubmit {
                    let request = PostRequest(content: content, visibility: visibility, replyTo: replyTo)
                    
                    content = ""
                    replyTo = nil
                    
                    handler(request)
                    
                    isFocused = true
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
            
            replyTo = status.id
            content = "@\(status.account.acct) "
            
            isFocused = true
        }
        .onChange(of: content) { content in
            if (content.isEmpty) {
                replyTo = nil
            }
        }
        .onChange(of: sharedClient.postAreaFocused) { focused in
            self.isFocused = focused
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

fileprivate extension Visibility {
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

#Preview {
    PostArea { request in
        
    }.environmentObject(SharedClient())
}
