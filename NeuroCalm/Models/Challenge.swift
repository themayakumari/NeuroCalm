//
//  Challenge.swift
//  NeuroCalm
//
//  Calm challenges — self-paced goals over a few days, tracked against the
//  same CalmLog history the ring and badges use. Solo now; the "with friends"
//  team version layers a shared backend on top of this same model later.
//

import Foundation
import SwiftData

/// What a challenge measures.
enum ChallengeMetric: String, Codable {
    case closedRings        // days the Calm Ring was closed
    case breatheSessions
    case relaxSessions
    case calmMoments        // any calm action

    var unit: String {
        switch self {
        case .closedRings:     return "days"
        case .breatheSessions: return "sessions"
        case .relaxSessions:   return "sessions"
        case .calmMoments:     return "moments"
        }
    }
}

struct ChallengeTemplate: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let metric: ChallengeMetric
    let target: Int
    let days: Int
}

enum ChallengeCatalog {
    static let featured: [ChallengeTemplate] = [
        ChallengeTemplate(id: "seven-day-calm", title: "7-Day Calm",
                          detail: "Close your Calm Ring on 5 of the next 7 days.",
                          symbol: "circle.circle.fill", metric: .closedRings, target: 5, days: 7),
        ChallengeTemplate(id: "breathe-daily", title: "Breathe Daily",
                          detail: "Do 5 breathing sessions this week.",
                          symbol: "wind", metric: .breatheSessions, target: 5, days: 7),
        ChallengeTemplate(id: "wind-down-week", title: "Wind-Down Week",
                          detail: "Play 3 relaxation tracks this week.",
                          symbol: "moon.stars.fill", metric: .relaxSessions, target: 3, days: 7),
        ChallengeTemplate(id: "calm-explorer", title: "Calm Explorer",
                          detail: "Log 10 calm moments in 7 days.",
                          symbol: "sparkles", metric: .calmMoments, target: 10, days: 7)
    ]

    static func template(id: String) -> ChallengeTemplate? {
        featured.first { $0.id == id }
    }
}

@Model
final class ActiveChallenge {
    var templateId: String
    var startDate: Date

    init(templateId: String, startDate: Date = .now) {
        self.templateId = templateId
        self.startDate = startDate
    }
}

struct ChallengeProgress: Equatable {
    let current: Int
    let target: Int
    let daysLeft: Int
    let isComplete: Bool
    let isExpired: Bool

    var fraction: Double { target == 0 ? 0 : min(1.0, Double(current) / Double(target)) }
}

enum ChallengeLogic {
    static func progress(
        template: ChallengeTemplate,
        start: Date,
        logs: [CalmLog],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> ChallengeProgress {
        let startDay = calendar.startOfDay(for: start)
        let windowEnd = calendar.date(byAdding: .day, value: template.days, to: startDay) ?? start
        let windowLogs = logs.filter { $0.date >= startDay && $0.date < windowEnd }

        let current: Int
        switch template.metric {
        case .breatheSessions:
            current = windowLogs.filter { $0.kind == CalmKind.breathe.rawValue }.count
        case .relaxSessions:
            current = windowLogs.filter { $0.kind == CalmKind.relax.rawValue }.count
        case .calmMoments:
            current = windowLogs.count
        case .closedRings:
            var byDay: [Date: Int] = [:]
            for log in windowLogs {
                byDay[calendar.startOfDay(for: log.date), default: 0] += log.points
            }
            current = byDay.values.filter { $0 >= CalmRingLogic.dailyGoal }.count
        }

        let elapsed = calendar.dateComponents([.day], from: startDay, to: calendar.startOfDay(for: now)).day ?? 0
        let daysLeft = max(0, template.days - elapsed)
        let isComplete = current >= template.target
        let isExpired = daysLeft == 0 && !isComplete

        return ChallengeProgress(
            current: min(current, template.target),
            target: template.target,
            daysLeft: daysLeft,
            isComplete: isComplete,
            isExpired: isExpired
        )
    }
}
