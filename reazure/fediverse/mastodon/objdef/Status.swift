//
//  Status.swift
//  reazure
//
//  Created by cheesekun on 11/3/24.
//


extension Mastodon {
    struct Visibility: RawRepresentable, Codable, Equatable, Hashable {
        var rawValue: String
        
        init(rawValue: String) {
            self.rawValue = rawValue
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            rawValue = try container.decode(String.self)
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(rawValue)
        }
        
        static let publicType = Visibility(rawValue: "public")
        static let unlisted = Visibility(rawValue: "unlisted")
        static let privateType = Visibility(rawValue: "private")
        static let direct = Visibility(rawValue: "direct")
    }
    
    struct CustomEmoji: Codable {
        let shortcode: String
        let url: String
        let static_url: String
    }
    
    struct Application: Codable {
        let name: String
    }
    
    struct Mention: Codable {
        let id: String
        let username: String
        let acct: String
    }
    
    struct MediaAttachment: Codable {
        let id: String
        let type: String
        let url: String?
        let preview_url: String?
        let remote_url: String?
    }
    
    struct Status: Codable {
        let id: String
        let created_at: String
        
        let in_reply_to_id: String?
        
        let url: String?
        
        let visibility: Visibility
        
        let content: String
        let account: UserProfile
        
        var favourited: Bool
        var reblogged: Bool
        
        let reblog: Box<Status>?
        
        let emojis: [CustomEmoji]
        let mentions: [Mention]
        
        let media_attachments: [MediaAttachment]
        
        let application: Application?
    }
    
    struct Notification: Codable {
        let id: String
        let type: String
        let created_at: String
        
        let account: UserProfile?
        let status: Status?
    }
}


extension Mastodon.Status: Hashable, Equatable, Identifiable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func ==(lhs: Mastodon.Status, rhs: Mastodon.Status) -> Bool {
        return lhs.id == rhs.id
    }
}

extension Mastodon.Status {
    func mentions(id: String) -> Bool {
        return mentions.contains(where: { $0.id == id })
    }
}


extension Mastodon.Notification: Hashable, Equatable, Identifiable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func ==(lhs: Mastodon.Notification, rhs: Mastodon.Notification) -> Bool {
        return lhs.id == rhs.id
    }
}

extension StatusVisibility {
    init(_ visibility: Mastodon.Visibility) {
        switch visibility {
        case .publicType:
            self = .publicType
        case .unlisted:
            self = .unlisted
        case .privateType:
            self = .privateType
        case .direct:
            self = .direct
        default:
            self = .publicType
        }
    }
}

class MastodonEmojiAdaptor: EmojiAdaptor {
    private let _emoji: Mastodon.CustomEmoji
    
    var shortcode: String { _emoji.shortcode }
    var url: String { _emoji.url }
    
    init(from emoji: Mastodon.CustomEmoji) {
        _emoji = emoji
    }
}

class MastodonMentionAdaptor: MentionAdaptor {
    private let _mention: Mastodon.Mention
    
    var id: String { _mention.id }
    var username: String { _mention.username }
    var acct: String { _mention.acct }
    
    init(from mention: Mastodon.Mention) {
        _mention = mention
    }
}

class MastodonAttachmentAdaptor: AttachmentAdaptor {
    private let _attachment: Mastodon.MediaAttachment
    
    var id: String { _attachment.id }
    var type: String { _attachment.type }
    var url: String { _attachment.url! }
    var previewUrl: String? { _attachment.preview_url }
    var originUrl: String? { _attachment.remote_url }
    
    init(from attachment: Mastodon.MediaAttachment) {
        _attachment = attachment
    }
}

class MastodonApplicationAdaptor: ApplicationAdaptor {
    private let _application: Mastodon.Application
    
    var name: String { _application.name }
    
    init(from application: Mastodon.Application) {
        _application = application
    }
}


class MastodonStatusAdaptor: StatusAdaptor {
    let _status: Mastodon.Status
    
    var id: String { _status.id }
    var createdAt: String { _status.created_at }
    
    var replyToId: String? { _status.in_reply_to_id }
    
    var url: String? { _status.url }
    
    var visibility: StatusVisibility
    
    var content: String { _status.content }
    var parsedContent: HTMLElement
    
    var account: AccountAdaptor
    
    var favourited: Bool { _status.favourited }
    var reblogged: Bool { _status.reblogged }
    
    var reblog: (any StatusAdaptor)?
    
    var emojis: [EmojiAdaptor]
    var mentions: [MentionAdaptor]
    
    var attachments: [AttachmentAdaptor]
    var application: ApplicationAdaptor?
    
    init(from status: Mastodon.Status) {
        self._status = status
        
        self.visibility = StatusVisibility(self._status.visibility)
        self.parsedContent = parseHTML(self._status.content)
        self.account = MastodonAccountAdaptor(from: self._status.account)
        self.emojis = self._status.emojis.map { MastodonEmojiAdaptor(from: $0) }
        self.mentions = self._status.mentions.map { MastodonMentionAdaptor(from: $0) }
        self.attachments = self._status.media_attachments.map { MastodonAttachmentAdaptor(from: $0) }
        
        if let reblog = self._status.reblog {
            self.reblog = MastodonStatusAdaptor(from: reblog.wrappedValue)
        }
        
        if let application = self._status.application {
            self.application = MastodonApplicationAdaptor(from: application)
        }
    }
}
