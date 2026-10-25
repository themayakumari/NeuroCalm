//
//  TeamService.swift
//  NeuroCalm
//
//  Firestore-backed team challenges: create (get a join code), join by code,
//  push your own progress, and fetch everyone's. Small groups, so members live
//  in a single map field on the challenge doc — one read gets the whole board.
//
//  Firestore setup (once, in the Firebase console):
//    1. Create a Firestore database.
//    2. Rules — allow signed-in users to read/write the shared challenges:
//         match /teamChallenges/{id} {
//           allow read, create: if request.auth != null;
//           allow update: if request.auth != null;   // members update their own count
//         }
//

import Foundation
import FirebaseFirestore

enum TeamError: LocalizedError {
    case notSignedIn
    case notFound

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "Sign in to use team challenges."
        case .notFound:    return "We couldn't find a challenge with that code."
        }
    }
}

enum TeamService {
    private static var collection: CollectionReference {
        Firestore.firestore().collection("teamChallenges")
    }

    /// Create a shared challenge; the creator is the first member. Returns it.
    static func create(template: ChallengeTemplate, uid: String, name: String) async throws -> TeamChallenge {
        let code = randomCode()
        let ref = collection.document()
        let data: [String: Any] = [
            "code": code,
            "templateId": template.id,
            "title": template.title,
            "startDate": Timestamp(date: Date()),
            "createdBy": uid,
            "members": [uid: ["name": name, "current": 0]]
        ]
        try await ref.setData(data)
        return try await fetch(id: ref.documentID)
    }

    /// Join a challenge by its code. Returns the joined challenge.
    static func join(code: String, uid: String, name: String) async throws -> TeamChallenge {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let snapshot = try await collection.whereField("code", isEqualTo: normalized).limit(to: 1).getDocuments()
        guard let doc = snapshot.documents.first else { throw TeamError.notFound }
        try await doc.reference.updateData(["members.\(uid)": ["name": name, "current": 0]])
        return try await fetch(id: doc.documentID)
    }

    /// Update only this member's progress count.
    static func updateProgress(id: String, uid: String, current: Int) async throws {
        try await collection.document(id).updateData(["members.\(uid).current": current])
    }

    static func fetch(id: String) async throws -> TeamChallenge {
        let doc = try await collection.document(id).getDocument()
        guard let data = doc.data() else { throw TeamError.notFound }
        return decode(id: doc.documentID, data)
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

    /// A short, unambiguous join code (no easily-confused characters).
    private static func randomCode() -> String {
        let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).map { _ in chars.randomElement()! })
    }
}
