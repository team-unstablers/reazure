//
//  EULASheet.swift
//  reazure
//

import SwiftUI

/// 이용약관 및 커뮤니티 정책 동의 시트.
///
/// App Store 심사 지침 1.2(사용자 생성 콘텐츠)는 계정 등록·로그인에 앞서 이용약관을
/// 제시하고 명시적인 동의를 받을 것을 요구한다. 따라서 이 시트는 OAuth 인증을
/// 시작하기 직전에 표시되며, 동의 없이는 인증 플로우로 진입할 수 없다.
///
/// 동의 상태는 저장하지 않는다. 계정을 추가할 때마다 매번 제시하므로 별도의
/// 영속 상태 없이도 요건을 만족한다.
struct EULASheet: View {
    /// 사용자가 입력한 서버 주소. 해당 인스턴스의 규칙 페이지로 연결하는 데 쓰인다.
    var serverAddress: String
    var agreeHandler: () -> Void

    @Environment(\.dismiss)
    private var dismiss

    private static let privacyPolicyURL = URL(string: "https://github.com/team-unstablers/reazure/blob/main/PRIVACY_POLICY.md")!
    private static let contactURL = URL(string: "mailto:contact+reazure@unstabler.pl")!

    private var serverRulesURL: URL? {
        URL(string: "https://\(serverAddress.sanitizeServerAddress())/about")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("EULA_INTRO")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    section("EULA_SECTION_SERVICE_TITLE", "EULA_SECTION_SERVICE_BODY")
                    section("EULA_SECTION_PROHIBITED_TITLE", "EULA_SECTION_PROHIBITED_BODY")
                    section("EULA_SECTION_RESPONSIBILITY_TITLE", "EULA_SECTION_RESPONSIBILITY_BODY")
                    section("EULA_SECTION_REPORTING_TITLE", "EULA_SECTION_REPORTING_BODY")
                    section("EULA_SECTION_ENFORCEMENT_TITLE", "EULA_SECTION_ENFORCEMENT_BODY")
                    section("EULA_SECTION_TERMINATION_TITLE", "EULA_SECTION_TERMINATION_BODY")

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        if let serverRulesURL = serverRulesURL {
                            Link(destination: serverRulesURL) {
                                Label("EULA_LINK_SERVER_RULES", systemImage: "list.bullet.rectangle")
                            }
                        }
                        Link(destination: Self.privacyPolicyURL) {
                            Label("EULA_LINK_PRIVACY_POLICY", systemImage: "hand.raised")
                        }
                        Link(destination: Self.contactURL) {
                            Label("EULA_LINK_CONTACT", systemImage: "envelope")
                        }
                    }
                    .font(.subheadline)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("EULA_NAVIGATION_TITLE")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    Divider()

                    Button {
                        dismiss()
                        agreeHandler()
                    } label: {
                        Text("ACTION_AGREE_AND_CONTINUE")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(role: .cancel) {
                        dismiss()
                    } label: {
                        Text("ACTION_DECLINE")
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                .background(.bar)
            }
        }
    }

    private func section(_ title: LocalizedStringKey, _ body: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(body)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    EULASheet(serverAddress: "mastodon.social") {}
}
