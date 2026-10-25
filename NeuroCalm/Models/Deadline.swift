//
//  Deadline.swift
//  NeuroCalm
//

import Foundation
import SwiftData

@Model
final class Deadline {
    var title: String      // e.g. "Chemistry Test"
    var dueDate: Date
    var subject: String    // e.g. "Science"
    var isCompleted: Bool

    init(title: String, dueDate: Date, subject: String = "", isCompleted: Bool = false) {
        self.title = title
        self.dueDate = dueDate
        self.subject = subject
        self.isCompleted = isCompleted
    }

    /// Number of days from now until the deadline.
    /// Negative if it's in the past.
    var daysUntil: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let due = calendar.startOfDay(for: dueDate)
        return calendar.dateComponents([.day], from: today, to: due).day ?? 0
    }

    var humanReadableDue: String {
        let days = daysUntil
        if days < 0 { return "Past due" }
        if days == 0 { return "Today" }
        if days == 1 { return "Tomorrow" }
        return "In \(days) days"
    }
}
