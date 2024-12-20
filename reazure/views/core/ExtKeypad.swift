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
    @Environment(\.palette)
    var palette: AppPalette

    @Binding var label: String
    @Binding var sublabel: String?
    
    var handler: () -> Void = {}
    
    var body: some View {
        Button {
            handler()
        } label: {
            VStack {
                Text(label)
                    .foregroundStyle(palette.extKeypadButtonForeground)
                    .padding(.bottom, 0)
                
                Text(sublabel ?? " ")
                    .font(.caption2)
                    .foregroundStyle(palette.extKeypadButtonSecondaryForeground)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(palette.extKeypadButtonBackground)
        .clipShape(.rect(cornerRadius: 4))
        .shadow(radius: 1, x: 0, y: 1)
        .hapticFeedback()
    }
}


struct ExtKeypad: View {
    @Environment(\.palette)
    var palette: AppPalette
    
    @EnvironmentObject
    var preferencesManager: PreferencesManager
    
    @EnvironmentObject
    var sharedClient: SharedClient
    
    var directionalPad: some View {
        
        let h = KeypadButton(label: .constant("h"), sublabel: .constant("←")) {
            sharedClient.handleShortcut(key: .h)
        }
        
        let j = KeypadButton(label: .constant("j"), sublabel: .constant("↓")) {
            sharedClient.handleShortcut(key: .j)
        }
        
        let k = KeypadButton(label: .constant("k"), sublabel: .constant("↑")) {
            sharedClient.handleShortcut(key: .k)
        }
        
        let l = KeypadButton(label: .constant("l"), sublabel: .constant("→")) {
            sharedClient.handleShortcut(key: .l)
        }

        
        return HStack {
            h
            if (preferencesManager.swapJKOnExtKeypad) {
                k
                j
            } else {
                j
                k
            }
            l
        }
    }
    
    var body: some View {
        VStack {
            /*
             HStack {
             KeypadButton(label: .constant("esc"), sublabel: .constant("release focus"))
             }
             */
            self.directionalPad
            HStack {
                KeypadButton(label: .constant("r"), sublabel: .constant("reply")) {
                    sharedClient.handleShortcut(key: .r)
                }
                KeypadButton(label: .constant("f"), sublabel: .constant("favourite")) {
                    sharedClient.handleShortcut(key: .f)
                }
                KeypadButton(label: .constant("t"), sublabel: .constant("boost")) {
                    sharedClient.handleShortcut(key: .t)
                }
                KeypadButton(label: .constant("v"), sublabel: .constant("context")) {
                }
                KeypadButton(label:
                                !sharedClient.postAreaFocused ?
                    .constant("u") : .constant("esc"),
                             sublabel:
                                !sharedClient.postAreaFocused ?
                    .constant("new post") : .constant("unfocus")
                ) {
                    sharedClient.handleShortcut(key: .u)
                }
                    .onLongPressGesture(minimumDuration: 0.1, maximumDistance: 0) {
                        print("TODO: discard")
                    }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(palette.extKeypadBackground)
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
                .environmentObject(PreferencesManager())
                .environmentObject(SharedClient.shared)
        }
        
        Spacer()
    }
}
