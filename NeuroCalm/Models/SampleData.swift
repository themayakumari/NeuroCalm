//
//  SampleData.swift
//  NeuroCalm
//
//  Seeds the database with example data on first launch
//  so screens look populated as you explore the app.
//

import Foundation
import SwiftData

enum SampleData {

    /// Launch NeuroCalm with this argument (see `ScreenTourUITests`) to skip
    /// onboarding and land straight on the main app with a populated profile —
    /// keeps UI tests deterministic regardless of what's already in the
    /// simulator from a previous manual run.
    private static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("UI-TESTING")
    }

    static func seedIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<UserProfile>()
        if let existing = try? context.fetch(descriptor), let profile = existing.first {
            // Already seeded — for UI tests, just make sure onboarding is done
            // so the test doesn't get stuck on the Welcome screen.
            if isUITesting && !profile.hasCompletedOnboarding {
                profile.hasCompletedOnboarding = true
                try? context.save()
            }
            return
        }

        // 1) Profile — empty for real users (filled in onboarding), pre-filled
        // and pre-onboarded when running under the UI test harness.
        let profile = UserProfile(
            name: isUITesting ? "Preview" : "Student",
            hasCompletedOnboarding: isUITesting,
            currentStreak: isUITesting ? 3 : 0,
            lastCheckInDate: isUITesting ? Date() : nil
        )
        context.insert(profile)

        // 2) A few example deadlines for the planner screen
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        let inThreeDays = calendar.date(byAdding: .day, value: 3, to: Date())!
        let inAWeek = calendar.date(byAdding: .day, value: 7, to: Date())!

        context.insert(Deadline(title: "Chemistry Test", dueDate: tomorrow, subject: "Science"))
        context.insert(Deadline(title: "Essay Draft", dueDate: inThreeDays, subject: "English"))
        context.insert(Deadline(title: "History Project", dueDate: inAWeek, subject: "History"))

        // 3) Example routine for today
        let today = Date()
        func taskAt(_ hour: Int, _ minute: Int, title: String, category: String) -> RoutineTask {
            var comps = calendar.dateComponents([.year, .month, .day], from: today)
            comps.hour = hour
            comps.minute = minute
            let date = calendar.date(from: comps) ?? today
            return RoutineTask(title: title, scheduledTime: date, category: category)
        }

        context.insert(taskAt(15, 30, title: "Snack & rest",        category: "break"))
        context.insert(taskAt(16, 0,  title: "Math homework",       category: "study"))
        context.insert(taskAt(16, 45, title: "Short break",         category: "break"))
        context.insert(taskAt(17, 0,  title: "Chemistry review",    category: "study"))
        context.insert(taskAt(17, 45, title: "Breathing reset",     category: "break"))
        context.insert(taskAt(18, 0,  title: "Dinner",              category: "other"))
        context.insert(taskAt(20, 30, title: "Light review",        category: "study"))
        context.insert(taskAt(21, 30, title: "Wind down for sleep", category: "sleep"))

        try? context.save()
    }
}
