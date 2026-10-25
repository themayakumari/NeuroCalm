//
//  UserProfile.swift
//  NeuroCalm
//
//  Stores info about the user: name, goals, streak.
//

import Foundation
import SwiftData

// @Model turns a regular Swift class into something
// that SwiftData can save to local storage automatically.
@Model
final class UserProfile {
    var name: String
    var gradeLevel: String
    var hasCompletedOnboarding: Bool
    var currentStreak: Int
    var longestStreak: Int
    var lastCheckInDate: Date?
    var goals: [String]  // e.g. ["Study Focus", "Better Sleep"]

    init(
        name: String = "Student",
        gradeLevel: String = "",
        hasCompletedOnboarding: Bool = false,
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        lastCheckInDate: Date? = nil,
        goals: [String] = []
    ) {
        self.name = name
        self.gradeLevel = gradeLevel
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastCheckInDate = lastCheckInDate
        self.goals = goals
    }
}
