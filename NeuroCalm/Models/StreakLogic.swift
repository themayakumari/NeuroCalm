//
//  StreakLogic.swift
//  NeuroCalm
//
//  Pure, testable streak math. Extracted from the views so the rules
//  (advance, hold, reset) are documented by tests rather than buried in a
//  save() call. This also fixes the old behaviour, which incremented the
//  streak on every check-in even after days were missed.
//

import Foundation

enum StreakLogic {

    struct Result: Equatable {
        let currentStreak: Int
        let longestStreak: Int
        let lastCheckIn: Date
    }

    /// Given the profile's current state and a check-in happening `now`,
    /// returns the updated streak values.
    ///
    /// Rules:
    /// - Already checked in today → streak unchanged.
    /// - Last check-in was yesterday → streak + 1 (a continued run).
    /// - Last check-in older, or none → streak resets to 1 (a fresh start).
    static func afterCheckIn(
        currentStreak: Int,
        longestStreak: Int,
        lastCheckIn: Date?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Result {
        let newCurrent: Int
        if let last = lastCheckIn {
            if calendar.isDateInToday(last) {
                newCurrent = max(currentStreak, 1)
            } else if calendar.isDateInYesterday(last) {
                newCurrent = currentStreak + 1
            } else {
                newCurrent = 1
            }
        } else {
            newCurrent = 1
        }
        return Result(
            currentStreak: newCurrent,
            longestStreak: max(longestStreak, newCurrent),
            lastCheckIn: now
        )
    }
}
