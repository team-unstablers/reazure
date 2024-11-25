//
//  NativePostContextMenu.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/25/24.
//

import SwiftUI

struct NativePostContextMenuInner: View {
    @EnvironmentObject
    var sharedClient: SharedClient
    
    @Environment(\.openURL)
    var openURL
    
    let status: StatusAdaptor
    
    var isOwnStatus: Bool {
        status.account.id == sharedClient.account?.id
    }
    
    var body: some View {
        Group {
            ActivityPubMarkupText(content: "\(status.account.displayName) (@\(status.account.acct))",
                                  emojos: status.account.emojis)
            
            Divider()
            
            Button("CONTEXT_MENU_REPLY") {}
            Button(status.reblogged ? "CONTEXT_MENU_UNREBLOG" : "CONTEXT_MENU_REBLOG") {
            }
                .disabled(!status.visibility.isRebloggable)
            Button(status.favourited ? "CONTEXT_MENU_UNFAVOURITE" : "CONTEXT_MENU_FAVOURITE") {
                
            }
            
            if let urlString = status.url,
               let url = URL(string: urlString) {
                
                Divider()
                
                Text(urlString)
                
                Button("CONTEXT_MENU_COPY_URL") {
                    UIPasteboard.general.string = urlString
                }
                
                Button("CONTEXT_MENU_SHARE") {
                    let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                    UIApplication.shared.windows.first?.rootViewController?.present(activityVC, animated: true, completion: nil)
                }
                
                Button("CONTEXT_MENU_OPEN_IN_BROWSER") {
                    openURL(url)
                }
            }
            
            if isOwnStatus {
                Divider()
                
                Button("CONTEXT_MENU_DELETE", role: .destructive) {
                    // TODO
                }
            }
        }
    }
}
