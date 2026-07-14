//
//  ReportRequest.swift
//  reazure
//

import Foundation

/// Why a post is being reported. Mirrors Mastodon's report categories; Misskey
/// has no category concept, so its client folds the value into the free-form
/// comment instead.
enum ReportCategory: String, CaseIterable, Identifiable {
    case spam
    case violation
    case other

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .spam:
            return NSLocalizedString("REPORT_CATEGORY_SPAM", comment: "")
        case .violation:
            return NSLocalizedString("REPORT_CATEGORY_VIOLATION", comment: "")
        case .other:
            return NSLocalizedString("REPORT_CATEGORY_OTHER", comment: "")
        }
    }
}

/// A server-agnostic abuse report, submitted through `FediverseClient.report(_:)`.
///
/// Exactly one status is reportable at a time (a report is raised from a single
/// timeline row), so this carries a single optional status rather than a list.
/// `statusUrl` is redundant for Mastodon — it resolves `statusId` itself — but
/// Misskey has no per-note report endpoint, so its client inlines the URL into
/// the comment.
struct ReportRequest {
    /// The reported account. On both backends this is the *local* id of the
    /// account as seen by the user's own server.
    let accountId: String

    let statusId: String?
    let statusUrl: String?

    let comment: String
    let category: ReportCategory

    /// Forward the report to the remote instance that hosts the account.
    /// Mastodon-only; ignored by backends that cannot forward.
    let forward: Bool

    init(accountId: String,
         statusId: String? = nil,
         statusUrl: String? = nil,
         comment: String = "",
         category: ReportCategory = .other,
         forward: Bool = false) {
        self.accountId = accountId
        self.statusId = statusId
        self.statusUrl = statusUrl
        self.comment = comment
        self.category = category
        self.forward = forward
    }
}
