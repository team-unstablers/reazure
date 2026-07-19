//
//  PostRowPresentation.swift
//  reazure
//

import Foundation

/// A modal a timeline row asks its host to present.
///
/// Context-menu handlers have no view context to present from — a
/// `PostContextMenuDescriptor.Action` is a bare closure, and the `v` shortcut
/// renders through UIKit's `UIMenu` — so the actions that need a dialog publish
/// one of these instead, and `SetupContextMenuModifier` (which owns the row's
/// view) presents it.
enum PostRowPresentation {
    case confirm(PostRowConfirmation)
    case report(PostReportTarget)
    /// The attachment viewer, opened from the attachment submenu. The row
    /// decides between a separate window and an in-app full-screen cover, the
    /// same way `AttachmentRow` does for a thumbnail tap.
    case gallery(AttachmentGalleryContext)
}

/// A destructive action held back until the user confirms it.
struct PostRowConfirmation: Identifiable {
    enum Kind: String {
        case delete
        case block
    }

    let kind: Kind
    /// `acct` of the affected account; named in the dialog.
    let acct: String
    /// Runs the action. Set by the descriptor, which owns the `StatusModel`.
    let perform: () -> Void

    var id: String { "\(kind.rawValue):\(acct)" }

    var title: String {
        switch kind {
        case .delete:
            return NSLocalizedString("CONFIRM_DELETE_TITLE", comment: "")
        case .block:
            return String(format: NSLocalizedString("CONFIRM_BLOCK_TITLE", comment: ""), acct)
        }
    }

    var message: String {
        switch kind {
        case .delete:
            return NSLocalizedString("CONFIRM_DELETE_MESSAGE", comment: "")
        case .block:
            return NSLocalizedString("CONFIRM_BLOCK_MESSAGE", comment: "")
        }
    }

    /// Title of the confirming (destructive) button.
    var confirmTitle: String {
        switch kind {
        case .delete:
            return NSLocalizedString("CONTEXT_MENU_DELETE", comment: "")
        case .block:
            return NSLocalizedString("CONTEXT_MENU_BLOCK", comment: "")
        }
    }
}

/// The post a report is being raised for, handed to `PostReportSheet`.
struct PostReportTarget: Identifiable {
    let accountId: String
    let acct: String
    let statusId: String
    let statusUrl: String?

    /// Whether to offer forwarding the report to the instance hosting the
    /// account. True only for a remote account on a backend that can forward
    /// (Mastodon); resolved when the menu is built, so the sheet stays a plain
    /// view with no environment dependency of its own.
    let canForward: Bool

    /// Submits the report and reports whether the server accepted it. Set by the
    /// descriptor, which owns the `StatusModel`.
    let submit: (ReportRequest) async -> Bool

    var id: String { statusId }
}

/// What became of a submitted report. A report leaves no trace in the timeline —
/// unlike a block, which greys the author's rows out — so it is acknowledged
/// explicitly.
enum PostReportOutcome: Identifiable {
    case accepted
    case failed

    var id: String {
        switch self {
        case .accepted:
            return "accepted"
        case .failed:
            return "failed"
        }
    }

    var title: String {
        switch self {
        case .accepted:
            return NSLocalizedString("REPORT_ACCEPTED_TITLE", comment: "")
        case .failed:
            return NSLocalizedString("REPORT_FAILED_TITLE", comment: "")
        }
    }

    var message: String {
        switch self {
        case .accepted:
            return NSLocalizedString("REPORT_ACCEPTED_MESSAGE", comment: "")
        case .failed:
            return NSLocalizedString("REPORT_FAILED_MESSAGE", comment: "")
        }
    }
}
