//
//  PostItem+setupContextMenu.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/25/24.
//

import Combine
import Foundation
import SwiftUI
import UIKit


extension View {
    func setupContextMenu(
        _ model: StatusModel,
        depth: Int,
        presentRequest: AnyPublisher<TimelineModel.FocusState, Never>
    ) -> some View {
        self.modifier(SetupContextMenuModifier(model: model, depth: depth, presentRequest: presentRequest))
    }
}


struct SetupContextMenuModifier: ViewModifier {
    let model: StatusModel
    let depth: Int
    let presentRequest: AnyPublisher<TimelineModel.FocusState, Never>

    /// The row hosts the modals its own context menu asks for: both menu
    /// renderers hand back a `PostRowPresentation` instead of acting, and these
    /// hold whichever one is on screen.
    @Environment(\.openWindow)
    private var openWindow

    @State private var confirmation: PostRowConfirmation?
    @State private var reportTarget: PostReportTarget?
    @State private var reportOutcome: PostReportOutcome?
    @State private var gallery: AttachmentGalleryContext?

    @ViewBuilder
    func body(content: Content) -> some View {
        content
            .contextMenu {
                NativePostContextMenuInner(model: model, depth: depth, present: present)
            }
            .overlay {
                ProgrammaticContextMenuHost(model: model,
                                            depth: depth,
                                            presentRequest: presentRequest,
                                            present: present)
            }
            .confirmationDialog(
                confirmation?.title ?? "",
                isPresented: isPresented($confirmation),
                titleVisibility: .visible,
                presenting: confirmation
            ) { confirmation in
                Button(confirmation.confirmTitle, role: .destructive) {
                    confirmation.perform()
                }
                Button(NSLocalizedString("DIALOG_CANCEL", comment: ""), role: .cancel) {}
            } message: { confirmation in
                Text(confirmation.message)
            }
            .sheet(item: $reportTarget) { target in
                PostReportSheet(target: target) { request in
                    Task {
                        let accepted = await target.submit(request)
                        reportOutcome = accepted ? .accepted : .failed
                    }
                }
            }
            .alert(
                reportOutcome?.title ?? "",
                isPresented: isPresented($reportOutcome),
                presenting: reportOutcome
            ) { _ in
                Button(NSLocalizedString("DIALOG_OK", comment: ""), role: .cancel) {}
            } message: { outcome in
                Text(outcome.message)
            }
            .fullScreenCover(item: $gallery) { context in
                AttachmentGalleryView(context: context)
            }
    }

    /// Handlers fire while the context menu is still on screen, and SwiftUI will
    /// not present a sheet or dialog from a row that is mid-dismissal. Deferring
    /// the state change by a runloop turn lets the menu go away first.
    private func present(_ presentation: PostRowPresentation) {
        DispatchQueue.main.async {
            switch presentation {
            case .confirm(let confirmation):
                self.confirmation = confirmation
            case .report(let target):
                self.reportTarget = target
            case .gallery(let context):
                // iPad/macOS는 별도 윈도우로, 멀티 씬을 지원하지 않는 iPhone에서는
                // 풀스크린 커버로 연다 (`AttachmentRow`의 썸네일 탭과 동일한 분기).
                if UIApplication.shared.supportsMultipleScenes {
                    self.openWindow(value: context)
                } else {
                    self.gallery = context
                }
            }
        }
    }

    /// Bridges an `Identifiable?` state to the `isPresented:` binding the
    /// dialog/alert overloads want, clearing it on dismissal.
    private func isPresented<T>(_ binding: Binding<T?>) -> Binding<Bool> {
        Binding(
            get: { binding.wrappedValue != nil },
            set: { presented in
                if !presented {
                    binding.wrappedValue = nil
                }
            }
        )
    }
}
