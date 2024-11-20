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

struct NotificationGroup: View {
    @EnvironmentObject
    var preferencesManager: PreferencesManager

    @EnvironmentObject
    var sharedClient: SharedClient
    
    @ObservedObject
    var model: NotificationModel
    
    @ObservedObject
    var statusModel: StatusModel
    
    var focusState: FocusState<TLFocusState?>.Binding
    
    var scrollViewProxy: ScrollViewProxy?

    var flags: PostItemFlags {
        var flags = PostItemFlags()
        
        switch model.notification.type {
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
    
    var body: some View {
        Section {
            renderItem(statusModel, statusModel.status, depth: 0)
            
            if statusModel.expandedDepth > 0 {
                ForEach(1...statusModel.expandedDepth, id: \.self) { index in
                    if statusModel.parents.count < index {
                        ProgressView()
                    } else {
                        renderItem(statusModel, statusModel.parents[index - 1], depth: index)
                    }
                }
            }
        }
    }
    
    func renderItem(_ statusModel: StatusModel, _ status: StatusAdaptor, depth: Int) -> some View {
        let expanded = statusModel.expandedDepth > depth
        var flags = depth == 0 ? flags : PostItemFlags()
        let relatedAccount: AccountAdaptor? = depth == 0 ? model.notification.account : nil
        
        if expanded {
            flags.insert(.expanded)
        }
        
        let focusInfo = TLFocusState(id: model.id, depth: depth)
        let focusState = sharedClient.focusState[.notifications]
        let focused = focusState?.id == model.id && focusState?.depth == depth
        
        let shouldDisplayCompactRow = (preferencesManager.compactMode && !focused)
        
        if shouldDisplayCompactRow {
            return AnyView(
                CompactPostItem(status: status, relatedAccount: relatedAccount, flags: flags)
                    .equatable()
                    .padding(.leading, CGFloat(depth) * 8)
                    .onTapGesture {
                        sharedClient.focusState[.notifications] = focusInfo
                    }
                    .id(focusInfo)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowSeparator(.hidden)
            )
        }

        let item = PostItem(status: status, relatedAccount: relatedAccount, flags: flags) { _ in
            if (expanded) {
                statusModel.expandedDepth = depth
            } else {
                statusModel.expandedDepth = depth + 1
            }
            
            if (statusModel.parents.count < depth + 1) {
                statusModel.resolveParent(of: status, using: sharedClient.client!)
            }
        }
            .equatable()
            .padding(.leading, CGFloat(depth) * 8)
            .background {
                if focused {
                    Color(uiColor: UIColor(r8: 66, g8: 203, b8: 245, a: 0.2))
                } else {
                    Color.clear
                }
            }
            .id(focusInfo)
            .onTapGesture {
                sharedClient.focusState[.notifications] = focusInfo
            }
            /*
            .focusable()
            .focused(focusState, equals: focusInfo)
             */
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowSeparator(.hidden)
            .setupShortcutHandler(with: sharedClient)
        
        
        if preferencesManager.compactMode && focused {
            return AnyView(
                item.onAppear {
                    // HACK: compact 모드인 경우 컨텐츠가 잘린 채로 스크롤 되는 경우가 있음
                    scrollViewProxy?.scrollTo(focusInfo)
                }
           )
        }
        
        return AnyView(item)
    }
    

    
}

