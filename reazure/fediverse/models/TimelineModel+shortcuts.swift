//
//  TimelineModel+shortcuts.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/30/24.
//

import Foundation

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
    
    var localizedDescription: String {
        switch self {
        case .h: return NSLocalizedString("SHORTCUTKEY_DESCRIPTION_H", comment: "")
        case .j: return NSLocalizedString("SHORTCUTKEY_DESCRIPTION_J", comment: "")
        case .k: return NSLocalizedString("SHORTCUTKEY_DESCRIPTION_K", comment: "")
        case .l: return NSLocalizedString("SHORTCUTKEY_DESCRIPTION_L", comment: "")
        case .r: return NSLocalizedString("SHORTCUTKEY_DESCRIPTION_R", comment: "")
        case .f: return NSLocalizedString("SHORTCUTKEY_DESCRIPTION_F", comment: "")
        case .t: return NSLocalizedString("SHORTCUTKEY_DESCRIPTION_T", comment: "")
        case .v: return NSLocalizedString("SHORTCUTKEY_DESCRIPTION_V", comment: "")
        case .u: return NSLocalizedString("SHORTCUTKEY_DESCRIPTION_U", comment: "")
        }
    }
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
            showContextMenuFocused()
        case .u:
            focusPostArea()
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

        // 열람 경고가 걸린 포스트에서는 먼저 본문을 펼친다. 스레드 확장은 그 다음
        // 눌렀을 때 일어난다 — 경고를 지나치지 않고 한 번 멈추게 하기 위함이다.
        if model.hasContentWarning(at: focusState.depth),
           !model.isRevealed(at: focusState.depth) {
            model.revealedDepths.insert(focusState.depth)
            return
        }

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

        // 펼쳐 둔 열람 경고가 있으면 그것부터 되돌린다. (expandFocused의 역순)
        if model.isRevealed(at: focusState.depth) {
            model.revealedDepths.remove(focusState.depth)
            return
        }

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
    
    func showContextMenuFocused() {
        guard let focusState = self.focusState,
              statuses.contains(where: { $0.id == focusState.id })
        else {
            return
        }

        contextMenuRequest.send(focusState)
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
