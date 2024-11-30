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
    
    var canonical: StatusAdaptor {
        self.status.canonical
    }
    
    var isOwnStatus: Bool {
        canonical.account.id == sharedClient.account?.id
    }
    
    var body: some View {
        Group {
            ActivityPubMarkupText(content: "\(canonical.account.displayName) (@\(canonical.account.acct))",
                                  emojos: canonical.account.emojis)
            
            Divider()
            
            Button("CONTEXT_MENU_REPLY") {}
            Button(canonical.reblogged ? "CONTEXT_MENU_UNREBLOG" : "CONTEXT_MENU_REBLOG") {
                
            }
                .disabled(!canonical.visibility.isRebloggable)
            Button(canonical.favourited ? "CONTEXT_MENU_UNFAVOURITE" : "CONTEXT_MENU_FAVOURITE") {
                
            }
            
            if let urlString = canonical.url,
               let url = URL(string: urlString) {
                
                Divider()
                
                Text(urlString)
                
                Divider()
                
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
