//
//  RoutineTask.swift
//  NeuroCalm
//

import Foundation
import SwiftData

@Model
final class RoutineTask {
    var title: String
    var scheduledTime: Date
    var isCompleted: Bool
    var category: String   // "study", "break", "sleep", "exercise", "other"

    init(
        title: String,
        scheduledTime: Date,
        isCompleted: Bool = false,
        category: String = "study"
    ) {
        self.title = title
        self.scheduledTime = scheduledTime
        self.isCompleted = isCompleted
        self.category = category
    }
}

/// Helper enum for categories so the rest of the app has type safety.
enum TaskCategory: String, CaseIterable, Identifiable {
    case study, breakTime = "break", sleep, exercise, other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .study: return "Study"
        case .breakTime: return "Break"
        case .sleep: return "Sleep"
        case .exercise: return "Exercise"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .study: return "book.fill"
        case .breakTime: return "cup.and.saucer.fill"
        case .sleep: return "moon.fill"
        case .exercise: return "figure.run"
        case .other: return "circle.fill"
        }
    }
}
