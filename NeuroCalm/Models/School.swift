//
//  School.swift
//  NeuroCalm
//
//  A school a student can join with a code, plus a Firestore-backed lookup.
//  The `schools` collection just needs documents with `name` and `code`
//  fields; populate it from the admin side. If Firestore is empty/disabled
//  the lookup simply returns nil (no match).
//

import Foundation
import FirebaseFirestore

struct School: Identifiable, Hashable {
    let id: String
    let name: String
    let code: String
}

enum SchoolService {
    /// Look up a school by its join code (case-insensitive).
    static func findSchool(code: String) async throws -> School? {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalized.isEmpty else { return nil }

        let snapshot = try await Firestore.firestore()
            .collection("schools")
            .whereField("code", isEqualTo: normalized)
            .limit(to: 1)
            .getDocuments()

        guard let doc = snapshot.documents.first else { return nil }
        let data = doc.data()
        return School(
            id: doc.documentID,
            name: data["name"] as? String ?? "Your school",
            code: normalized
        )
    }
}
