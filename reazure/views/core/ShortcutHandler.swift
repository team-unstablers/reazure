//
//  ShortcutHandler.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/30/24.
//

import SwiftUI
import UIKit

/// Narrow seam for dispatching keyboard shortcuts, adopted by `SharedClient`.
/// Injected into the shortcut plumbing so it no longer hard-references the
/// `SharedClient.shared` singleton and can be exercised in isolation.
protocol ShortcutRouting: AnyObject {
    func handleShortcut(key: ShortcutKey)
}

class ShortcutHandlerInternal: UIViewController {
    private let router: ShortcutRouting

    init(router: ShortcutRouting) {
        self.router = router
        super.init(nibName: nil, bundle: nil)
        
        registerShortcut(.h, action: #selector(handlerH))
        registerShortcut(.j, action: #selector(handlerJ))
        registerShortcut(.k, action: #selector(handlerK))
        registerShortcut(.l, action: #selector(handlerL))
        registerShortcut(.f, action: #selector(handlerF))
        registerShortcut(.r, action: #selector(handlerR))
        registerShortcut(.t, action: #selector(handlerT))
        registerShortcut(.v, action: #selector(handlerV))
        registerShortcut(.u, action: #selector(handlerU))
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func registerShortcut(_ key: ShortcutKey, action: Selector) {
        let command = key.asUIKeyCommand(selector: action)
        self.addKeyCommand(command)
    }
    
    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.becomeFirstResponder()
    }
    
    @objc
    func handlerH() {
        router.handleShortcut(key: .h)
    }
    
    @objc
    func handlerJ() {
        router.handleShortcut(key: .j)
    }
    
    @objc
    func handlerK() {
        router.handleShortcut(key: .k)
    }
    
    @objc
    func handlerL() {
        router.handleShortcut(key: .l)
    }
    
    @objc
    func handlerF() {
        router.handleShortcut(key: .f)
    }
    
    @objc
    func handlerR() {
        router.handleShortcut(key: .r)
    }
    
    @objc
    func handlerT() {
        router.handleShortcut(key: .t)
    }
    
    @objc
    func handlerV() {
        router.handleShortcut(key: .v)
    }
    
    @objc
    func handlerU() {
        router.handleShortcut(key: .u)
    }
}

struct ShortcutHandler: UIViewControllerRepresentable {
    let router: ShortcutRouting

    func makeUIViewController(context: Context) -> ShortcutHandlerInternal {
        let controller = ShortcutHandlerInternal(router: router)

        return controller
    }
    
    func updateUIViewController(_ uiViewController: ShortcutHandlerInternal, context: Context) {
    }
}

fileprivate extension ShortcutKey {
    var asUIKeyCommandInput: String {
        switch self {
        case .h:
            return UIKeyCommand.inputLeftArrow
        case .j:
            return UIKeyCommand.inputDownArrow
        case .k:
            return UIKeyCommand.inputUpArrow
        case .l:
            return UIKeyCommand.inputRightArrow
        case .f:
            return "f"
        case .r:
            return "r"
        case .t:
            return "t"
        case .v:
            return "v"
        case .u:
            return "u"
        }
        
    }
    
    func asUIKeyCommand(selector: Selector) -> UIKeyCommand {
        let command = UIKeyCommand(
            input: self.asUIKeyCommandInput,
            modifierFlags: [],
            action: selector
        )
        
        command.title = self.localizedDescription
        command.wantsPriorityOverSystemBehavior = true
        
        return command
    }
}

