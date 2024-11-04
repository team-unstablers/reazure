//
//  AddAccountView.swift
//  reazure
//
//  Created by cheesekun on 11/3/24.
//

import SwiftUI

fileprivate enum AddAccountPhase {
    case beforeAuthorize
    case afterAuthorize
}

fileprivate class AddAccountViewModel: ObservableObject {
    @Environment(\.openURL)
    var openURL
    
    var accountManager: AccountManager!
    
    @Published
    var phase: AddAccountPhase = .beforeAuthorize
    
    @Published
    var serverAddress: String = ""
    
    @Published
    var manualClientID: Bool = false
    
    @Published
    var clientID: String = ""
    
    @Published
    var clientSecret: String = ""
    
    @Published
    var oauthCode: String = ""

    @Published
    var isBusy = false
    
    @Published
    var error: Error?
    
    var validated: Bool {
        !serverAddress.isEmpty &&
        ((manualClientID && (!clientID.isEmpty && !clientSecret.isEmpty)) || !manualClientID)
    }
    
    private var application: OAuthApplication? = nil
    
    func setup(accountManager: AccountManager) {
        self.accountManager = accountManager
    }
    
    func performAddAccount() {
        isBusy = true
        
        Task {
            do {
                try await sanityCheck()
                
                let application = try await createApplication()
                self.application = application
                
                var authorizeURL = MastodonEndpoint.oauthAuthorize.url(for: serverAddress)
                
                authorizeURL.append(queryItems: [
                    URLQueryItem(name: "client_id", value: application.client_id),
                    URLQueryItem(name: "response_type", value: "code"),
                    URLQueryItem(name: "redirect_uri", value: "urn:ietf:wg:oauth:2.0:oob"),
                    URLQueryItem(name: "scope", value: application.scopes.joined(separator: " "))
                ])
                
                await openURL(authorizeURL)
                
                DispatchQueue.main.async {
                    self.phase = .afterAuthorize
                    self.isBusy = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.error = error
                    self.isBusy = false
                }
            }
        }
    }
    
    func finalizeAddAccount() {
        guard let application = self.application else {
            return
        }
        
        isBusy = true
        
        Task {
            do {
                let token = try await MastodonClient.obtainOAuthToken(
                    from: serverAddress,
                    application: application,
                    code: oauthCode
                )
                
                var account = Account(
                    id: "unknown",
                    username: "unknown",
                    server: .mastodon(address: serverAddress),
                    accessToken: token.access_token
                )
                
                let client = MastodonClient(using: account)
                let profile = try await client.verifyCredentials()
                
                account.id = profile.id
                account.username = profile.username
                
                DispatchQueue.main.async {
                    self.accountManager.add(account)
                    self.isBusy = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.error = error
                    self.isBusy = false
                    
                    self.phase = .beforeAuthorize
                }
            }
        }
    }
    
    func sanityCheck() async throws {
        guard let nodeInfo = try await MastodonClient.nodeInfo(of: serverAddress) else {
            throw URLError(.badServerResponse)
        }
        
        if nodeInfo.software.name != "mastodon" {
            throw URLError(.badServerResponse)
        }
    }
    
    func createApplication() async throws -> OAuthApplication {
        if manualClientID {
            return OAuthApplication(
                id: "unknown",
                name: "unknown",
                website: "unknown",
                scopes: ["profile", "read", "write"],
                client_id: clientID,
                client_secret: clientSecret
            )
        }
        
        return try await MastodonClient.createClient(at: serverAddress)
    }
    
}


struct AddAccountView: View {
    @EnvironmentObject
    var accountManager: AccountManager

    @StateObject
    private var viewModel = AddAccountViewModel()
    
    var body: some View {
        Form {
            Section {
                TextField("서버 주소 (예: mastodon.online)", text: $viewModel.serverAddress)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .fontDesign(.monospaced)
                    .disabled(viewModel.isBusy || viewModel.phase == .afterAuthorize)
                
                HStack {
                    Button("OAuth 인증 시작") {
                        viewModel.performAddAccount()
                    }
                    .disabled(!viewModel.validated || viewModel.isBusy || viewModel.phase == .afterAuthorize)
                    
                    if viewModel.isBusy {
                        Spacer()
                        ProgressView()
                    }
                }
                
            } header: {
                Text("Fediverse 서버 정보")
            } footer: {
                VStack {
                    if let error = viewModel.error {
                        Text("오류: \(error.localizedDescription)")
                            .foregroundColor(.red)
                    } else {
                        Text("reazure는 현재 Mastodon v4 계열 서버만 지원합니다. Mastodon 계정을 가지고 있지 않은 경우, https://joinmastodon.org 에서 새 계정을 생성할 수 있습니다.")
                    }
                    
                }
                
            }
            if viewModel.phase == .afterAuthorize {
                Section {
                    TextField("인증 코드", text: $viewModel.oauthCode)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .fontDesign(.monospaced)
                        .disabled(viewModel.isBusy)
                    
                    HStack {
                        Button("OAuth 인증 끝마치기") {
                            viewModel.finalizeAddAccount()
                        }
                        .disabled(!viewModel.validated || viewModel.isBusy)
                        
                        if viewModel.isBusy {
                            Spacer()
                            ProgressView()
                        }
                    }
                } header: {
                    Text("OAuth 인증 코드 입력")
                } footer: {
                    Text("인증 화면에 표시된 인증 코드를 입력해주세요.")
                }
            }
            
            Section {
                Toggle("클라이언트 ID를 수동으로 지정", isOn: $viewModel.manualClientID)
                    .disabled(viewModel.isBusy)
                
                if viewModel.manualClientID {
                    TextField("클라이언트 ID", text: $viewModel.clientID)
                        .fontDesign(.monospaced)
                        .autocapitalization(.none)
                        .disabled(viewModel.isBusy)
                    
                    TextField("클라이언트 시크릿", text: $viewModel.clientSecret)
                        .fontDesign(.monospaced)
                        .autocapitalization(.none)
                        .disabled(viewModel.isBusy)
                }
            } header: {
                Text("고급 설정")
            } footer: {
                VStack {
                    Text(
"""
필요한 경우 클라이언트 ID를 수동으로 지정할 수 있습니다. via芸 등을 해야 할 때 유용합니다.

참고 사항:
- profile, read, write에 대한 OAuth scope가 필요합니다.

"""
                    )
                }
            }
            .navigationTitle("새 계정 추가")
        }
        .onAppear {
            viewModel.setup(accountManager: accountManager)
        }
    }
}

#Preview {
    AddAccountView()
}
