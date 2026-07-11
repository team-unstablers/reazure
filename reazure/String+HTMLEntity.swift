//
//  String+decodeHTMLEntity.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/12/24.
//

import Foundation

fileprivate let ENTITY_TABLES = [
    "amp": "&",
    "lt": "<",
    "gt": ">",
    "quot": "\"",
    "apos": "'",
    
    "nbsp": " ",
    "iexcl": "¡",
    "cent": "¢",
    "pound": "£",
    "curren": "¤",
    "yen": "¥",
    "brvbar": "¦",
    "sect": "§",
    "uml": "¨",
    "copy": "©",
    "ordf": "ª",
    "laquo": "«",
    "not": "¬",
    "shy": "­",
    "reg": "®",
    "macr": "¯",
    "deg": "°",
    "plusmn": "±",
    "sup2": "²",
    "sup3": "³",
    "acute": "´",
    "micro": "µ",
    "para": "¶",
    "cedil": "¸",
    "sup1": "¹",
    "ordm": "º",
    "raquo": "»",
    "frac14": "¼",
    "frac12": "½",
    "frac34": "¾",
    "iquest": "¿",
    "times": "×",
    "divide": "÷",
    
    "forall": "∀",
    "part": "∂",
    "exist": "∃",
    "empty": "∅",
    "nabla": "∇",
    "isin": "∈",
    "notin": "∉",
    "ni": "∋",
    "prod": "∏",
    "sum": "∑",
    "minus": "−",
    "lowast": "∗",
    "radic": "√",
    "prop": "∝",
    "infin": "∞",
    "ang": "∠",
    "and": "∧",
    "or": "∨",
    "cap": "∩",
    "cup": "∪",
    "int": "∫",
    "there4": "∴",
    "sim": "∼",
    "cong": "≅",
    "asymp": "≈",
    "ne": "≠",
    "equiv": "≡",
    "le": "≤",
    "ge": "≥",
    "sub": "⊂",
    "sup": "⊃",
    "nsub": "⊄",
    "sube": "⊆",
    "supe": "⊇",
    "oplus": "⊕",
    "otimes": "⊗",
    "perp": "⊥",
    "sdot": "⋅",
]

extension String {
    func decodeHTMLEntity() -> String {
        var result = ""
        var cursor = startIndex

        while let ampersand = self[cursor...].firstIndex(of: "&") {
            result.append(contentsOf: self[cursor..<ampersand])

            let entityStart = index(after: ampersand)
            guard let semicolon = self[entityStart...].firstIndex(of: ";") else {
                result.append(contentsOf: self[ampersand...])
                return result
            }

            let entity = self[entityStart..<semicolon]

            // A second ampersand means the first one was not a complete entity.
            // Preserve it and let the next loop decode the later candidate.
            guard entity.count <= 64, !entity.contains("&") else {
                result.append("&")
                cursor = entityStart
                continue
            }

            let decoded: String?

            if entity.hasPrefix("#x") || entity.hasPrefix("#X") {
                decoded = UInt32(entity.dropFirst(2), radix: 16)
                    .flatMap(UnicodeScalar.init)
                    .map(String.init)
            } else if entity.hasPrefix("#") {
                decoded = UInt32(entity.dropFirst(), radix: 10)
                    .flatMap(UnicodeScalar.init)
                    .map(String.init)
            } else {
                decoded = ENTITY_TABLES[String(entity)]
            }

            if let decoded {
                result.append(decoded)
            } else {
                result.append(contentsOf: self[ampersand...semicolon])
            }

            cursor = index(after: semicolon)
        }

        result.append(contentsOf: self[cursor...])
        return result
    }
}
