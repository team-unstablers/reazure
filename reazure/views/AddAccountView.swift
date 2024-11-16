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
    
    private var application: Mastodon.OAuthApplication? = nil
    
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
    
    func createApplication() async throws -> Mastodon.OAuthApplication {
        if manualClientID {
            return Mastodon.OAuthApplication(
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
                TextField("ADD_ACCOUNT_SERVER_ADDRESS", text: $viewModel.serverAddress)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .fontDesign(.monospaced)
                    .disabled(viewModel.isBusy || viewModel.phase == .afterAuthorize)
                
                HStack {
                    Button("ACTION_START_OAUTH") {
                        viewModel.performAddAccount()
                    }
                    .disabled(!viewModel.validated || viewModel.isBusy || viewModel.phase == .afterAuthorize)
                    
                    if viewModel.isBusy {
                        Spacer()
                        ProgressView()
                    }
                }
                
            } header: {
                Text("ADD_ACCOUNT_HEADER_SERVER_INFO")
            } footer: {
                VStack {
                    if let error = viewModel.error {
                        Text("ERROR: \(error.localizedDescription)")
                            .foregroundColor(.red)
                    } else {
                        Text("ADD_ACCOUNT_FOOTER_NOTICE")
                    }
                    
                }
                
            }
            if viewModel.phase == .afterAuthorize {
                Section {
                    TextField("ADD_ACCOUNT_OAUTH_CODE", text: $viewModel.oauthCode)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .fontDesign(.monospaced)
                        .disabled(viewModel.isBusy)
                    
                    HStack {
                        Button("ACTION_FINISH_OAUTH") {
                            viewModel.finalizeAddAccount()
                        }
                        .disabled(!viewModel.validated || viewModel.isBusy)
                        
                        if viewModel.isBusy {
                            Spacer()
                            ProgressView()
                        }
                    }
                } header: {
                    Text("ADD_ACCOUNT_HEADER_OAUTH_CODE")
                } footer: {
                    Text("ADD_ACCOUNT_FOOTER_OAUTH_CODE")
                }
            }
            
            Section {
                Toggle("ADD_ACCOUNT_EXTRA_MANUAL_CLIENT_ID", isOn: $viewModel.manualClientID)
                    .disabled(viewModel.isBusy)
                
                if viewModel.manualClientID {
                    TextField("ADD_ACCOUNT_CLIENT_ID", text: $viewModel.clientID)
                        .fontDesign(.monospaced)
                        .autocapitalization(.none)
                        .disabled(viewModel.isBusy)
                    
                    TextField("ADD_ACCOUNT_CLIENT_SECRET", text: $viewModel.clientSecret)
                        .fontDesign(.monospaced)
                        .autocapitalization(.none)
                        .disabled(viewModel.isBusy)
                }
            } header: {
                Text("ADD_ACCOUNT_HEADER_EXTRA_SETTINGS")
            } footer: {
                VStack {
                    Text("ADD_ACCOUNT_FOOTER_EXTRA_SETTINGS")
                }
            }
            
            AboutAppFooter()
                .listRowInsets(EdgeInsets())
        }
        .navigationTitle("ADD_ACCOUNT_NAVIGATION_TITLE")
        .onAppear {
            viewModel.setup(accountManager: accountManager)
        }
    }
}

#Preview {
    AddAccountView()
}
