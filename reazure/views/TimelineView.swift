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
    var focusedId: String?
    
    var body: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(sharedClient.timeline[type]!) { status in
                    Button {
                        sharedClient.focusState[type] = status.id
                    } label: {
                        PostItem(status: status, selfId: sharedClient.account?.id ?? "")
                            .equatable()
                        // .focusable()
                        // .focused(sharedClient.focusState[type], equals: status.id)
                            .background {
                                if sharedClient.focusState[type] == status.id {
                                    Color(uiColor: UIColor(r8: 66, g8: 203, b8: 245, a: 0.2))
                                } else {
                                    Color.clear
                                }
                            }
                    }
                    .id(status.id)
                    .focusable(interactions: [.activate, .edit])
                    .focused($focusedId, equals: status.id)
                    .buttonStyle(NoButtonStyle())
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowSeparator(.hidden)
                    
                    .onKeyPress(.downArrow) {
                        sharedClient.handleShortcut(key: .j)
                        return .handled
                    }
                    .onKeyPress(.upArrow) {
                        sharedClient.handleShortcut(key: .k)
                        return .handled
                    }
                    .onKeyPress(.init("j")) {
                        sharedClient.handleShortcut(key: .j)
                        return .handled
                    }
                    .onKeyPress(.init("k")) {
                        sharedClient.handleShortcut(key: .k)
                        return .handled
                    }
                    .onKeyPress(.init("r")) {
                        sharedClient.handleShortcut(key: .r)
                        return .handled
                    }
                    .onKeyPress(.init("f")) {
                        sharedClient.handleShortcut(key: .f)
                        return .handled
                    }
                    .onKeyPress(.init("t")) {
                        sharedClient.handleShortcut(key: .t)
                        return .handled
                    }
                    .onKeyPress(.init("v")) {
                        sharedClient.handleShortcut(key: .v)
                        return .handled
                    }
                    .onKeyPress(.init("u")) {
                        sharedClient.handleShortcut(key: .u)
                        return .handled
                    }
                    .onKeyPress(.init("ㅕ")) {
                        sharedClient.handleShortcut(key: .u)
                        return .handled
                    }
                    
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
            .onChange(of: sharedClient.focusState[type]) { _ in
                print("test")
                focusedId = sharedClient.focusState[type]
                // withAnimation {
                    proxy.scrollTo(sharedClient.focusState[type])
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

