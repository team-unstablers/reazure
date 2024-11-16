//
//  TimelineView.swift
//  reazure
//
//  Created by cheesekun on 11/2/24.
//

import SwiftUI

struct NoButtonStyle: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        return configuration.label
    }
}


struct TimelineView: View {
    var type: TimelineType
    
    @EnvironmentObject
    var sharedClient: SharedClient
    
    @FocusState
    var focusState: TLFocusState?
    
    /*
    @FocusState
    var focusedId: String?
     */
    
    var body: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(sharedClient.timeline[type]!) { model in
                    PostGroup(model: model, type: type, focusState: $focusState)
                }
            }
            .listStyle(.plain)
            .listRowSpacing(0)
            .padding(0)
            .overlay {
                /*
                if let status = sharedClient.focusedStatus(for: .home) {
                    GeometryReader { geom in
                        ContextMenu {
                            Group {
                                ActivityPubMarkupText(content: "\(status.account.display_name) (@\(status.account.acct))",
                                                      emojos: status.account.emojis)
                                    .bold()
                                    .lineLimit(1)
                                Divider()
                                HStack {
                                    Text("답글 달기")
                                    Spacer()
                                    Text("부스트")
                                    Spacer()
                                    Text("페이버릿")
                                    Spacer()
                                    Text("스레드 불러오기")
                                }
                                Divider()
                                Text(status.url ?? "(nil)")
                                    .lineLimit(1)
                                HStack {
                                    Text("URL 복사")
                                    Spacer()
                                    Text("브라우저에서 열기")
                                }
                                Divider()
                                Text("삭제")
                                    .foregroundStyle(.gray)
                            }
                        }
                        .fixedSize()
                        .offset(x: 16, y: 16)
                    }
                    .allowsHitTesting(true)
                }
                 */
            }
            .onChange(of: sharedClient.focusState[type]) { value in
                // proxy.scrollTo가 먼저 실행되어야 함: 왜냐하면 focusedId가 현재 표시 바깥에 있으면 포커스 안됨 / 숏컷 핸들러 안 먹게 됨
                guard let focusState = sharedClient.focusState[type] else {
                    return
                }
                proxy.scrollTo(focusState)
                
                DispatchQueue.main.async {
                    self.focusState = focusState
                }
                
                // withAnimation {
                // }
            }
        }
        .onAppear {
            Task {
                await sharedClient.fetchStatuses(for: type)
            }
        }
    }
}

