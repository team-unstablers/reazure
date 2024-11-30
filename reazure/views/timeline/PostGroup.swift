//
//  PostItem.swift
//  reazure
//
//  Created by cheesekun on 11/2/24.
//

import SwiftUI

/*
 enum PostItemType {
 case normal
 case reblog
 case favourite
 }
 */

typealias TLFocusChangeHandler = (TimelineModel.FocusState) -> Void

struct PostGroup: View {
    @Environment(\.palette)
    var palette: AppPalette
    
    @Environment(\.tlFocusState)
    var focusState: TimelineModel.FocusState?
    
    @EnvironmentObject
    var preferencesManager: PreferencesManager
    
    @ObservedObject
    var model: StatusModel
    
    var scrollViewProxy: ScrollViewProxy?
    
    var focusChangeHandler: TLFocusChangeHandler
    
    var body: some View {
        Section {
            renderItem(model.status, depth: 0)
            
            if model.expandedDepth > 0 {
                ForEach(1...model.expandedDepth, id: \.self) { index in
                    if model.parents.count < index {
                        ProgressView()
                    } else {
                        renderItem(model.parents[index - 1], depth: index)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    func renderItem(_ status: StatusAdaptor, depth: Int) -> some View {
        let expanded = model.expandedDepth > depth
        // 게을러..
        let flags: PostItemFlags = ((depth == 0) ? model.rootStatusFlags : [])
            .union(expanded ? [.expanded] : [])
        
        let relatedAccount: AccountAdaptor? = (depth == 0) ? model.rootRelatedAccount : nil
        
        let focusInfo = TimelineModel.FocusState(id: model.id, depth: depth)
        let focusState = focusState
        let focused = focusState?.id == model.id && focusState?.depth == depth
        
        let shouldDisplayCompactRow = (preferencesManager.compactMode && !focused)
        
        if shouldDisplayCompactRow {
            CompactPostItem(status: status, relatedAccount: relatedAccount, flags: flags)
                .equatable()
                .setupPostItemView(depth: depth, focused: focused, palette: palette)
                .setupFocusHandler(with: focusInfo, handler: focusChangeHandler)
                .setupContextMenu(model, depth: depth)
        } else {
            let item = PostItem(status: status, relatedAccount: relatedAccount, flags: flags) { _ in
                if (expanded) {
                    model.expandedDepth = depth
                } else {
                    model.expandedDepth = depth + 1
                }
                
                if (model.parents.count < depth + 1) {
                    Task {
                        try? await model.resolveParent(of: status)
                    }
                }
            }
                .equatable()
                .setupPostItemView(depth: depth, focused: focused, palette: palette)
                .setupFocusHandler(with: focusInfo, handler: focusChangeHandler)
                .setupContextMenu(model, depth: depth)

            if preferencesManager.compactMode && focused {
                AnyView(
                    item.onAppear {
                        // HACK: compact 모드인 경우 컨텐츠가 잘린 채로 스크롤 되는 경우가 있음
                        scrollViewProxy?.scrollTo(focusInfo)
                    }
                )
            } else {
                item
            }
        }
    }
}

fileprivate extension StatusModel {
    var rootStatusFlags: PostItemFlags {
        // check (self instanceof NotificationModel)
        if let _self = self as? NotificationModel {
            var flags = PostItemFlags()
            
            switch _self.notification.type {
            case .mention:
                flags.insert(.mentioned)
            case .reblog:
                flags.insert(.rebloggedByOthers)
            case .favourite:
                flags.insert(.favouritedByOthers)
            default:
                break
            }
            
            return flags
        }
        
        return []
    }
    
    var rootRelatedAccount: AccountAdaptor? {
        // check (self instanceof NotificationModel)
        if let _self = self as? NotificationModel {
            if _self.notification.type != .mention {
                return _self.notification.account
            }
        }
        
        return nil
    }
    
}


fileprivate extension View {
    @ViewBuilder
    func setupPostItemView(depth: Int, focused: Bool, palette: AppPalette) -> some View {
        self
            .padding(.leading, CGFloat(depth) * 8)
            .background {
                if focused {
                    palette.postItemFocusedBackground
                } else {
                    Color.clear
                }
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowSeparator(.hidden)
    }
    
    @ViewBuilder
    func setupFocusHandler(with focusInfo: TimelineModel.FocusState, handler: @escaping TLFocusChangeHandler) -> some View {
        self
            .id(focusInfo)
            .onTapGesture {
                handler(focusInfo)
            }
    }
}
