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
        
        return PostItem(status: status, flags: flags) { _ in
            if (expanded) {
                model.expandedDepth = depth
            } else {
                model.expandedDepth = depth + 1
            }
            
            if (model.parents.count < depth + 1) {
                resolveParent(of: status)
            }
        }
            .equatable()
            .padding(.leading, CGFloat(depth) * 8)
        /*
            .onTapGesture {
                sharedClient.focusState[type] = status.id
            }
         */
        // .focusable()
        // .focused(sharedClient.focusState[type], equals: status.id)
            .background {
                if sharedClient.focusState[type] == status.id {
                    Color(uiColor: UIColor(r8: 66, g8: 203, b8: 245, a: 0.2))
                } else {
                    Color.clear
                }
            }
            .id(status.id + "-" + String(depth))
        // .focusable(interactions: [.activate, .edit])
        // .focused($focusedId, equals: status.id)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowSeparator(.hidden)
            .setupShortcutHandler(with: sharedClient)
    }
    
    func resolveParent(of status: StatusAdaptor) {
        if (model.resolving) {
            return
        }
        
        model.resolving = true
        
        Task {
            defer {
                DispatchQueue.main.async {
                    model.resolving = false
                }
            }
            do {
                guard let parent = try await self.sharedClient.client?.status(of: status.replyToId!) else {
                    return
                }
                DispatchQueue.main.async {
                    model.parents.append(MastodonStatusAdaptor(from: parent))
                }
            } catch {
                print("Failed to resolve parent: \(error)")
            }
        }
        
        
        /*
        do {
            let parent = nil // ...
            model.parents.append(parent)
        }
         */
    }
    
}

