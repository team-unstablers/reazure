//
//  ExtKeypad.swift
//  reazure
//
//  Created by cheesekun on 11/3/24.
//

import SwiftUI

fileprivate extension View {
    func hapticFeedback() -> some View {
        modifier(HapticFeedbackModifier())
    }
}

fileprivate enum FeedbackStyle {
    case light
    case medium
}

fileprivate struct HapticFeedbackModifier: ViewModifier {
    @State private var tapped = false
    var style: FeedbackStyle = .medium

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !self.tapped {
                        self.tapped = true
                        HapticManager.shared.feedback(.medium)
                    }
                }
                .onEnded { _ in
                    self.tapped = false
                    HapticManager.shared.feedback(.soft)
                })
    }
}


fileprivate struct KeypadButton: View {
    @Binding var label: String
    @Binding var sublabel: String?
    
    var handler: () -> Void = {}

    var body: some View {
        Button {
            handler()
        } label: {
            VStack {
                Text(label)
                    .foregroundStyle(.black)
                    .padding(.bottom, 0)
                
                Text(sublabel ?? " ")
                    .font(.caption2)
                    .foregroundStyle(.gray)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(.white)
        .clipShape(.rect(cornerRadius: 4))
        .shadow(radius: 1, x: 0, y: 1)
        .hapticFeedback()
    }
}

struct ExtKeypad: View {
    @EnvironmentObject
    var sharedClient: SharedClient
    
    var body: some View {
        VStack {
            /*
            HStack {
                KeypadButton(label: .constant("esc"), sublabel: .constant("release focus"))
            }
             */
            HStack {
                KeypadButton(label: .constant("h"), sublabel: .constant("←"))
                KeypadButton(label: .constant("j"), sublabel: .constant("↓")) {
                    guard let focusedId = sharedClient.focusState[.home],
                          let index = sharedClient.timeline[.home]?.firstIndex(where: { $0.id == focusedId })
                    else {
                        sharedClient.focusState[.home] = sharedClient.timeline[.home]?.first?.id
                        return
                    }
                    
                    let timeline = sharedClient.timeline[.home]!
                    
                    let nextIndex = max(0, min(index + 1, timeline.count - 1))
                    let nextId = timeline[nextIndex].id
                    
                    sharedClient.focusState[.home] = nextId
                }
                KeypadButton(label: .constant("k"), sublabel: .constant("↑")) {
                    guard let focusedId = sharedClient.focusState[.home],
                          let index = sharedClient.timeline[.home]?.firstIndex(where: { $0.id == focusedId })
                    else {
                        sharedClient.focusState[.home] = sharedClient.timeline[.home]?.first?.id
                        return
                    }
                    
                    let timeline = sharedClient.timeline[.home]!
                    
                    let prevIndex = max(0, min(index - 1, timeline.count - 1))
                    let prevId = timeline[prevIndex].id
                    
                    sharedClient.focusState[.home] = prevId
                }
                KeypadButton(label: .constant("l"), sublabel: .constant("→"))
            }
            HStack {
                KeypadButton(label: .constant("r"), sublabel: .constant("reply")) {
                    sharedClient.replyTo.send(sharedClient.focusedStatus(for: .home))
                }
                KeypadButton(label: .constant("f"), sublabel: .constant("favourite")) {
                    sharedClient.withFocusedStatus(for: .home) { status in
                        guard let status = status else {
                            return nil
                        }
                        
                        var modified = status
                        
                        // FIXME: this is a workaround for the API not updating the status object
                        // FIXME: client.favourite() will return new status object, should implement timeline.replace(status)
                        if (!status.favourited) {
                            Task {
                                try? await sharedClient.client?.favourite(statusId: status.id)
                            }
                            modified.favourited = true
                            
                            return modified
                        } else {
                            Task {
                                try? await sharedClient.client?.unfavourite(statusId: status.id)
                            }
                            modified.favourited = false
                            
                            return modified
                        }
                    }
                }
                KeypadButton(label: .constant("t"), sublabel: .constant("boost")) {
                    sharedClient.withFocusedStatus(for: .home) { status in
                        guard let status = status else {
                            return nil
                        }
                        
                        var modified = status
                        
                        // FIXME: this is a workaround for the API not updating the status object
                        // FIXME: client.favourite() will return new status object, should implement timeline.replace(status)
                        if (!status.reblogged) {
                            Task {
                                try? await sharedClient.client?.reblog(statusId: status.id)
                            }
                            modified.reblogged = true
                            
                            return modified
                        } else {
                            Task {
                                try? await sharedClient.client?.unreblog(statusId: status.id)
                            }
                            modified.reblogged = false
                            
                            return modified
                        }
                    }
                }
                KeypadButton(label: .constant("v"), sublabel: .constant("context"))
                KeypadButton(label:
                                !sharedClient.postAreaFocused ?
                                    .constant("u") : .constant("esc"),
                             sublabel:
                                !sharedClient.postAreaFocused ?
                                    .constant("new post") : .constant("unfocus")
                ) {
                    sharedClient.postAreaFocused.toggle()
                }
                .onLongPressGesture(minimumDuration: 0.1, maximumDistance: 0) {
                    print("TODO: discard")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(uiColor: .init(r8: 209, g8: 212, b8: 217)))
    }
}

#Preview {
    VStack {
        Spacer()
        VStack {
            Text("Preview of KeypadButton")
            HStack {
                KeypadButton(label: .constant("up"), sublabel: .constant(nil))
                KeypadButton(label: .constant("down"), sublabel: .constant("test"))
            }
            .padding()
            .background(Color(uiColor: .init(r8: 209, g8: 212, b8: 217)))
        }
        
        Spacer()
        
        VStack {
            Text("Preview of ExtKeypad")
            ExtKeypad()
                .environmentObject(SharedClient())
        }
        
        Spacer()
    }
}
