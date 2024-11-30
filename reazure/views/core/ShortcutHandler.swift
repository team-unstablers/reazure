//
//  ShortcutHandler.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/30/24.
//

import SwiftUI
import UIKit

class ShortcutHandlerInternal: UIViewController {
    var sharedClient: SharedClient {
        SharedClient.shared
    }
    
    init() {
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
        sharedClient.handleShortcut(key: .h)
    }
    
    @objc
    func handlerJ() {
        sharedClient.handleShortcut(key: .j)
    }
    
    @objc
    func handlerK() {
        sharedClient.handleShortcut(key: .k)
    }
    
    @objc
    func handlerL() {
        sharedClient.handleShortcut(key: .l)
    }
    
    @objc
    func handlerF() {
        sharedClient.handleShortcut(key: .f)
    }
    
    @objc
    func handlerR() {
        sharedClient.handleShortcut(key: .r)
    }
    
    @objc
    func handlerT() {
        sharedClient.handleShortcut(key: .t)
    }
    
    @objc
    func handlerV() {
        sharedClient.handleShortcut(key: .v)
    }
    
    @objc
    func handlerU() {
        sharedClient.handleShortcut(key: .u)
    }
}

struct ShortcutHandler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> ShortcutHandlerInternal {
        let controller = ShortcutHandlerInternal()
        
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
        
        command.wantsPriorityOverSystemBehavior = true
        
        return command
    }
}

