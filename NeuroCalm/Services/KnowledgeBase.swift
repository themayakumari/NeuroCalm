//
//  KnowledgeBase.swift
//  NeuroCalm
//
//  A small on-device knowledge base of traditional yoga breathing and
//  relaxation practices. It grounds the assistant: for a given question it finds
//  the most relevant practices and hands their text to the assistant as source
//  material, so replies stay faithful to the practices.
//
//  The practices come from the content file in Firebase Storage (see
//  ContentService), saved on the phone at the last launch. Edit that file to
//  change or add practices, no app update needed. Resources/Knowledge/
//  practices.json is the bundled backup used until a download succeeds.
//

import Foundation

struct Practice: Codable, Identifiable {
    let id: String
    let name: String
    let aliases: [String]
    let goodFor: [String]
    let summary: String
    let teen: String?          // short, teen-friendly (14–19) explanation
    let category: String       // "Breathing techniques" / "Relaxation techniques" / "Short meditation practices"
    let animation: String?     // animation style key (breathe / alternate / hum / wave / settle / ripple)
    let audio: String?         // bundled guided-audio filename, if any (else a placeholder shows)
    let audioTrackIds: [String]?  // MeditationLibrary track ids to play under this practice
    let content: String
    let source: String

    /// The teen-friendly blurb, falling back to the plain summary.
    var teenFriendly: String {
        if let teen, !teen.isEmpty { return teen }
        return summary
    }
}

final class KnowledgeBase {
    static let shared = KnowledgeBase()

    let practices: [Practice]

    private init() {
        if let saved = ContentService.savedContent()?.practices, !saved.isEmpty {
            practices = saved
            return
        }
        let url = Bundle.main.url(forResource: "practices", withExtension: "json", subdirectory: "Knowledge")
            ?? Bundle.main.url(forResource: "practices", withExtension: "json")
        if let url, let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([Practice].self, from: data) {
            practices = decoded
        } else {
            practices = []
        }
    }

    /// Rank practices by how well they match the question.
    func search(_ query: String, limit: Int = 2) -> [Practice] {
        let q = query.lowercased()
        let words = Set(
            q.split(whereSeparator: { !$0.isLetter })
                .map(String.init)
                .filter { $0.count > 2 }
        )

        func score(_ p: Practice) -> Int {
            var s = 0
            let name = p.name.lowercased()
            if q.contains(name) { s += 5 }
            for alias in p.aliases where q.contains(alias.lowercased()) { s += 4 }
            for tag in p.goodFor {
                let t = tag.lowercased()
                if q.contains(t) || words.contains(t) { s += 2 }
            }
            for w in words where name.contains(w) { s += 1 }
            return s
        }

        return practices
            .map { (practice: $0, score: score($0)) }
            .filter { $0.score > 0 }
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0.practice }
    }

    /// Source-material block to ground the assistant, or nil if nothing matches.
    func grounding(for query: String) -> String? {
        let hits = search(query)
        guard !hits.isEmpty else { return nil }
        return hits
            .map { "\($0.name) — \($0.source)\n\($0.content)" }
            .joined(separator: "\n\n")
    }
}
