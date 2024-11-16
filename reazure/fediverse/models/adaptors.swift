//
//  StatusAdaptor.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/16/24.
//

enum StatusVisibility {
    case publicType
    case unlisted
    case privateType
    case direct
}

protocol ApplicationAdaptor {
    var name: String { get }
}

protocol EmojiAdaptor {
    var shortcode: String { get }
    var url: String { get }
}

protocol MentionAdaptor {
    var id: String { get }
    var acct: String { get }
    var username: String { get }
}

protocol AttachmentAdaptor {
    var id: String { get }
    var type: String { get }
    var previewUrl: String? { get }
    var url: String { get }
    var originUrl: String? { get }
}

protocol AccountAdaptor {
    var id: String { get }
    var username: String { get }
    var acct: String { get }
    
    var url: String? { get }
    
    var displayName: String { get }
    var locked: Bool { get }
    var bot: Bool { get }
    
    var avatar: String { get }
    var emojis: [EmojiAdaptor] { get }
}

protocol StatusAdaptor {
    var id: String { get }
    var createdAt: String { get }
    
    var replyToId: String? { get }
    
    var url: String? { get }
    
    var visibility: StatusVisibility { get }
    
    var content: String { get }
    var parsedContent: HTMLElement { get }
    
    var account: AccountAdaptor { get }
    
    var favourited: Bool { get }
    var reblogged: Bool { get }
    
    var reblog: (any StatusAdaptor)? { get }
    
    var emojis: [EmojiAdaptor] { get }
    var mentions: [MentionAdaptor] { get }
    
    var attachments: [AttachmentAdaptor] { get }
    var application: ApplicationAdaptor? { get }
}
