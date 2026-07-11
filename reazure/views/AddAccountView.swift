//
//  AddAccountView.swift
//  reazure
//
//  Created by cheesekun on 11/3/24.
//

import SwiftUI
import UIKit
import AuthenticationServices

fileprivate class AddAccountViewModel: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    var accountManager: AccountManager!

    @Published
    var serverAddress: String = ""

    @Published
    var manualClientID: Bool = false

    @Published
    var clientID: String = ""

    @Published
    var clientSecret: String = ""

    @Published
    var isBusy = false

    @Published
    var error: Error?

    var validated: Bool {
        !serverAddress.isEmpty &&
        ((manualClientID && (!clientID.isEmpty && !clientSecret.isEmpty)) || !manualClientID)
    }

    private var application: Mastodon.OAuthApplication? = nil

    /// The in-flight authentication session. Held strongly so it is not torn down
    /// (and thus cancelled) before the user finishes authorizing.
    private var authSession: ASWebAuthenticationSession?

    /// Invoked after the account is successfully added; drives navigation back.
    private var completionHandler: (() -> Void)?

    func setup(accountManager: AccountManager) {
        self.accountManager = accountManager
    }

    func performAddAccount(completion: @escaping (() -> Void)) {
        self.completionHandler = completion
        isBusy = true

        Task {
            do {
                guard let nodeInfo = try await MastodonClient.nodeInfo(of: serverAddress) else {
                    throw FediverseAPIError.unsupportedServerSoftware
                }

                try await sanityCheck(using: nodeInfo)

                let application = try await createApplication()
                self.application = application

                var authorizeURL = MastodonEndpoint.oauthAuthorize.url(for: serverAddress)

                let scopes = application.scopes ?? MastodonClient.defaultScope(for: nodeInfo.software.version)

                authorizeURL.append(queryItems: [
                    URLQueryItem(name: "client_id", value: application.client_id),
                    URLQueryItem(name: "response_type", value: "code"),
                    URLQueryItem(name: "redirect_uri", value: MastodonClient.oauthRedirectURI),
                    URLQueryItem(name: "scope", value: scopes.joined(separator: " "))
                ])

                DispatchQueue.main.async {
                    self.startAuthSession(with: authorizeURL)
                }
            } catch {
                DispatchQueue.main.async {
                    self.error = error
                    self.isBusy = false
                }
            }
        }
    }

    /// Presents the in-app authentication browser. The custom callback scheme lets
    /// the session capture the authorization code directly, so no manual paste step
    /// is needed.
    private func startAuthSession(with url: URL) {
        let session = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: MastodonClient.oauthCallbackScheme
        ) { [weak self] callbackURL, error in
            self?.handleAuthCallback(callbackURL: callbackURL, error: error)
        }

        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = true

        self.authSession = session
        session.start()
    }

    private func handleAuthCallback(callbackURL: URL?, error: Error?) {
        self.authSession = nil

        if let error = error {
            // Treat an explicit user cancellation as a no-op rather than an error.
            if let authError = error as? ASWebAuthenticationSessionError,
               authError.code == .canceledLogin {
                self.isBusy = false
                return
            }

            self.error = error
            self.isBusy = false
            return
        }

        guard let callbackURL = callbackURL,
              let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "code" })?
                .value
        else {
            self.error = FediverseAPIError.unknownError(originError: nil)
            self.isBusy = false
            return
        }

        finalizeAddAccount(code: code)
    }

    private func finalizeAddAccount(code: String) {
        guard let application = self.application else {
            self.isBusy = false
            return
        }

        Task {
            do {
                let token = try await MastodonClient.obtainOAuthToken(
                    from: serverAddress,
                    application: application,
                    code: code
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

                    self.completionHandler?()
                }
            } catch {
                DispatchQueue.main.async {
                    self.error = error
                    self.isBusy = false
                }
            }
        }
    }

    func sanityCheck(using nodeInfo: Mastodon.NodeInfo) async throws {
        if nodeInfo.software.name != "mastodon" {
            throw FediverseAPIError.unsupportedServerSoftware
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

    // MARK: - ASWebAuthenticationPresentationContextProviding

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}


struct AddAccountView: View {
    @EnvironmentObject
    var accountManager: AccountManager

    @StateObject
    private var viewModel = AddAccountViewModel()

    var completionHandler: (() -> Void)?

    var body: some View {
        Form {
            Section {
                TextField("ADD_ACCOUNT_SERVER_ADDRESS", text: $viewModel.serverAddress)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .fontDesign(.monospaced)
                    .disabled(viewModel.isBusy)

                HStack {
                    Button("ACTION_START_OAUTH") {
                        viewModel.performAddAccount {
                            completionHandler?()
                        }
                    }
                    .disabled(!viewModel.validated || viewModel.isBusy)

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
