//
//  TimelineModel+shortcuts.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/30/24.
//

enum ShortcutKey {
    case h
    case j
    case k
    case l
    
    case r
    case f
    case t
    case v
    case u
}



extension TimelineModel {
    func handleShortcut(_ shortcut: ShortcutKey) {
        switch shortcut {
        case .h:
            collapseFocused()
        case .j:
            focusNext()
        case .k:
            focusPrevious()
        case .l:
            expandFocused()
            
        case .f:
            toggleFavouriteFocused()
        case .r:
            composeReplyFocused()
        case .t:
            toggleReblogFocused()
        case .v:
            break
        case .u:
            sharedClient.postAreaFocused.toggle()
        default:
            break
        }
    }
    
    func focusNext() {
        guard let focusState = focusState,
              let index = statuses.firstIndex(where: { $0.id == focusState.id }) else {
            guard let index = statuses.first?.id else {
                return
            }
            
            self.focusState = FocusState(id: index, depth: 0)
            return
        }
        
        let model = statuses[index]
        
        if (focusState.depth < model.expandedDepth) {
            self.focusState = FocusState(id: model.id, depth: focusState.depth + 1)
        } else {
            let nextIndex = Swift.max(0, Swift.min(index + 1, statuses.count - 1))
            let nextId = statuses[nextIndex].id
            
            self.focusState = FocusState(id: nextId, depth: 0)
        }
    }
    
    func focusPrevious() {
        guard let focusState = focusState,
              let index = statuses.firstIndex(where: { $0.id == focusState.id }) else {
            guard let index = statuses.first?.id else {
                return
            }
            
            self.focusState = FocusState(id: index, depth: 0)
            return
        }
        
        if (index == 0 && focusState.depth == 0) {
            // self.postAreaFocused = true
            return
        }
        
        let model = statuses[index]
        
        if (focusState.depth > 0) {
            self.focusState = FocusState(id: model.id, depth: focusState.depth - 1)
        } else {
            let prevIndex = Swift.max(0, Swift.min(index - 1, statuses.count - 1))
            let prevModel = statuses[prevIndex]
            
            self.focusState = FocusState(id: prevModel.id, depth: prevModel.expandedDepth)
        }
    }
    
    func expandFocused() {
        guard let focusState = focusState,
              let index = statuses.firstIndex(where: { $0.id == focusState.id })
        else {
            return
        }
        
        let model = statuses[index]
        
        let focusedStatus: any StatusAdaptor = (focusState.depth == 0) ?
            model.status :
            model.parents[focusState.depth - 1]
        
        if focusedStatus.replyToId == nil {
            return
        }

        model.expandedDepth = focusState.depth + 1
        
        
        if (model.parents.count < focusState.depth + 1) {
            Task {
                try? await model.resolveParent(of: focusedStatus)
            }
        }
    }
    
    func collapseFocused() {
        guard let focusState = self.focusState,
              let index = statuses.firstIndex(where: { $0.id == focusState.id })
        else {
            return
        }
        
        let model = statuses[index]
        
        model.expandedDepth = Swift.max(0, focusState.depth - 1)
        
        self.focusState = FocusState(id: model.id, depth: model.expandedDepth)
    }
    
    func toggleFavouriteFocused() {
        guard let focusState = self.focusState,
              let index = statuses.firstIndex(where: { $0.id == focusState.id })
        else {
            return
        }
        
        let model = statuses[index]
        
        Task {
            try? await model.toggleFavourite(of: focusState.depth)
        }
    }
    
    func toggleReblogFocused() {
        guard let focusState = self.focusState,
              let index = statuses.firstIndex(where: { $0.id == focusState.id })
        else {
            return
        }
        
        let model = statuses[index]
        
        Task {
            try? await model.toggleReblog(of: focusState.depth)
        }
    }
    
    func composeReplyFocused() {
        guard let focusState = self.focusState,
              let index = statuses.firstIndex(where: { $0.id == focusState.id })
        else {
            return
        }
        
        let model = statuses[index]
        
        Task {
            try? await model.composeReply(to: focusState.depth)
        }
    }
    
}
