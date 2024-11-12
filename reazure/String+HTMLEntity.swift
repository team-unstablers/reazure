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
        let scanner = Scanner(string: self)
        scanner.charactersToBeSkipped = nil
        
        var result = ""
        
        while !scanner.isAtEnd {
            if let string = scanner.scanUpToString("&") {
                result.append(string)
            }
            
            if scanner.scanString("&") != nil {
                if let entity = scanner.scanUpToString(";") {
                    if entity.hasPrefix("#x") {
                        if let code = UInt32(entity.dropFirst(2), radix: 16) {
                            result.append(String(UnicodeScalar(code)!))
                        }
                    } else if entity.hasPrefix("#") {
                        if let code = UInt32(entity.dropFirst(), radix: 10) {
                            result.append(String(UnicodeScalar(code)!))
                        }
                    } else {
                        if let decoded = ENTITY_TABLES[entity] {
                            result.append(decoded)
                        } else {
                            result.append("&\(entity);")
                        }
                    }
                }
                
                scanner.scanString(";")
            }
        }
        
        return result
    }
}
