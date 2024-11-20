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

enum NotificationType {
    case mention
    case status
    case reblog
    case follow
    case followRequest
    case favourite
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

protocol NotificationAdaptor {
    var id: String { get }
    var type: NotificationType { get }
    var createdAt: String { get }
    
    var account: AccountAdaptor? { get }
    var status: StatusAdaptor? { get }
}

class MaskedStatusAdaptor: StatusAdaptor {
    var status: StatusAdaptor
    var favourited: Bool
    var reblogged: Bool
    
    var id: String { status.id }
    var createdAt: String { status.createdAt }
    
    var replyToId: String? { status.replyToId }
    
    var url: String? { status.url }
    
    var visibility: StatusVisibility { status.visibility }
    
    var content: String { status.content }
    var parsedContent: HTMLElement { status.parsedContent }
    
    var account: AccountAdaptor { status.account }
    
    var reblog: (any StatusAdaptor)? { status.reblog }
    
    var emojis: [EmojiAdaptor] { status.emojis }
    var mentions: [MentionAdaptor] { status.mentions }
    
    var attachments: [AttachmentAdaptor] { status.attachments }
    var application: ApplicationAdaptor? { status.application }
    
    init(status: StatusAdaptor, favourited: Bool? = nil, reblogged: Bool? = nil) {
        self.status = status
        self.favourited = favourited ?? status.favourited
        self.reblogged = reblogged ?? status.reblogged
    }
}

extension StatusAdaptor {
    func mask(favourited: Bool? = nil, reblogged: Bool? = nil) -> MaskedStatusAdaptor {
        // check instance of MaskedStatusAdaptor
        if let masked = self as? MaskedStatusAdaptor {
            let favourited = favourited ?? masked.favourited
            let reblogged = reblogged ?? masked.reblogged
            
            return MaskedStatusAdaptor(status: masked.status, favourited: favourited, reblogged: reblogged)
        }
        
        return MaskedStatusAdaptor(status: self, favourited: favourited, reblogged: reblogged)
    }
}
