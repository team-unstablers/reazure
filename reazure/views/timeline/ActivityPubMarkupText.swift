//
//  ActivityPubMarkupText.swift
//  reazure
//
//  Created by cheesekun on 11/4/24.
//

import SwiftUI
import UIKit

class HTMLElement: Equatable, Hashable {
    var name: String
    var attributes: [String: String] = [:]
    
    var text: String = ""
    var children: [HTMLElement] = []
    
    init(name: String) {
        self.name = name
    }
    
    static func == (lhs: HTMLElement, rhs: HTMLElement) -> Bool {
        return lhs.name == rhs.name &&
               lhs.attributes == rhs.attributes &&
               lhs.children == rhs.children &&
               lhs.text == rhs.text
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(attributes)
        hasher.combine(children)
        hasher.combine(text)
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
    
    func asNSAttributedString(emojis: [EmojiAdaptor]) -> NSAttributedString {
        if (name == "__TEXT__") {
            let string = NSMutableAttributedString(string: text.replacingOccurrences(of: "\\n", with: "", options: .regularExpression))
            
            string.addAttributes([.font: UIFont.systemFont(ofSize: 16)], range: NSRange(location: 0, length: string.length))
            
            return string
        } else if (name == "__EMOJO__") {
            // FIXME: 비동기 처리가 필요함
            guard let emojoDef = emojis.first(where: { $0.shortcode == text }),
                  let emojoData = try? Data(contentsOf: URL(string: emojoDef.url)!)
            else {
                return NSAttributedString(string: ":\(text):")
            }
            
            let emojo = NSTextAttachment()
            let emojoImage = UIImage(data: emojoData)!
            emojo.image = emojoImage
            
            // emojo.bounds = CGRect(x: 0, y: -4, width: 16, height: 16)
            emojo.bounds = CGRect(x: 0, y: -3, width: emojoImage.size.width, height: emojoImage.size.height)
            
            // print(emojo)
            
            return NSAttributedString(attachment: emojo)
        } else if (name == "br") {
            return NSAttributedString(string: "\n")
        } else if (name == "strong" || name == "b") {
            let result = NSMutableAttributedString()
            
            for child in children {
                result.append(child.asNSAttributedString(emojis: emojis))
            }
            
            result.addAttributes([.font: UIFont.boldSystemFont(ofSize: 16)], range: NSRange(location: 0, length: result.length))
            
            return result
        } else if (name == "a") {
            let result = NSMutableAttributedString()
            
            for child in children {
                result.append(child.asNSAttributedString(emojis: emojis))
            }
            
            result.addAttributes([.link: attributes["href"] ?? ""], range: NSRange(location: 0, length: result.length))
            
            return result
        } else {
            let result = NSMutableAttributedString()
            
            for child in children {
                result.append(child.asNSAttributedString(emojis: emojis))
            }
            
            return result
        }
    }
    
    func asSwiftUIView(emojis: [EmojiAdaptor]) -> Text {
        if (name == "__TEXT__") {
            return Text(text.replacingOccurrences(of: "\\n", with: "", options: .regularExpression))
        } else if (name == "__EMOJO__") {
            // FIXME: 비동기 처리가 필요함
            guard let emojoDef = emojis.first(where: { $0.shortcode == text }),
                  let emojoData = try? Data(contentsOf: URL(string: emojoDef.url)!)
            else {
                return Text(":\(text):")
            }
            
            let emojoImage = UIImage(data: emojoData)!
            let height = 24.0
            let scale = emojoImage.size.height / height
            
            let scaledImage = UIImage(cgImage: emojoImage.cgImage!, scale: scale, orientation: emojoImage.imageOrientation)
            
            return Text(
                Image(uiImage: scaledImage)
                    .resizable()
            )
        } else if (name == "br") {
            return Text("\n")
        } else if (name == "strong" || name == "b") {
            var result: Text = Text("")
            
            for child in children {
                result = result + child.asSwiftUIView(emojis: emojis)
            }
            
            return result.bold()
        } else if (name == "a") {
            // FIXME: a 태그 안에 emoji 있으면 표시 안됨
            let result = NSMutableAttributedString()
            
            for child in children {
                result.append(child.asNSAttributedString(emojis: emojis))
            }
            
            result.addAttributes([.link: attributes["href"] ?? ""], range: NSRange(location: 0, length: result.length))
            
            return Text(AttributedString(result))
        } else {
            var result: Text = Text("")
            
            for child in children {
                result = result + child.asSwiftUIView(emojis: emojis)
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
        
        guard let emojo = scanner.scanCharacters(from: .letters.union(.init(charactersIn: "1234567890_"))) else {
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
            // print("text: \(text)")
            
            let containerElement = parseEmojo(text.decodeHTMLEntity())
            currentElement.children.append(containerElement)
        }
        scanner.scanString("<")
        guard let tag = scanner.scanUpToString(">") else {
            continue // ??
        }
        
        scanner.scanString(">")
        
        // print("tag: \(tag)")
        
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
struct ActivityPubMarkupText: View, Equatable {
    @State
    var resolvedEmojos: [String: UIImage] = [:]
    
    var element: HTMLElement
    var emojos: [EmojiAdaptor]

    init(content: String, emojos: [EmojiAdaptor]) {
        let element = parseHTML(content)
        Self.insertLineBreak(element: element)
        
        self.element = element
        self.emojos = emojos
    }
    
    init(element: HTMLElement, emojos: [EmojiAdaptor]) {
        self.element = element
        self.emojos = emojos
    }
    
    var body: some View {
        buildTextView(element: element, emojis: emojos)
    }
    
    func resolveEmojo(url: String, for code: String) async {
        guard let image = try? await CachedImageLoader.shared.loadImage(url: url) else {
            print("failed to resolve emojo \"\(code)\": (\(url))")
            return
        }
        
        let scaledImage = image.scale(to: 18.0)

        resolvedEmojos[code] = scaledImage
    }
    
    /// 웹 브라우저의 display: block; 속성을 흉내내기 위해 p, div 태그 뒤에 두 개의 br 태그를 추가합니다.
    /// FIXME: 이 함수는 여러 depth의 요소를 가진 HTML을 처리하지 못합니다.
    static func insertLineBreak(element: HTMLElement) {
        if (element.name == "body") {
            for (index, child) in element.children.enumerated() {
                if (index == element.children.count - 1) {
                    break
                }
                
                insertLineBreak(element: child)
            }
        }
        
        if (element.name == "__TEXT__" || element.name == "__EMOJO__") {
            return
        }
        
        if (element.name == "p" || element.name == "div") {
            element.children.append(.init(name: "br"))
            element.children.append(.init(name: "br"))
        }
    }
    
    func buildTextView(element: HTMLElement, emojis: [EmojiAdaptor]) -> Text {
        if (element.name == "__TEXT__") {
            return Text(element.text.replacingOccurrences(of: "\\n", with: "", options: .regularExpression))
        } else if (element.name == "__EMOJO__") {
            guard let emojoDef = emojis.first(where: { $0.shortcode == element.text }) else {
                return Text(":\(element.text):")
            }
            
            guard let emojoImage = self.resolvedEmojos[element.text] else {
                Task {
                    await resolveEmojo(url: emojoDef.url, for: element.text)
                }
                return Text(":\(element.text):")
            }

            
            return Text(
                Image(uiImage: emojoImage)
                    .resizable()
            )
        } else if (element.name == "br") {
            return Text("\n")
        } else if (element.name == "strong" || element.name == "b") {
            var result: Text = Text("")
            
            for child in element.children {
                result = result + buildTextView(element: child, emojis: emojis)
            }
            
            return result.bold()
        } else if (element.name == "a") {
            // FIXME: a 태그 안에 emoji 있으면 표시 안됨
            let result = NSMutableAttributedString()
            
            for child in element.children {
                result.append(child.asNSAttributedString(emojis: emojis))
            }
            
            result.addAttributes([.link: element.attributes["href"] ?? ""], range: NSRange(location: 0, length: result.length))
            
            return Text(AttributedString(result))
        } else {
            var result: Text = Text("")
            
            for child in element.children {
                result = result + buildTextView(element: child, emojis: emojis)
            }
            
            return result
        }
    }
    
    static func == (lhs: ActivityPubMarkupText, rhs: ActivityPubMarkupText) -> Bool {
        // FIXME: compare emojos
        return (lhs.element == rhs.element)
    }
}


struct ActivityPubMarkupTextSimple: View, Equatable {
    var content: String
    var emojos: [EmojiAdaptor]
    
    init(content: String, emojos: [EmojiAdaptor]) {
        self.content = content
        self.emojos = emojos
    }
    
    var body: some View {
        ActivityPubMarkupText(content: content, emojos: emojos)
            .equatable()
    }
    
    static func == (lhs: ActivityPubMarkupTextSimple, rhs: ActivityPubMarkupTextSimple) -> Bool {
        return lhs.content == rhs.content
    }
}

#Preview {
    GeometryReader { geometry in
        VStack(spacing: 2) {
            Text(verbatim: "Test")
            ActivityPubMarkupText(content:
"""
<p>
안녕, 나는 <strong>치즈군★</strong>이야. :smile:<br>
<a href="https://google.com">여기</a>를 누르면 나를 팔로우 할 수 있어.
ㅁㄴ이ㅏ러미ㅏㄴㅇ러ㅏ민ㅇ러ㅏㅣㄴㅁㅇ러ㅏㅣㅁㄴㅇ러ㅏㅣㅁㄴ어라ㅣㅁㄴ어라ㅣㅁ너라ㅣㅁㄴ어리먼아ㅣ러ㅏㅣㅇㄴㅁ
</p>
""",
                                  emojos: []
            )
            Text(verbatim: "Test")
        }
    }

}
