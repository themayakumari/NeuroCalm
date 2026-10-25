//
//  NotificationService.swift
//  NeuroCalm
//
//  Schedules local notifications. No backend needed.
//

import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()

    /// Ask the user for permission to send local notifications.
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                DispatchQueue.main.async { completion(granted) }
            }
    }

    /// Schedule a reminder the morning before a deadline.
    func scheduleDeadlineReminder(for deadline: Deadline) {
        // Trigger time: 9:00 AM the day before the due date.
        let calendar = Calendar.current
        guard let dayBefore = calendar.date(byAdding: .day, value: -1, to: deadline.dueDate)
        else { return }

        var comps = calendar.dateComponents([.year, .month, .day], from: dayBefore)
        comps.hour = 9
        comps.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

        let content = UNMutableNotificationContent()
        content.title = "Deadline tomorrow"
        content.body = "\(deadline.title) is due tomorrow. Take a deep breath and plan ahead."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "deadline-\(deadline.persistentModelID.hashValue)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { _ in }
    }

    /// Schedule a daily reminder for a routine task at its scheduled time.
    func scheduleRoutineReminder(for task: RoutineTask) {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: task.scheduledTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)

        let content = UNMutableNotificationContent()
        content.title = "Routine reminder"
        content.body = "Time for: \(task.title)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: routineIdentifier(for: task),
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request) { _ in }
    }

    /// Remove a routine task's reminder (e.g. when it's deleted).
    func cancelRoutineReminder(for task: RoutineTask) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [routineIdentifier(for: task)])
    }

    private func routineIdentifier(for task: RoutineTask) -> String {
        "routine-\(task.persistentModelID.hashValue)"
    }

    /// Cancel the recurring daily check-in reminder.
    func cancelDailyCheckIn() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["daily-checkin"])
    }

    /// Helpful: a daily check-in reminder.
    func scheduleDailyCheckIn(hour: Int = 16, minute: Int = 0) {
        let content = UNMutableNotificationContent()
        content.title = "Time to check in"
        content.body = "How are you feeling? Tap to log your mood."
        content.sound = .default

        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)

        let request = UNNotificationRequest(
            identifier: "daily-checkin",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { _ in }
    }
}
