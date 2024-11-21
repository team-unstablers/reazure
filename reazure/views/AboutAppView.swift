//
//  AboutAppView.swift
//  reazure
//
//  Created by cheesekun on 11/2/24.
//

import SwiftUI

fileprivate struct PreferenceSwitch<Content>: View where Content: View {
    @EnvironmentObject
    var preferencesManager: PreferencesManager
    
    @Binding
    var isOn: Bool
    var content: () -> Content

    var body: some View {
        Toggle(isOn: $isOn) {
            content()
        }
            .onChange(of: isOn) { newValue in
                preferencesManager.save()
            }
    }
}



struct AboutAppView: View {
    var addAccountHandler: () -> Void
    
    @EnvironmentObject
    var sharedClient: SharedClient

    @EnvironmentObject
    var preferencesManager: PreferencesManager
    
    @EnvironmentObject
    var accountManager: AccountManager
    
    var body: some View {
        VStack {
            Form {
                AboutAppHeader()
                    .listRowInsets(EdgeInsets())
                
                Section(header: Text("SETTINGS_CATEGORY_DEFAULT"), footer: {
                    let notificationSound = preferencesManager.notificationSound
                    if notificationSound != .default {
                        return (
                            Text("\(notificationSound.localizedDescription) - \(notificationSound.description)") + Text("\n") +
                            Text("SETTINGS_FOOTER_DEFAULT_SOUND_LICENSED_WITH: \(notificationSound.license)") + Text("\n") +
                            Text("©️ \(notificationSound.copyright)")
                        )
                    } else {
                        return Text("")
                    }
                }()) {
                    PreferenceSwitch(isOn: $preferencesManager.playSoundOnNotification) {
                        Text("SETTINGS_KEY_PLAY_SOUND")
                    }
                    
                    if preferencesManager.playSoundOnNotification {
                        Picker("SETTINGS_KEY_SOUND_NAME", selection: $preferencesManager.notificationSound) {
                            ForEach(NotificationSound.allCases) { sound in
                                Text(sound.localizedDescription)
                                    .tag(sound)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .onChange(of: preferencesManager.notificationSound) { newValue in
                            newValue.play()
                            preferencesManager.save()
                        }
                    }
                    
                    PreferenceSwitch(isOn: $preferencesManager.vibrateOnNotification) {
                        Text("SETTINGS_KEY_VIBRATE")
                    }
                        .disabled(preferencesManager.playSoundOnNotification)
                    
                    PreferenceSwitch(isOn: $preferencesManager.liftDownPostArea) {
                        Text("SETTINGS_KEY_LIFT_DOWN_POST_AREA")
                    }
                }
                
                Section {
                    PreferenceSwitch(isOn: $preferencesManager.compactMode) {
                        Text("SETTINGS_KEY_COMPACT_MODE")
                    }
                } footer: {
                    Text("SETTINGS_FOOTER_COMPACT_MODE")
                }
                
                Section {
                    PreferenceSwitch(isOn: $preferencesManager.showExtKeypad) {
                        Text("SETTINGS_KEY_SHOW_EXT_KEYPAD")
                    }
                    if preferencesManager.showExtKeypad {
                        PreferenceSwitch(isOn: $preferencesManager.swapJKOnExtKeypad) {
                            Text("SETTINGS_KEY_SWAP_JK_ON_EXT_KEYPAD")
                        }
                    }
                } footer: {
                    Text("SETTINGS_FOOTER_SHOW_EXT_KEYPAD")
                }
                
                Section {
                    PreferenceSwitch(isOn: .constant(false)) {
                        Text("SETTINGS_KEY_ALWAYS_SHOW_SOFT_KEYBOARD")
                    }
                } footer: {
                    Text("SETTINGS_FOOTER_ALWAYS_SHOW_SOFT_KEYBOARD")
                }
                
                
                ForEach(accountManager.accounts) { account in
                    Section(header: Text("\(account.username)@\(account.server.address)")) {
                        Button("ACTION_LOGOUT") {
                            accountManager.remove(account)
                            sharedClient.account = nil
                        }
                        .foregroundColor(.red)
                    }
                }
                
                if accountManager.isEmpty {
                    Section {
                        Button("ACTION_ADD_ACCOUNT") {
                            addAccountHandler()
                        }
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
        .environmentObject(SharedClient())
        .environmentObject(AccountManager())
        .environmentObject(PreferencesManager())
}
