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
    @EnvironmentObject
    var sharedClient: SharedClient
    
    @ObservedObject
    var model: StatusModel
    
    var type: TimelineType
    
    var focusState: FocusState<TLFocusState?>.Binding
    
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
        
        return PostItem(status: status, flags: flags) { _ in
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
                if let focusState = sharedClient.focusState[type],
                   focusState.id == model.id,
                   focusState.depth == depth
                {
                    Color(uiColor: UIColor(r8: 66, g8: 203, b8: 245, a: 0.2))
                } else {
                    Color.clear
                }
            }
            .id(focusInfo)
            .onTapGesture {
                sharedClient.focusState[type] = focusInfo
            }
            .focusable()
            .focused(focusState, equals: focusInfo)

        // .focusable(interactions: [.activate, .edit])
        // .focused($focusedId, equals: status.id)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowSeparator(.hidden)
            .setupShortcutHandler(with: sharedClient)
    }
    

    
}

