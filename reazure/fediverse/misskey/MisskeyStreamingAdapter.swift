//
//  MisskeyStreamingAdapter.swift
//  reazure
//
//  Misskey streaming strategy for the shared `StreamingClient`. Speaks Misskey's
//  WebSocket channel protocol, then re-packages inbound notes/notifications into
//  the shared `Mastodon.StreamingEvent` `{event, payload}` envelope so
//  `EventIngestor` (and the whole streaming pipeline) works unchanged.
//

import Foundation

struct MisskeyStreamingAdapter: StreamingProtocolAdapter {
    func url(account: Account, configuration: FediverseServerConfiguration) -> URL {
        // Misskey streams over the same host: wss://<host>/streaming?i=<token>.
        let host = configuration.streamingEndpoint.sanitizeServerAddress()

        var components = URLComponents()
        components.scheme = "wss"
        components.host = host
        components.path = "/streaming"
        components.queryItems = [URLQueryItem(name: "i", value: account.accessToken)]

        return components.url!
    }

    func onConnected(send: (String) -> Void) {
        // Subscribe to the home timeline and the `main` (notifications) channels.
        send(connectFrame(channel: "homeTimeline"))
        send(connectFrame(channel: "main"))
    }

    func translate(text: String) -> Mastodon.StreamingEvent? {
        guard let data = text.data(using: .utf8),
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              root["type"] as? String == "channel",
              let channelBody = root["body"] as? [String: Any],
              let innerType = channelBody["type"] as? String,
              let innerBody = channelBody["body"] else {
            return nil
        }

        // Key on the inner frame type (stateless — no need to track channel ids).
        let event: String
        switch innerType {
        case "note":
            event = "update"
        case "notification":
            event = "notification"
        default:
            return nil
        }

        // The envelope payload must be a JSON *string* (re-parsed by
        // `MisskeyEventDecoder`), so re-serialize the inner body.
        guard let payloadData = try? JSONSerialization.data(withJSONObject: innerBody),
              let payload = String(data: payloadData, encoding: .utf8) else {
            return nil
        }

        return Mastodon.StreamingEvent(event: event, payload: payload)
    }

    private func connectFrame(channel: String) -> String {
        let frame: [String: Any] = [
            "type": "connect",
            "body": [
                "channel": channel,
                "id": UUID().uuidString
            ]
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: frame),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }

        return string
    }
}
