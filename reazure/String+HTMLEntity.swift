//
//  String+decodeHTMLEntity.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/12/24.
//

import Foundation

extension String {
    func decodeHTMLEntity() -> String {
        let whitespacePrefix = self.prefix { $0 == " " }
        
        let encodedData = self.data(using: .utf8)!
        let attributedOptions: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        let attributedString = try! NSAttributedString(data: encodedData, options: attributedOptions, documentAttributes: nil)
        
        // whitespace를 복원
        return (whitespacePrefix + attributedString.string)
    }
}
