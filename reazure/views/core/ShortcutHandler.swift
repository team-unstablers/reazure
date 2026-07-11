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
    
    /// 익스클루시브 가드 (아래 참조)
    @MainActor
    private var __XXX__UIKIT_BUG_WORKAROUND_ACCESS_GUARD: Bool = false
    
    /// BUG: UIKeyCommand 핸들러 '그 자체'와 몇 틱 이내에 programmatic한 방법으로 UIButton의 컨텍스트 메뉴를 열면 Key release를 감지하지 못해서 무한 루프가 발생합니다.
    ///      (= 메뉴를 아무리 닫아도 키가 눌린 상태로 남아, 계속해서 컨텍스트 메뉴를 열려고 시도합니다)
    ///      부득이하게 0.2초 정도 딜레이를 두고 컨텍스트 메뉴를 열도록 하여 이 문제를 해결합니다.
    ///
    ///      - 이 문제는 macOS 26 (via Designed for iPad)에서 확인되었으며, iPadOS에서는 아직 확인하지 못했습니다.
    @MainActor
    @objc
    func handlerV() {
        // HACK: @MainActor로 보호된 익스클루시브 가드를 생성한다
        guard !__XXX__UIKIT_BUG_WORKAROUND_ACCESS_GUARD else {
            return
        }
        
        self.__XXX__UIKIT_BUG_WORKAROUND_ACCESS_GUARD = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.router.handleShortcut(key: .v)
            
            self.__XXX__UIKIT_BUG_WORKAROUND_ACCESS_GUARD = false
        }
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

