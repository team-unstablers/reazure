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

struct PostGroup: View {
    @Environment(\.palette)
    var palette: AppPalette
    
    @EnvironmentObject
    var preferencesManager: PreferencesManager
    
    @EnvironmentObject
    var sharedClient: SharedClient
    
    @ObservedObject
    var model: StatusModel
    
    var type: TimelineType
    
    var focusState: FocusState<TLFocusState?>.Binding
    
    var scrollViewProxy: ScrollViewProxy?
    
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
    
    func renderItem(_ status: StatusAdaptor, depth: Int) -> some View {
        let expanded = model.expandedDepth > depth
        var flags = PostItemFlags()
        
        if expanded {
            flags.insert(.expanded)
        }
        
        let focusInfo = TLFocusState(id: model.id, depth: depth)
        let focusState = sharedClient.focusState[type]
        let focused = focusState?.id == model.id && focusState?.depth == depth
        
        let shouldDisplayCompactRow = (preferencesManager.compactMode && !focused)
        
        if shouldDisplayCompactRow {
            return AnyView(
                CompactPostItem(status: status, flags: flags)
                    .equatable()
                    .padding(.leading, CGFloat(depth) * 8)
                    .onTapGesture {
                        sharedClient.focusState[type] = focusInfo
                    }
                    .id(focusInfo)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowSeparator(.hidden)
            )
        }
        
        let item = PostItem(status: status, flags: flags) { _ in
                if (expanded) {
                    model.expandedDepth = depth
                } else {
                    model.expandedDepth = depth + 1
                }
                
                if (model.parents.count < depth + 1) {
                    model.resolveParent(of: status, using: sharedClient.client!)
                }
            }
                .equatable()
                .padding(.leading, CGFloat(depth) * 8)
                .background {
                    if focused {
                        palette.postItemFocusedBackground
                    } else {
                        Color.clear
                    }
                }
                .id(focusInfo)
                .onTapGesture {
                    sharedClient.focusState[type] = focusInfo
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

