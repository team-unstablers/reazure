//
//  TimelineSortKey.swift
//  reazure
//
//  Created by Gyuhwan Park on 7/13/26.
//

import Foundation

/// Sort key for a timeline row.
///
/// The primary key is the event time, with the id as a tie-breaker. The id
/// string alone is deliberately *not* used as the sort key: unlike a status id,
/// a Mastodon notification id is a plain auto-increment integer on some
/// instances, so a lexicographic comparison flips whenever the digit count
/// grows (e.g. `"999"` vs `"1000"`).
///
/// The event time is whatever the row represents — a status' `createdAt` for a
/// timeline entry, the *notification's* `createdAt` for a notification entry.
/// Parsing happens once at construction, not per comparison.
struct TimelineSortKey: Comparable, Hashable {
    /// A row whose `createdAt` fails to parse sorts as the oldest.
    let date: Date
    let id: String

    init(createdAt: String, id: String) {
        self.date = TimelineSortKey.parseDate(createdAt) ?? .distantPast
        self.id = id
    }

    static func < (lhs: TimelineSortKey, rhs: TimelineSortKey) -> Bool {
        if lhs.date != rhs.date {
            return lhs.date < rhs.date
        }

        return lhs.id < rhs.id
    }

    // Mastodon and Misskey both emit fractional seconds, but the plain
    // formatter is kept as a fallback for instances that omit them.
    private static let fractionalSecondsFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        return formatter
    }()

    private static let internetDateTimeFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        return formatter
    }()

    private static func parseDate(_ string: String) -> Date? {
        return fractionalSecondsFormatter.date(from: string)
            ?? internetDateTimeFormatter.date(from: string)
    }
}
