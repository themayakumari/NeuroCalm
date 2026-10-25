//
//  BreathingSession.swift
//  NeuroCalm
//

import Foundation
import SwiftData

@Model
final class BreathingSession {
    var date: Date
    var durationSeconds: Int
    var technique: String   // "box", "deep", "alternate"
    var moodBefore: String?
    var moodAfter: String?

    init(
        date: Date = Date(),
        durationSeconds: Int,
        technique: String,
        moodBefore: String? = nil,
        moodAfter: String? = nil
    ) {
        self.date = date
        self.durationSeconds = durationSeconds
        self.technique = technique
        self.moodBefore = moodBefore
        self.moodAfter = moodAfter
    }
}

/// A breathing ratio the user can pick before a session — the relative
/// lengths of inhale : (hold) : exhale : (hold). Produces the same
/// `(inhale, hold1, exhale, hold2)` shape the animation engine already uses,
/// so it drops straight into `BreathingView`.
enum BreathingRatio: String, CaseIterable, Identifiable {
    case oneToOne          // 1:1   — balanced
    case oneToTwo          // 1:2   — longer, calming exhale
    case equalHold         // 1:1:1 — inhale, hold, exhale
    case box               // 1:1:1:1
    case fourSevenEight    // 4-7-8 — classic relaxation pattern

    var id: String { rawValue }

    /// The base seconds for one "1" in the ratio. A comfortable default count.
    static let unitSeconds = 4

    /// Compact ratio label, e.g. "1:1", "1:2", "4-7-8".
    var ratioLabel: String {
        switch self {
        case .oneToOne: return "1:1"
        case .oneToTwo: return "1:2"
        case .equalHold: return "1:1:1"
        case .box: return "1:1:1:1"
        case .fourSevenEight: return "4-7-8"
        }
    }

    var title: String {
        switch self {
        case .oneToOne: return "Balanced"
        case .oneToTwo: return "Longer exhale"
        case .equalHold: return "Inhale · hold · exhale"
        case .box: return "Box breathing"
        case .fourSevenEight: return "4-7-8 relax"
        }
    }

    var description: String {
        switch self {
        case .oneToOne: return "Even in, even out — a steady, balanced rhythm."
        case .oneToTwo: return "A longer exhale than inhale to settle the body."
        case .equalHold: return "Breathe in, hold, breathe out — equal counts."
        case .box: return "In, hold, out, hold — all equal. Calms the nerves."
        case .fourSevenEight: return "Inhale 4, hold 7, exhale 8 — deeply relaxing."
        }
    }

    /// Per-phase seconds: inhale, hold1, exhale, hold2 (0 = skipped).
    var phases: (inhale: Int, hold1: Int, exhale: Int, hold2: Int) {
        let u = Self.unitSeconds
        switch self {
        case .oneToOne:       return (u, 0, u, 0)
        case .oneToTwo:       return (u, 0, u * 2, 0)
        case .equalHold:      return (u, u, u, 0)
        case .box:            return (u, u, u, u)
        case .fourSevenEight: return (4, 7, 8, 0)   // fixed, not unit-scaled
        }
    }
}

/// Preset session lengths offered before a breathing session, in minutes.
enum BreathingDuration: Int, CaseIterable, Identifiable {
    case one = 1, two = 2, three = 3, five = 5

    var id: Int { rawValue }
    var minutes: Int { rawValue }
    var seconds: Int { rawValue * 60 }
    var label: String { "\(rawValue) min" }
}
