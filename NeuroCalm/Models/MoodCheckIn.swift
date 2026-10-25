//
//  MoodCheckIn.swift
//  NeuroCalm
//

import Foundation
import SwiftData

@Model
final class MoodCheckIn {
    var date: Date
    var mood: String        // calm, okay, stressed, overwhelmed, tired
    var stressLevel: Int    // 1 (low) ... 5 (very high)
    var notes: String

    init(date: Date = Date(), mood: String, stressLevel: Int, notes: String = "") {
        self.date = date
        self.mood = mood
        self.stressLevel = stressLevel
        self.notes = notes
    }
}

/// The set of moods the user can choose from.
enum Mood: String, CaseIterable, Identifiable {
    case calm
    case okay
    case stressed
    case overwhelmed
    case tired

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .calm: return "😌"
        case .okay: return "🙂"
        case .stressed: return "😟"
        case .overwhelmed: return "😫"
        case .tired: return "😴"
        }
    }

    var label: String {
        rawValue.capitalized
    }
}
