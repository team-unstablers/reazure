//
//  ActivityPubMarkupText.swift
//  reazure
//
//  Created by cheesekun on 11/4/24.
//

import SwiftUI
import UIKit

func validatedActivityPubLinkURL(_ value: String?) -> URL? {
    guard let value,
          value == value.trimmingCharacters(in: .whitespacesAndNewlines),
          value.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }),
          let components = URLComponents(string: value),
          let scheme = components.scheme?.lowercased(),
          scheme == "http" || scheme == "https",
          components.host != nil,
          components.user == nil,
          components.password == nil else {
        return nil
    }

    return components.url
}

class HTMLElement: Equatable {
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
    
    func asNSAttributedString(
        resolvedEmojos: [String: UIImage],
        fontSize: CGFloat = 16
    ) -> NSAttributedString {
        if (name == "__TEXT__") {
            let string = NSMutableAttributedString(string: text.replacingOccurrences(of: "\\n", with: "", options: .regularExpression))

            string.addAttributes([.font: UIFont.systemFont(ofSize: fontSize)], range: NSRange(location: 0, length: string.length))

            return string
        } else if (name == "__EMOJO__") {
            guard let emojoImage = resolvedEmojos[text] else {
                return NSAttributedString(string: ":\(text):")
            }

            let emojo = NSTextAttachment()
            emojo.image = emojoImage
            emojo.bounds = CGRect(x: 0, y: -3, width: emojoImage.size.width, height: emojoImage.size.height)

            return NSAttributedString(attachment: emojo)
        } else if (name == "br") {
            return NSAttributedString(string: "\n")
        } else if (name == "strong" || name == "b") {
            let result = NSMutableAttributedString()

            for child in children {
                result.append(child.asNSAttributedString(resolvedEmojos: resolvedEmojos, fontSize: fontSize))
            }

            result.addAttributes([.font: UIFont.boldSystemFont(ofSize: fontSize)], range: NSRange(location: 0, length: result.length))

            return result
        } else if (name == "a") {
            let result = NSMutableAttributedString()

            for child in children {
                result.append(child.asNSAttributedString(resolvedEmojos: resolvedEmojos, fontSize: fontSize))
            }

            if let url = validatedActivityPubLinkURL(attributes["href"]) {
                result.addAttributes([.link: url], range: NSRange(location: 0, length: result.length))
            }

            return result
        } else {
            let result = NSMutableAttributedString()

            for child in children {
                result.append(child.asNSAttributedString(resolvedEmojos: resolvedEmojos, fontSize: fontSize))
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
    let characters = Array(tag)
    var cursor = 0

    func skipWhitespace() {
        while cursor < characters.count, characters[cursor].isWhitespace {
            cursor += 1
        }
    }

    skipWhitespace()

    let tagNameStart = cursor
    while cursor < characters.count,
          !characters[cursor].isWhitespace,
          characters[cursor] != "/" {
        cursor += 1
    }

    guard tagNameStart < cursor else {
        return nil
    }

    let tagName = String(characters[tagNameStart..<cursor]).lowercased()
    let element = HTMLElement(name: tagName)

    while cursor < characters.count {
        skipWhitespace()

        guard cursor < characters.count, characters[cursor] != "/" else {
            break
        }

        let keyStart = cursor
        while cursor < characters.count,
              !characters[cursor].isWhitespace,
              characters[cursor] != "=",
              characters[cursor] != "/" {
            cursor += 1
        }

        guard keyStart < cursor else {
            cursor += 1
            continue
        }

        let key = String(characters[keyStart..<cursor]).lowercased()
        skipWhitespace()

        guard cursor < characters.count, characters[cursor] == "=" else {
            element.attributes[key] = "true"
            continue
        }

        cursor += 1
        skipWhitespace()

        guard cursor < characters.count else {
            element.attributes[key] = ""
            continue
        }

        let value: String
        if characters[cursor] == "\"" || characters[cursor] == "'" {
            let quote = characters[cursor]
            cursor += 1

            let valueStart = cursor
            while cursor < characters.count, characters[cursor] != quote {
                cursor += 1
            }

            value = String(characters[valueStart..<cursor])
            if cursor < characters.count {
                cursor += 1
            }
        } else {
            let valueStart = cursor
            while cursor < characters.count, !characters[cursor].isWhitespace {
                cursor += 1
            }
            value = String(characters[valueStart..<cursor])
        }

        element.attributes[key] = value.decodeHTMLEntity()
    }

    return element
}

func parseEmojo(_ rootText: String) -> HTMLElement {
    let root = HTMLElement(name: "__TEXT_CONTAINER__")
    
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


private let maximumHTMLNestingDepth = 128

private func appendHTMLText(_ text: Substring, to element: HTMLElement) {
    guard !text.isEmpty else {
        return
    }

    let container = parseEmojo(String(text).decodeHTMLEntity())
    if !container.children.isEmpty {
        element.children.append(container)
    }
}

private func endOfHTMLTag(in html: String, startingAt start: String.Index) -> String.Index? {
    var cursor = start
    var quote: Character?

    while cursor < html.endIndex {
        let character = html[cursor]

        if let activeQuote = quote {
            if character == activeQuote {
                quote = nil
            }
        } else if character == "\"" || character == "'" {
            quote = character
        } else if character == ">" {
            return cursor
        }

        cursor = html.index(after: cursor)
    }

    return nil
}

private func closingTagName(_ tag: Substring) -> String? {
    let name = tag
        .dropFirst()
        .drop(while: { $0.isWhitespace })
        .prefix(while: { !$0.isWhitespace && $0 != "/" })

    guard !name.isEmpty else {
        return nil
    }

    return name.lowercased()
}

private let blockElementsRequiringSeparation: Set<String> = ["p", "div"]

func insertActivityPubBlockLineBreaks(in element: HTMLElement) {
    for child in element.children {
        insertActivityPubBlockLineBreaks(in: child)
    }

    guard element.children.count > 1 else {
        return
    }

    for index in element.children.indices.dropLast() {
        let child = element.children[index]
        guard blockElementsRequiringSeparation.contains(child.name) else {
            continue
        }

        let existingLineBreaks = child.children
            .reversed()
            .prefix(while: { $0.name == "br" })
            .count

        for _ in existingLineBreaks..<2 {
            child.children.append(HTMLElement(name: "br"))
        }
    }
}

func parseHTML(_ html: String) -> HTMLElement {
    let root = HTMLElement(name: "body")
    var stack = [root]
    var cursor = html.startIndex

    while cursor < html.endIndex {
        guard let openingBracket = html[cursor...].firstIndex(of: "<") else {
            appendHTMLText(html[cursor...], to: stack[stack.count - 1])
            break
        }

        appendHTMLText(html[cursor..<openingBracket], to: stack[stack.count - 1])

        if html[openingBracket...].hasPrefix("<!--") {
            let commentBody = html.index(openingBracket, offsetBy: 4)
            guard let commentEnd = html.range(of: "-->", range: commentBody..<html.endIndex) else {
                break
            }

            cursor = commentEnd.upperBound
            continue
        }

        let tagStart = html.index(after: openingBracket)
        guard let tagEnd = endOfHTMLTag(in: html, startingAt: tagStart) else {
            appendHTMLText(html[openingBracket...], to: stack[stack.count - 1])
            break
        }

        let tag = html[tagStart..<tagEnd]
        cursor = html.index(after: tagEnd)

        let trimmedTag = tag.drop(while: { $0.isWhitespace })
        guard let firstCharacter = trimmedTag.first else {
            continue
        }

        if firstCharacter == "!" || firstCharacter == "?" {
            continue
        }

        if firstCharacter == "/" {
            guard let tagName = closingTagName(trimmedTag),
                  let matchingIndex = stack.lastIndex(where: { $0.name == tagName }),
                  matchingIndex > stack.startIndex else {
                continue
            }

            // Close the matching element together with any malformed nested
            // elements above it. They were attached when their opening tags
            // were parsed, so no content is lost.
            stack.removeSubrange(matchingIndex...)
            continue
        }

        guard let element = parseTag(String(trimmedTag)) else {
            continue
        }

        stack[stack.count - 1].children.append(element)

        let selfClosing = trimmedTag.last == "/" || element.isSelfClosing
        if !selfClosing, stack.count < maximumHTMLNestingDepth {
            stack.append(element)
        }
    }

    insertActivityPubBlockLineBreaks(in: root)
    return root
}

struct ActivityPubEmojiDefinition: Equatable, Hashable {
    let shortcode: String
    let url: String
}

struct ActivityPubEmojiRenderRequest: Equatable, Hashable {
    let definition: ActivityPubEmojiDefinition
    let pointSize: CGFloat
}

func activityPubEmojiDefinitions(_ emojos: [EmojiAdaptor]) -> [ActivityPubEmojiDefinition] {
    emojos.map {
        ActivityPubEmojiDefinition(shortcode: $0.shortcode, url: $0.url)
    }
}

func referencedActivityPubEmojos(
    in element: HTMLElement,
    definitions: [ActivityPubEmojiDefinition]
) -> [ActivityPubEmojiDefinition] {
    var definitionByShortcode: [String: ActivityPubEmojiDefinition] = [:]
    for definition in definitions where definitionByShortcode[definition.shortcode] == nil {
        definitionByShortcode[definition.shortcode] = definition
    }

    var result: [ActivityPubEmojiDefinition] = []
    var insertedShortcodes: Set<String> = []

    func visit(_ element: HTMLElement) {
        if element.name == "__EMOJO__",
           insertedShortcodes.insert(element.text).inserted,
           let definition = definitionByShortcode[element.text] {
            result.append(definition)
        }

        for child in element.children {
            visit(child)
        }
    }

    visit(element)
    return result
}

struct ActivityPubMarkupText: View, Equatable {
    @Environment(\.appFontMetrics)
    var appFontMetrics: AppFontMetrics

    @State
    var resolvedEmojos: [ActivityPubEmojiRenderRequest: UIImage] = [:]

    var element: HTMLElement
    var emojos: [EmojiAdaptor]

    init(content: String, emojos: [EmojiAdaptor]) {
        self.element = parseHTML(content)
        self.emojos = emojos
    }
    
    init(element: HTMLElement, emojos: [EmojiAdaptor]) {
        self.element = element
        self.emojos = emojos
    }
    
    var body: some View {
        let requests = emojiRenderRequests

        buildTextView(element: element, emojiRequests: requests)
            .font(appFontMetrics.body)
            .task(id: requests) {
                await resolveEmojos(requests)
            }
    }

    private var emojiRenderRequests: [ActivityPubEmojiRenderRequest] {
        referencedActivityPubEmojos(
            in: element,
            definitions: activityPubEmojiDefinitions(emojos)
        ).map {
            ActivityPubEmojiRenderRequest(
                definition: $0,
                pointSize: appFontMetrics.emojiPointSize
            )
        }
    }

    @MainActor
    private func resolveEmojos(_ requests: [ActivityPubEmojiRenderRequest]) async {
        for request in requests where resolvedEmojos[request] == nil {
            guard !Task.isCancelled else {
                return
            }

            guard let image = await CachedImageLoader.shared.loadImage(url: request.definition.url) else {
                print("failed to resolve emojo \"\(request.definition.shortcode)\": (\(request.definition.url))")
                continue
            }

            guard !Task.isCancelled else {
                return
            }

            resolvedEmojos[request] = image.scale(to: request.pointSize)
        }
    }
    
    func buildTextView(
        element: HTMLElement,
        emojiRequests: [ActivityPubEmojiRenderRequest]
    ) -> Text {
        if (element.name == "__TEXT__") {
            return Text(element.text.replacingOccurrences(of: "\\n", with: "", options: .regularExpression))
        } else if (element.name == "__EMOJO__") {
            guard let request = emojiRequests.first(where: { $0.definition.shortcode == element.text }) else {
                return Text(":\(element.text):")
            }

            guard let emojoImage = resolvedEmojos[request] else {
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
                result = result + buildTextView(element: child, emojiRequests: emojiRequests)
            }
            
            return result.bold()
        } else if (element.name == "a") {
            let result = NSMutableAttributedString()
            let imagesByShortcode = Dictionary(
                uniqueKeysWithValues: emojiRequests.compactMap { request in
                    resolvedEmojos[request].map { (request.definition.shortcode, $0) }
                }
            )

            for child in element.children {
                result.append(child.asNSAttributedString(
                    resolvedEmojos: imagesByShortcode,
                    fontSize: appFontMetrics.linkPointSize
                ))
            }

            if let url = validatedActivityPubLinkURL(element.attributes["href"]) {
                result.addAttributes([.link: url], range: NSRange(location: 0, length: result.length))
            }

            return Text(AttributedString(result))
        } else {
            var result: Text = Text("")
            
            for child in element.children {
                result = result + buildTextView(element: child, emojiRequests: emojiRequests)
            }
            
            return result
        }
    }
    
    static func == (lhs: ActivityPubMarkupText, rhs: ActivityPubMarkupText) -> Bool {
        lhs.element == rhs.element &&
        activityPubEmojiDefinitions(lhs.emojos) == activityPubEmojiDefinitions(rhs.emojos)
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
        lhs.content == rhs.content &&
        activityPubEmojiDefinitions(lhs.emojos) == activityPubEmojiDefinitions(rhs.emojos)
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
