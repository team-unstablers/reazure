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
    var body: some View {
        VStack {
            /*
            HStack {
                KeypadButton(label: .constant("esc"), sublabel: .constant("release focus"))
            }
             */
            HStack {
                KeypadButton(label: .constant("h"), sublabel: .constant("←"))
                KeypadButton(label: .constant("j"), sublabel: .constant("↓"))
                KeypadButton(label: .constant("k"), sublabel: .constant("↑"))
                KeypadButton(label: .constant("l"), sublabel: .constant("→"))
            }
            HStack {
                KeypadButton(label: .constant("r"), sublabel: .constant("reply"))
                KeypadButton(label: .constant("f"), sublabel: .constant("favourite"))
                KeypadButton(label: .constant("t"), sublabel: .constant("boost"))
                KeypadButton(label: .constant("v"), sublabel: .constant("context"))
                KeypadButton(label: .constant("u"), sublabel: .constant("new post"))
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
        }
        
        Spacer()
    }
}
