//
//  TeamService.swift
//  NeuroCalm
//
//  Firestore-backed team challenges: create (get a join code), join by code,
//  push your own progress, and fetch everyone's. Small groups, so members live
//  in a single map field on the challenge doc — one read gets the whole board.
//  The join code is the document id, and only members can read a challenge.
//
//  Firestore setup (once): create a Firestore database, then deploy the
//  security rules in `firestore.rules` at the repo root. They only let each
//  member change their own entry in `members`.
//

import Foundation
import FirebaseFirestore

enum TeamError: LocalizedError {
    case notSignedIn
    case notFound
    case nameNotAllowed

    var errorDescription: String? {
        switch self {
        case .notSignedIn:    return "Sign in to use team challenges."
        case .notFound:       return "We couldn't find a challenge with that code."
        case .nameNotAllowed: return "Please pick a different leaderboard name. Offensive names aren't allowed."
        }
    }
}

enum TeamService {
    private static var collection: CollectionReference {
        Firestore.firestore().collection("teamChallenges")
    }

    /// Longest name shown on a leaderboard (matches `firestore.rules`).
    static let maxNameLength = 60

    /// The challenges a student is in, kept on their account (`title` only).
    private static func accountList(uid: String) -> CollectionReference {
        Firestore.firestore().collection("users").document(uid).collection("teamChallenges")
    }

    /// Create a shared challenge; the creator is the first member. Returns it.
    /// The join code is the document id, so a code already in use is refused
    /// by the rules and another one is tried.
    static func create(template: ChallengeTemplate, uid: String, name: String) async throws -> TeamChallenge {
        guard isNameAllowed(name) else { throw TeamError.nameNotAllowed }
        var attempts = 0
        while true {
            attempts += 1
            let code = randomCode()
            let data: [String: Any] = [
                "code": code,
                "templateId": template.id,
                "title": template.title,
                "startDate": Timestamp(date: Date()),
                "createdBy": uid,
                "members": [uid: ["name": leaderboardName(name), "current": 0]]
            ]
            // On the account first, so nobody is ever a member it can't clean up.
            try await accountList(uid: uid).document(code).setData(["title": template.title])
            do {
                try await collection.document(code).setData(data)
                return try await fetch(id: code)
            } catch {
                try? await accountList(uid: uid).document(code).delete()
                guard isDenied(error), attempts < 5 else { throw error }
            }
        }
    }

    /// Join a challenge by its code. Returns the joined challenge. Joining one
    /// you're already in keeps your progress and just updates your name.
    /// Only members can read a challenge, so a refused read means "not in it yet".
    static func join(code: String, uid: String, name: String) async throws -> TeamChallenge {
        guard isNameAllowed(name) else { throw TeamError.nameNotAllowed }
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard isValidCode(normalized) else { throw TeamError.notFound }
        let ref = collection.document(normalized)
        var title = ""
        do {
            let doc = try await ref.getDocument()
            title = doc.data()?["title"] as? String ?? ""
            try await ref.updateData(["members.\(uid).name": leaderboardName(name)])
        } catch where isDenied(error) {
            try await accountList(uid: uid).document(normalized).setData(["title": title])
            do {
                try await ref.updateData(["members.\(uid)": ["name": leaderboardName(name), "current": 0]])
            } catch {
                try? await accountList(uid: uid).document(normalized).delete()
                throw isDenied(error) ? TeamError.notFound : error
            }
        }
        let joined = try await fetch(id: normalized)
        try await accountList(uid: uid).document(normalized).setData(["title": joined.title])
        return joined
    }

    /// Update only this member's progress count.
    static func updateProgress(id: String, uid: String, current: Int) async throws {
        try await collection.document(id).updateData(["members.\(uid).current": current])
    }

    /// Remove this member from a challenge (leaving it, or deleting an account).
    /// The last member removes the whole challenge, and a creator who leaves
    /// clears their id from it.
    static func leave(id: String, uid: String) async throws {
        let ref = collection.document(id)
        let doc: DocumentSnapshot
        do {
            doc = try await ref.getDocument()
        } catch where isDenied(error) {
            try? await accountList(uid: uid).document(id).delete()
            throw TeamError.notFound
        }
        guard let data = doc.data() else {
            try? await accountList(uid: uid).document(id).delete()
            throw TeamError.notFound
        }
        let members = data["members"] as? [String: Any] ?? [:]
        if Set(members.keys) == [uid] {
            try await ref.delete()
        } else {
            var changes: [String: Any] = ["members.\(uid)": FieldValue.delete()]
            if data["createdBy"] as? String == uid { changes["createdBy"] = "" }
            try await ref.updateData(changes)
        }
        try await accountList(uid: uid).document(id).delete()
    }

    /// Every challenge saved on the account: (id, title).
    static func accountChallenges(uid: String) async throws -> [(id: String, title: String)] {
        try await accountList(uid: uid).getDocuments().documents.map {
            (id: $0.documentID, title: $0.data()["title"] as? String ?? "Challenge")
        }
    }

    /// Report a leaderboard name. Reports go to the `reports` collection, which
    /// only the Firebase console can read; remove the name there if it breaks the rules.
    static func report(challengeId: String, member: MemberProgress, reporterUid: String) async throws {
        try await Firestore.firestore().collection("reports").addDocument(data: [
            "challengeId": challengeId,
            "reportedUid": member.id,
            "reportedName": member.name,
            "reporterUid": reporterUid,
            "createdAt": FieldValue.serverTimestamp()
        ])
    }

    static func fetch(id: String) async throws -> TeamChallenge {
        do {
            let doc = try await collection.document(id).getDocument()
            guard let data = doc.data() else { throw TeamError.notFound }
            return decode(id: doc.documentID, data)
        } catch where isDenied(error) {
            // Removed, or no longer a member.
            throw TeamError.notFound
        }
    }

    // MARK: - Helpers

    private static func decode(id: String, _ data: [String: Any]) -> TeamChallenge {
        let rawMembers = data["members"] as? [String: [String: Any]] ?? [:]
        let members = rawMembers.map { uid, m in
            MemberProgress(id: uid, name: m["name"] as? String ?? "Friend", current: m["current"] as? Int ?? 0)
        }.sorted { $0.current > $1.current }

        return TeamChallenge(
            id: id,
            code: data["code"] as? String ?? "",
            templateId: data["templateId"] as? String ?? "",
            title: data["title"] as? String ?? "Challenge",
            startDate: (data["startDate"] as? Timestamp)?.dateValue() ?? Date(),
            createdBy: data["createdBy"] as? String ?? "",
            members: members
        )
    }

    /// Trim a display name so it always passes the rules.
    static func leaderboardName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Friend" : String(trimmed.prefix(maxNameLength))
    }

    // MARK: - Name filter

    /// Whole words that can't be used in a leaderboard name.
    private static let blockedWords: Set<String> = [
        "ass", "asshole", "bastard", "bitch", "bullshit", "cock", "cunt", "dick", "dyke",
        "fag", "faggot", "fuck", "hitler", "kike", "nazi", "nigga", "nigger", "penis",
        "porn", "pussy", "rape", "rapist", "retard", "shit", "shithead", "slut", "spic",
        "tits", "twat", "vagina", "wank", "wanker", "whore"
    ]

    /// Words that can't appear anywhere in a name, even inside a longer word.
    private static let blockedParts = ["asshole", "bitch", "faggot", "fuck", "motherf", "nigga", "nigger"]

    /// False if a name contains an offensive word, including common disguises
    /// like "f u c k" or "sh1t". Empty names are fine (they become "Friend").
    static func isNameAllowed(_ name: String) -> Bool {
        let swaps: [Character: Character] = ["0": "o", "1": "i", "3": "e", "4": "a", "5": "s", "7": "t",
                                             "@": "a", "$": "s", "!": "i"]
        let folded = name.lowercased().folding(options: .diacriticInsensitive, locale: nil)
        let plain = String(folded.map { swaps[$0] ?? $0 })
        let words = plain.split { !$0.isLetter }.map(String.init)
        let joined = words.joined()
        return !words.contains(where: blockedWords.contains)
            && !blockedWords.contains(joined)
            && !blockedParts.contains(where: joined.contains)
    }

    /// True for a code the app could have made. Codes become document ids, so
    /// nothing else (like "/") may reach Firestore.
    static func isValidCode(_ code: String) -> Bool {
        code.count == 6 && code.allSatisfy { $0.isASCII && ($0.isUppercase || $0.isNumber) }
    }

    /// The rules refused this, or the document isn't there.
    private static func isDenied(_ error: Error) -> Bool {
        let error = error as NSError
        return error.domain == FirestoreErrorDomain
            && (error.code == FirestoreErrorCode.permissionDenied.rawValue
                || error.code == FirestoreErrorCode.notFound.rawValue)
    }

    /// A short, unambiguous join code (no easily-confused characters).
    private static func randomCode() -> String {
        let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).map { _ in chars.randomElement()! })
    }
}
