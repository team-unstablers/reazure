//
//  AboutAppView.swift
//  reazure
//
//  Created by cheesekun on 11/2/24.
//

import SwiftUI



struct AboutAppView: View {
    var addAccountHandler: () -> Void
    
    @EnvironmentObject
    var preferencesManager: PreferencesManager
    
    @EnvironmentObject
    var accountManager: AccountManager
    
    var body: some View {
        VStack {
            Form {
                AboutAppHeader()
                    .listRowInsets(EdgeInsets())
                
                Section("SETTINGS_CATEGORY_DEFAULT") {
                    Toggle(isOn: .constant(true)) {
                        Text("SETTINGS_KEY_PLAY_SOUND")
                    }
                    Toggle(isOn: .constant(true)) {
                        Text("SETTINGS_KEY_VIBRATE")
                    }
                }
                
                Section {
                    Toggle(isOn: $preferencesManager.showExtKeypad) {
                        Text("SETTINGS_KEY_SHOW_EXT_KEYPAD")
                    }
                } footer: {
                    Text("SETTINGS_FOOTER_SHOW_EXT_KEYPAD")
                }
                
                Section {
                    Toggle(isOn: $preferencesManager.alwaysShowSoftwareKeyboard) {
                        Text("SETTINGS_KEY_ALWAYS_SHOW_SOFT_KEYBOARD")
                    }
                } footer: {
                    Text("SETTINGS_FOOTER_ALWAYS_SHOW_SOFT_KEYBOARD")
                }
                
                
                ForEach(accountManager.accounts) { account in
                    Section(header: Text("\(account.username)@\(account.server.address)")) {
                        Button("ACTION_LOGOUT") {
                        }
                        .foregroundColor(.red)
                    }
                }
                
                Section {
                    Button("ACTION_ADD_ACCOUNT") {
                        addAccountHandler()
                    }
                }
                
                AboutAppFooter()
                    .listRowInsets(EdgeInsets())

                
                /*
                 Section {
                 
                 } footer: {
                 VStack {
                 Group {
                 Text("주식회사 팀언스테이블러즈 개발")
                 Text("이 소프트웨어는 Twitter 클라이언트 〈[Azurea](https://azurea.info)〉로부터 영감을 받음.")
                 }
                 .font(.caption)
                 }
                 }
                 */
            }
        }
    }
}

#Preview {
    AboutAppView(addAccountHandler: {})
        .environmentObject(AccountManager())
        .environmentObject(PreferencesManager())
}
