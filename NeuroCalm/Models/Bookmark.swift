//
//  Bookmark.swift
//  NeuroCalm
//
//  A saved/favorited item. Generic on purpose (kind + referenceId) so it can
//  point at any content type later; for now it's used to favorite relaxation
//  tracks so they're one tap away.
//

import Foundation
import SwiftData

@Model
final class Bookmark {
    var kind: String        // e.g. "meditation"
    var referenceId: String // the content's id, e.g. a MeditationTrack.id
    var title: String
    var subtitle: String
    var dateAdded: Date

    init(kind: String, referenceId: String, title: String, subtitle: String, dateAdded: Date = Date()) {
        self.kind = kind
        self.referenceId = referenceId
        self.title = title
        self.subtitle = subtitle
        self.dateAdded = dateAdded
    }
}

extension Bookmark {
    static let meditationKind = "meditation"
}
