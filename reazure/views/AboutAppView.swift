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
    var accountManager: AccountManager
    
    var body: some View {
        VStack {
            VStack {
                Text("reazure")
                    .font(.largeTitle)
                Text("version 1")
                    .padding(.bottom, 8)
                
                Text("이제 [새로운 집](https://joinmastodon.org)을 찾아 떠나자.")
            }
            .frame(minHeight: 192)
            
            Form {
                Section("기본 설정") {
                    Toggle(isOn: .constant(true)) {
                        Text("알림 수신 시 소리 재생")
                    }
                    Toggle(isOn: .constant(true)) {
                        Text("알림 수신 시 진동")
                    }
                }
                
                Section {
                    Toggle(isOn: .constant(false)) {
                        Text("확장 키보드 표시")
                    }
                } footer: {
                    Text("Azurea-like한 단축키를 사용할 수 있도록 확장 키보드를 표시합니다.")
                }
                
                Section {
                    Toggle(isOn: .constant(false)) {
                        Text("항상 소프트웨어 키보드 표시")
                    }
                } footer: {
                    Text("물리 자판이 탑재된 스마트폰과 유사한 경험을 할 수 있도록 앱 내에서 항상 소프트웨어 키보드를 표시합니다.")
                }
                
                
                ForEach(accountManager.accounts) { account in
                    Section(header: Text("\(account.username)@\(account.server.address)")) {
                        Button("로그아웃") {
                        }
                        .foregroundColor(.red)
                    }
                }
                
                Section {
                    Button("새 계정 추가하기") {
                        addAccountHandler()
                    }
                }
                
                
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
}
