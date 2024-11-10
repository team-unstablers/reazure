//
//  PostArea.swift
//  reazure
//
//  Created by cheesekun on 11/5/24.
//

import SwiftUI

struct PostRequest: Codable {
    var content: String
    
    var replyTo: String?
}

typealias PostSubmitHandler = (PostRequest) -> Void

struct PostArea: View {
    @EnvironmentObject
    var sharedClient: SharedClient
    
    var handler: PostSubmitHandler
    
    @State
    var content: String = ""
    
    @State
    var replyTo: String? = nil
    
    
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
                Text("\(remaining)")
                Spacer()
                Text(sharedClient.streamingState.asLocalizedText)
            }
                .padding(.horizontal, 4)
            TextField(text: $content) {}
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(background)
                .border(.black, width: 1)
                .onSubmit {
                    let request = PostRequest(content: content, replyTo: replyTo)
                    
                    content = ""
                    replyTo = nil

                    handler(request)
                }
        }
        .background(AzureaTheme.win32Background)
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

#Preview {
    PostArea { request in
        
    }
}
