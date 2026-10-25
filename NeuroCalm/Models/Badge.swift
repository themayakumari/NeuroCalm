//
//  Badge.swift
//  NeuroCalm
//
//  Achievement badges that reward showing up. Definitions are data; whether one
//  is earned is computed purely from the CalmLog history (so it's testable and
//  has no stored state to keep in sync).
//

import Foundation

struct Badge: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let symbol: String       // SF Symbol name
}

enum BadgeCatalog {
    static let all: [Badge] = [
        Badge(id: "first-breath", title: "First Breath",
              detail: "Complete your first breathing session.", symbol: "wind"),
        Badge(id: "first-rest", title: "Deep Rest",
              detail: "Play your first relaxation track.", symbol: "moon.stars.fill"),
        Badge(id: "first-checkin", title: "Checked In",
              detail: "Log your first mood check-in.", symbol: "face.smiling"),
        Badge(id: "ring-closed", title: "Ring Closed",
              detail: "Fill your Calm Ring for a day.", symbol: "circle.circle.fill"),
        Badge(id: "well-rounded", title: "Well-Rounded",
              detail: "Breathe, relax, and check in — all in one day.", symbol: "sparkles"),
        Badge(id: "streak-3", title: "3-Day Calm",
              detail: "Close your ring 3 days in a row.", symbol: "flame.fill"),
        Badge(id: "streak-7", title: "7-Day Calm",
              detail: "Close your ring 7 days in a row.", symbol: "flame.fill"),
        Badge(id: "ten-moments", title: "Ten Moments",
              detail: "Log 10 calm moments in total.", symbol: "leaf.fill"),
        Badge(id: "night-owl", title: "Night Owl",
              detail: "Relax with a track in the evening.", symbol: "zzz")
    ]
}

/// Pure logic deciding which badges are earned from the calm history.
enum BadgeLogic {
    static func earned(logs: [CalmLog], now: Date = .now, calendar: Calendar = .current) -> Set<String> {
        var earned = Set<String>()

        let breathe = logs.filter { $0.kind == CalmKind.breathe.rawValue }
        let relax   = logs.filter { $0.kind == CalmKind.relax.rawValue }
        let mood    = logs.filter { $0.kind == CalmKind.mood.rawValue }

        if !breathe.isEmpty { earned.insert("first-breath") }
        if !relax.isEmpty   { earned.insert("first-rest") }
        if !mood.isEmpty    { earned.insert("first-checkin") }
        if logs.count >= 10 { earned.insert("ten-moments") }

        // Any day where the ring closed.
        if anyDayClosed(logs: logs, calendar: calendar) { earned.insert("ring-closed") }

        // A single day containing all three kinds.
        if hasWellRoundedDay(logs: logs, calendar: calendar) { earned.insert("well-rounded") }

        // Evening relaxation.
        if relax.contains(where: { calendar.component(.hour, from: $0.date) >= 20 }) {
            earned.insert("night-owl")
        }

        let streak = CalmRingLogic.closedStreak(logs: logs, now: now, calendar: calendar)
        if streak >= 3 { earned.insert("streak-3") }
        if streak >= 7 { earned.insert("streak-7") }

        return earned
    }

    private static func anyDayClosed(logs: [CalmLog], calendar: Calendar) -> Bool {
        var byDay: [Date: Int] = [:]
        for log in logs {
            byDay[calendar.startOfDay(for: log.date), default: 0] += log.points
        }
        return byDay.values.contains { $0 >= CalmRingLogic.dailyGoal }
    }

    private static func hasWellRoundedDay(logs: [CalmLog], calendar: Calendar) -> Bool {
        var kindsByDay: [Date: Set<String>] = [:]
        for log in logs {
            kindsByDay[calendar.startOfDay(for: log.date), default: []].insert(log.kind)
        }
        return kindsByDay.values.contains { $0.count >= 3 }
    }
}
