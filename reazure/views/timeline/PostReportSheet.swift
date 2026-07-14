//
//  PostReportSheet.swift
//  reazure
//

import SwiftUI

/// Composes an abuse report for a single post.
///
/// Doubles as the confirmation step for reporting: nothing is submitted until
/// the send button is tapped. The comment is optional here — Misskey's report
/// endpoint requires a non-empty one, but its client always folds the category
/// and the note's URL in, so an empty comment is still a valid report on both
/// backends.
struct PostReportSheet: View {
    @Environment(\.dismiss)
    private var dismiss

    let target: PostReportTarget

    /// Hands the composed report to the row, which submits it and acknowledges
    /// the outcome.
    let submit: (ReportRequest) -> Void

    @State private var category: ReportCategory = .spam
    @State private var comment: String = ""
    @State private var forward: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(selection: $category) {
                        ForEach(ReportCategory.allCases) { category in
                            Text(verbatim: category.localizedTitle)
                                .tag(category)
                        }
                    } label: {
                        Text("REPORT_CATEGORY")
                    }

                    TextField(text: $comment, axis: .vertical) {
                        Text("REPORT_COMMENT_PLACEHOLDER")
                    }
                    .lineLimit(3...6)
                } header: {
                    Text(verbatim: "@\(target.acct)")
                } footer: {
                    Text("REPORT_DESCRIPTION")
                }

                if target.canForward {
                    Section {
                        Toggle(isOn: $forward) {
                            Text("REPORT_FORWARD")
                        }
                    } footer: {
                        Text("REPORT_FORWARD_DESCRIPTION")
                    }
                }
            }
            .navigationTitle(Text("REPORT_TITLE"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("DIALOG_CANCEL")
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        submit(ReportRequest(
                            accountId: target.accountId,
                            statusId: target.statusId,
                            statusUrl: target.statusUrl,
                            comment: comment,
                            category: category,
                            forward: target.canForward && forward
                        ))
                        dismiss()
                    } label: {
                        Text("REPORT_SUBMIT")
                    }
                }
            }
        }
    }
}
