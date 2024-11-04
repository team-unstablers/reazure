//
//  Untitled.swift
//  reazure
//
//  Created by cheesekun on 11/3/24.
//

import SwiftUI

extension View {
    func watchAccountManager(_ addAccountHandler: @escaping () -> Void) -> some View {
        return self.modifier(WatchAccountManager(addAccountHandler: addAccountHandler))
    }
}

struct WatchAccountManager: ViewModifier {
    @EnvironmentObject
    var accountManager: AccountManager
    
    @EnvironmentObject
    var sharedClient: SharedClient

    var addAccountHandler: () -> Void
    
    @State
    private var showAlert = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                accountManager.refresh()
                if accountManager.isEmpty {
                    showAlert = true
                } else {
                    sharedClient.account = accountManager.accounts.first!
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Fediverse 계정 없음"),
                    message: Text("새 Fediverse 계정을 추가합니까?"),
                    primaryButton: .default(Text("예")) {
                        addAccountHandler()
                    },
                    secondaryButton: .cancel()
                )
            }
    }
}
