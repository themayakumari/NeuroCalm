//
//  School.swift
//  NeuroCalm
//
//  A school a student can join with a code, plus a Firestore-backed lookup.
//  Each document in `schools` has the code (in capitals) as its id and a `name`
//  field; add them from the admin side. If there's no document with that id,
//  the lookup simply returns nil (no match).
//
//  The student's school is saved to their account in `users/{uid}` (only the
//  school's id and name), so it comes back on a new phone or after a
//  reinstall. This phone keeps a copy in UserDefaults for quick display.
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

        guard isValidCode(normalized) else { return nil }

        let doc = try await Firestore.firestore()
            .collection("schools")
            .document(normalized)
            .getDocument()

        guard let data = doc.data() else { return nil }
        return School(
            id: doc.documentID,
            name: data["name"] as? String ?? "Your school",
            code: normalized
        )
    }

    /// Codes become document ids, so nothing else (like "/") may reach Firestore.
    static func isValidCode(_ code: String) -> Bool {
        code.count <= 64 && code.allSatisfy { $0.isASCII && ($0.isUppercase || $0.isNumber || $0 == "-") }
    }

    // MARK: - Saved on the account

    static let idKey = "schoolId"
    static let nameKey = "schoolName"

    private static func accountDoc(uid: String) -> DocumentReference {
        Firestore.firestore().collection("users").document(uid)
    }

    /// The school saved on this phone, if any.
    static var savedName: String? {
        UserDefaults.standard.string(forKey: nameKey)
    }

    /// Save the school to the account and to this phone.
    static func saveToAccount(_ school: School, uid: String) async throws {
        try await accountDoc(uid: uid).setData([
            "schoolId": school.id,
            "schoolName": String(school.name.prefix(120))
        ])
        storeLocally(id: school.id, name: school.name)
    }

    /// Copy the account's school onto this phone (after signing in).
    /// Leaves this phone alone if the account has no school yet.
    static func restoreFromAccount(uid: String) async throws {
        let doc = try await accountDoc(uid: uid).getDocument()
        guard let data = doc.data(),
              let id = data["schoolId"] as? String,
              let name = data["schoolName"] as? String else { return }
        storeLocally(id: id, name: name)
    }

    /// Remove the school from the account and this phone.
    static func removeFromAccount(uid: String) async throws {
        try await accountDoc(uid: uid).delete()
        clearLocal()
    }

    static func storeLocally(id: String, name: String) {
        UserDefaults.standard.set(id, forKey: idKey)
        UserDefaults.standard.set(name, forKey: nameKey)
    }

    static func clearLocal() {
        UserDefaults.standard.removeObject(forKey: idKey)
        UserDefaults.standard.removeObject(forKey: nameKey)
    }
}
