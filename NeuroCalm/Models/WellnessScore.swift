//
//  WellnessScore.swift
//  NeuroCalm
//
//  Pure, testable logic for the weekly "Brain Wellness Score" shown on
//  the Progress tab. Kept out of the view so it can be unit-tested.
//

import Foundation

enum WellnessScore {

    /// A 0–100 score weighting this week's activity:
    /// breathing sessions (up to 40), tasks completed (up to 30),
    /// and mood check-ins (up to 30).
    static func compute(breathingSessions: Int, tasksCompleted: Int, checkIns: Int) -> Int {
        let b = min(max(breathingSessions, 0) * 10, 40)
        let t = min(max(tasksCompleted, 0) * 5, 30)
        let c = min(max(checkIns, 0) * 5, 30)
        return b + t + c
    }

    /// A short encouraging line matched to the score band.
    static func message(for score: Int) -> String {
        switch score {
        case ..<25: return "A small start counts. One session today goes a long way."
        case 25..<50: return "You're building momentum — keep showing up."
        case 50..<75: return "Strong week. Your brain thanks you."
        default: return "Outstanding week. Take pride in this."
        }
    }
}
