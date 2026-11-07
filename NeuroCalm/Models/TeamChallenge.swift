//
//  TeamChallenge.swift
//  NeuroCalm
//
//  Shared "with friends" challenges. The challenge itself lives in Firestore so
//  everyone sees each other's progress; only which challenges *this* device has
//  joined is kept locally (TeamMembership). Each member's private data (their
//  CalmLog) never leaves the device — only their challenge `current` count is
//  shared.
//

import Foundation
import SwiftData

/// One member's standing on a team challenge (from Firestore).
struct MemberProgress: Identifiable, Hashable {
    let id: String        // uid
    let name: String
    let current: Int
}

/// A shared challenge fetched from Firestore.
struct TeamChallenge: Identifiable {
    let id: String
    let code: String
    let templateId: String
    let title: String
    let startDate: Date
    let createdBy: String
    let members: [MemberProgress]   // sorted, highest first

    var template: ChallengeTemplate? { ChallengeCatalog.template(id: templateId) }
}

/// People this student blocked on team leaderboards. Kept on this phone only,
/// so the blocked person never finds out.
enum BlockedMembers {
    static let key = "blockedTeamMembers"

    /// The saved list is uids joined by commas (uids never contain one).
    static func ids(from raw: String) -> Set<String> {
        Set(raw.split(separator: ",").map(String.init))
    }

    static func raw(from ids: Set<String>) -> String {
        ids.sorted().joined(separator: ",")
    }

    /// The leaderboard without anyone this student blocked.
    static func visible(_ members: [MemberProgress], raw: String) -> [MemberProgress] {
        let blocked = ids(from: raw)
        return members.filter { !blocked.contains($0.id) }
    }
}

/// Local record of a team challenge this device has joined (so we know which to show).
@Model
final class TeamMembership {
    var challengeId: String
    var title: String
    var joinedAt: Date

    init(challengeId: String, title: String) {
        self.challengeId = challengeId
        self.title = title
        self.joinedAt = .now
    }
}
