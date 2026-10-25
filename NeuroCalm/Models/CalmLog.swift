//
//  CalmLog.swift
//  NeuroCalm
//
//  A tiny record of a calming action (a breath session, a relaxation track, a
//  mood check-in). These feed the daily "Calm Ring" and the badges — kept as a
//  single log so the gamification has one source of truth.
//

import Foundation
import SwiftData

enum CalmKind: String, CaseIterable, Codable {
    case breathe
    case relax
    case mood

    /// Points this action contributes toward the daily ring.
    var points: Int {
        switch self {
        case .breathe: return 50
        case .relax:   return 40
        case .mood:    return 20
        }
    }

    var label: String {
        switch self {
        case .breathe: return "Breathing"
        case .relax:   return "Relaxation"
        case .mood:    return "Check-in"
        }
    }
}

@Model
final class CalmLog {
    var date: Date
    var kind: String        // CalmKind raw value
    var points: Int

    init(kind: CalmKind, date: Date = .now) {
        self.date = date
        self.kind = kind.rawValue
        self.points = kind.points
    }
}

/// Pure, testable math for the daily Calm Ring.
enum CalmRingLogic {
    /// Points needed to "close" the ring for a day.
    static let dailyGoal = 100

    /// Total calm points earned on a given day.
    static func points(on day: Date, logs: [CalmLog], calendar: Calendar = .current) -> Int {
        logs.filter { calendar.isDate($0.date, inSameDayAs: day) }
            .map(\.points)
            .reduce(0, +)
    }

    /// Ring fill for a point total, 0…1.
    static func progress(_ points: Int) -> Double {
        min(1.0, Double(points) / Double(dailyGoal))
    }

    static func isClosed(_ points: Int) -> Bool { points >= dailyGoal }

    /// Consecutive days (ending today) on which the ring closed. Today still
    /// in progress doesn't break the streak — it just isn't counted yet.
    static func closedStreak(logs: [CalmLog], now: Date = .now, calendar: Calendar = .current) -> Int {
        // Sum points per start-of-day.
        var byDay: [Date: Int] = [:]
        for log in logs {
            let day = calendar.startOfDay(for: log.date)
            byDay[day, default: 0] += log.points
        }
        func closed(_ day: Date) -> Bool { (byDay[day] ?? 0) >= dailyGoal }

        var streak = 0
        var day = calendar.startOfDay(for: now)
        if !closed(day) {
            // Today not closed yet — start counting from yesterday (grace).
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
        }
        while closed(day) {
            streak += 1
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
        }
        return streak
    }
}
