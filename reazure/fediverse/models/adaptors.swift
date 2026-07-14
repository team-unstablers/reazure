//
//  StatusAdaptor.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/16/24.
//

enum StatusVisibility: String, Codable {
    case publicType = "public"
    case unlisted = "unlisted"
    case privateType = "private"
    case direct = "direct"

    var isRebloggable: Bool {
        switch self {
        case .publicType, .unlisted:
            return true
        default:
            return false
        }
    }
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

protocol StatusAdaptor: AnyObject {
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
    
    // extension
    var deleted: Bool { get }
    /// Whether this post is hidden because its author was blocked.
    var blocked: Bool { get }

    var reblog: (any StatusAdaptor)? { get }

    var emojis: [EmojiAdaptor] { get }
    var mentions: [MentionAdaptor] { get }

    var attachments: [AttachmentAdaptor] { get }
    var application: ApplicationAdaptor? { get }
}

extension StatusAdaptor {
    /// No wire format carries a "the reader blocked this author" flag — a blocked
    /// post simply stops being delivered. It only ever becomes `true` through
    /// `MaskedStatusAdaptor`, when a block is applied to rows already on screen,
    /// so every backend adaptor inherits `false` from here.
    var blocked: Bool { false }
}

protocol NotificationAdaptor: AnyObject {
    var id: String { get }
    var type: NotificationType { get }
    var createdAt: String { get }
    
    var account: AccountAdaptor? { get }
    var status: StatusAdaptor? { get }
}

class MaskedStatusAdaptor: StatusAdaptor {
    
    // FIXME: HACK: 난 너무 게을러
    class ReblogMaskedStatusAdaptor: StatusAdaptor {
        // 부모(MaskedStatusAdaptor)가 이 인스턴스를 강참조로 소유하므로,
        // 역참조는 unowned로 두어 마스크 쌍의 순환 참조를 방지한다.
        unowned var _parent: MaskedStatusAdaptor
        
        var status: StatusAdaptor {
            return _parent.status.reblog!
        }
        
        var favourited: Bool {
            _parent.favourited
        }
        var reblogged: Bool {
            _parent.reblogged
        }
        
        var deleted: Bool {
            _parent.deleted
        }

        var blocked: Bool {
            _parent.blocked
        }

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
        
        init(_ parent: MaskedStatusAdaptor) {
            self._parent = parent
        }
    }
    
    var status: StatusAdaptor
    
    var reblog: (any StatusAdaptor)?
    
    var favourited: Bool
    var reblogged: Bool

    var deleted: Bool
    var blocked: Bool

    var id: String { status.id }
    var createdAt: String { status.createdAt }
    
    var replyToId: String? { status.replyToId }
    
    var url: String? { status.url }
    
    var visibility: StatusVisibility { status.visibility }
    
    var content: String { status.content }
    var parsedContent: HTMLElement { status.parsedContent }
    
    var account: AccountAdaptor { status.account }
    
    
    var emojis: [EmojiAdaptor] { status.emojis }
    var mentions: [MentionAdaptor] { status.mentions }
    
    var attachments: [AttachmentAdaptor] { status.attachments }
    var application: ApplicationAdaptor? { status.application }
    
    init(status: StatusAdaptor, favourited: Bool? = nil, reblogged: Bool? = nil, deleted: Bool? = nil, blocked: Bool? = nil) {
        self.status = status

        self.favourited = favourited ?? status.favourited
        self.reblogged = reblogged ?? status.reblogged
        self.deleted = deleted ?? false
        self.blocked = blocked ?? false

        if let reblog = status.reblog {
            self.reblog = ReblogMaskedStatusAdaptor(self)
        }
    }
}

