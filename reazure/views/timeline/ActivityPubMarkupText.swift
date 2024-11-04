//
//  ActivityPubMarkupText.swift
//  reazure
//
//  Created by cheesekun on 11/4/24.
//

import SwiftUI
import UIKit

class HTMLElement {
    var name: String
    var attributes: [String: String] = [:]
    
    var text: String = ""
    var children: [HTMLElement] = []
    
    init(name: String) {
        self.name = name
    }
}

extension HTMLElement {
    var innerText: String {
        return children.map { it in
            if (it.name == "__TEXT__") {
                // replace all whitespace characters with a single space
                return it.text.replacingOccurrences(of: "\\n", with: "", options: .regularExpression)
            } else if (it.name == "__EMOJO__") {
                return "<emojo>\(it.text)</emojo>"
            } else if (it.name == "br") {
                return "\n"
            } else {
                return it.innerText
            }
        }.joined()
    }
    
    func asNSAttributedString() -> NSAttributedString {
        
        if (name == "__TEXT__") {
            let string = NSMutableAttributedString(string: text.replacingOccurrences(of: "\\n", with: "", options: .regularExpression))
            
            string.addAttributes([.font: UIFont.systemFont(ofSize: 16)], range: NSRange(location: 0, length: string.length))
            
            return string
        } else if (name == "__EMOJO__") {
            /*
            let emojo = NSTextAttachment()
            emojo.image = NSImage(named: text)
            return NSAttributedString(attachment: emojo)
             */
            
            return NSAttributedString(string: "<emojo>\(text)</emojo>")
        } else if (name == "br") {
            return NSAttributedString(string: "\n")
        } else if (name == "strong" || name == "b") {
            let result = NSMutableAttributedString()
            
            for child in children {
                result.append(child.asNSAttributedString())
            }
            
            result.addAttributes([.font: UIFont.boldSystemFont(ofSize: 16)], range: NSRange(location: 0, length: result.length))
            
            return result
        } else if (name == "a") {
            let result = NSMutableAttributedString()
            
            for child in children {
                result.append(child.asNSAttributedString())
            }
            
            result.addAttributes([.link: attributes["href"] ?? ""], range: NSRange(location: 0, length: result.length))
            
            return result
        } else {
            let result = NSMutableAttributedString()
            
            for child in children {
                result.append(child.asNSAttributedString())
            }
            
            return result
        }
    }
}

extension HTMLElement {
    static let selfClosingTags: Set<String> = [
        "area", "base", "br", "col", "embed", "hr",
        "img", "input", "link", "meta", "param", "source", "track", "wbr"
    ]
    
    var isSelfClosing: Bool {
        HTMLElement.selfClosingTags.contains(name)
    }
}

func parseTag(_ tag: String) -> HTMLElement? {
    let scanner = Scanner(string: tag)
    scanner.charactersToBeSkipped = nil
    
    guard let tagName = scanner.scanUpToCharacters(from: .whitespacesAndNewlines) else {
        return nil
    }
    let element = HTMLElement(name: tagName)
    
    while !scanner.isAtEnd {
        scanner.scanCharacters(from: .whitespacesAndNewlines)
        
        // [a-zA-Z0-9\-]
        guard let key = scanner.scanCharacters(from: .alphanumerics.union(.init(charactersIn: "-"))) else {
            break
        }
        
        guard let _ = scanner.scanString("=") else {
            element.attributes[key] = "true"
            continue
        }
        
        scanner.scanString("\"")
        
        guard let value = scanner.scanUpToString("\"") else {
            break
        }
        
        scanner.scanString("\"")
        
        element.attributes[key] = value
    }

    return element
}

func parseEmojo(_ rootText: String) -> HTMLElement {
    var root = HTMLElement(name: "__TEXT_CONTAINER__")
    
    let scanner = Scanner(string: rootText)
    scanner.charactersToBeSkipped = nil
    
    while !scanner.isAtEnd {
        if let text = scanner.scanUpToString(":") {
            let textElement = HTMLElement(name: "__TEXT__")
            textElement.text = text
            
            root.children.append(textElement)
        }
        
        guard let _ = scanner.scanString(":") else {
            continue
        }
        
        guard let emojo = scanner.scanCharacters(from: .lowercaseLetters.union(.init(charactersIn: "1234567890_"))) else {
            let textElement = HTMLElement(name: "__TEXT__")
            textElement.text = ":"
            
            root.children.append(textElement)
            continue
        }
        
        guard let _ = scanner.scanString(":") else {
            let textElement = HTMLElement(name: "__TEXT__")
            textElement.text = ":\(emojo)"
            
            root.children.append(textElement)
            continue
        }
        
        let emojoElement = HTMLElement(name: "__EMOJO__")
        emojoElement.text = emojo
        
        root.children.append(emojoElement)
    }
    
    return root
}


func parseHTML(_ html: String) -> HTMLElement {
    var root = HTMLElement(name: "body")
    
    var stack: [HTMLElement] = []
    var currentElement: HTMLElement = root
    
    let scanner = Scanner(string: html)
    scanner.charactersToBeSkipped = nil
    
    while !scanner.isAtEnd {
        if let text = scanner.scanUpToString("<") {
            print("text: \(text)")
            
            let containerElement = parseEmojo(text)
            currentElement.children.append(containerElement)
        }
        scanner.scanString("<")
        guard let tag = scanner.scanUpToString(">") else {
            continue // ??
        }
        
        scanner.scanString(">")
        
        print("tag: \(tag)")
        
        if tag.hasPrefix("!--") && tag.hasSuffix("--") {
            continue
        }
        
        if tag.hasPrefix("/") {
            let tagName = tag.dropFirst()
            
            guard currentElement.name == tagName else {
                fatalError("Invalid HTML")
            }
            
            let parent = stack.popLast()
            
            if let parent = parent {
                parent.children.append(currentElement)
                currentElement = parent
            }
            
            continue
        }
        
        guard let element = parseTag(tag) else {
            continue
        }
        
        let selfClosing = tag.hasSuffix("/") || element.isSelfClosing == true
        
        if selfClosing {
            currentElement.children.append(element)
        } else {
            stack.append(currentElement)
            currentElement = element
        }
    }
    
    return root
}



// CustomText에서 UIImage를 포함하는 NSAttributedString 생성 예시
struct ActivityPubMarkupText: UIViewRepresentable {
    var text: String
    var maxWidth: CGFloat

    func makeUIView(context: Context) -> UILabel {
        let rootElement = parseHTML(text)
        
        let rootView = UIView()
        
        let label = UILabel()
        label.lineBreakMode = .byWordWrapping
        label.numberOfLines = 0
        // label.text = "test"
        
        label.attributedText = rootElement.asNSAttributedString()
        // label.backgroundColor = .blue

        label.setContentHuggingPriority(.defaultHigh, for: .vertical)
        label.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
        // label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        // label.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        /*
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
         */

        label.preferredMaxLayoutWidth = maxWidth
        label.sizeToFit()

        return label
    }

    func updateUIView(_ uiView: UILabel, context: Context) {
        let rootElement = parseHTML(text)
        
        uiView.attributedText = rootElement.asNSAttributedString()
        // uiView.text = "\(uiView.topAnchor)"
        uiView.sizeToFit()
        
        // uiView.preferredMaxLayoutWidth = uiView.frame.width
        uiView.preferredMaxLayoutWidth = maxWidth

    }
}

#Preview {
    GeometryReader { geometry in
        VStack(spacing: 2) {
            Text(verbatim: "Test")
            ActivityPubMarkupText(text:
"""
<p>
안녕, 나는 <strong>치즈군★</strong>이야. :smile:<br>
<a href="https://google.com">여기</a>를 누르면 나를 팔로우 할 수 있어.
ㅁㄴ이ㅏ러미ㅏㄴㅇ러ㅏ민ㅇ러ㅏㅣㄴㅁㅇ러ㅏㅣㅁㄴㅇ러ㅏㅣㅁㄴ어라ㅣㅁㄴ어라ㅣㅁ너라ㅣㅁㄴ어리먼아ㅣ러ㅏㅣㅇㄴㅁ
</p>
""",
                                  maxWidth: geometry.size.width
            )
            Text(verbatim: "Test")
        }
    }

}
