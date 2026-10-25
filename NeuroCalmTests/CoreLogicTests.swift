//
//  CoreLogicTests.swift
//  NeuroCalmTests
//
//  Unit tests for the app's pure "brain": streak math, wellness score,
//  deadline dates, breathing ratios, and the assistant's routing.
//

import XCTest
import UIKit
import SwiftUI
import AVFoundation
import HealthKit
@testable import NeuroCalm

final class CoreLogicTests: XCTestCase {

    // MARK: - HealthKit wiring

    func testHealthKit_mindfulTypeResolves() {
        // Confirms HealthKit is linked and the Mindful Session type is available,
        // which is what HealthKitService writes breathing sessions to.
        XCTAssertNotNil(HKObjectType.categoryType(forIdentifier: .mindfulSession))
    }


    // MARK: - Relaxation audio library

    func testMeditationTracks_areAllBundledAndPlayable() throws {
        XCTAssertFalse(MeditationLibrary.all.isEmpty)
        for track in MeditationLibrary.all {
            let url = try XCTUnwrap(track.url, "missing bundled audio for \(track.id)")
            let player = try AVAudioPlayer(contentsOf: url)
            XCTAssertGreaterThan(player.duration, 0, "\(track.id) produced no audio")
        }
    }


    // MARK: - Streak

    private let cal = Calendar.current

    func testStreak_firstEverCheckIn_startsAtOne() {
        let r = StreakLogic.afterCheckIn(currentStreak: 0, longestStreak: 0, lastCheckIn: nil)
        XCTAssertEqual(r.currentStreak, 1)
        XCTAssertEqual(r.longestStreak, 1)
    }

    func testStreak_checkingInAgainToday_doesNotAdvance() {
        let r = StreakLogic.afterCheckIn(currentStreak: 5, longestStreak: 9, lastCheckIn: Date())
        XCTAssertEqual(r.currentStreak, 5)
        XCTAssertEqual(r.longestStreak, 9)
    }

    func testStreak_checkingInYesterday_advances() {
        let yesterday = cal.date(byAdding: .day, value: -1, to: Date())!
        let r = StreakLogic.afterCheckIn(currentStreak: 3, longestStreak: 3, lastCheckIn: yesterday)
        XCTAssertEqual(r.currentStreak, 4)
        XCTAssertEqual(r.longestStreak, 4, "a new record should raise the longest streak")
    }

    func testStreak_missedDays_resetsToOne() {
        let threeDaysAgo = cal.date(byAdding: .day, value: -3, to: Date())!
        let r = StreakLogic.afterCheckIn(currentStreak: 10, longestStreak: 10, lastCheckIn: threeDaysAgo)
        XCTAssertEqual(r.currentStreak, 1, "missing days resets the run")
        XCTAssertEqual(r.longestStreak, 10, "but the record is preserved")
    }

    // MARK: - Wellness score

    func testWellness_zeroActivity_isZero() {
        XCTAssertEqual(WellnessScore.compute(breathingSessions: 0, tasksCompleted: 0, checkIns: 0), 0)
    }

    func testWellness_caps_eachComponent() {
        // 10 sessions * 10 = 100 but capped at 40; 10 tasks * 5 = 50 capped 30; 10 checkins capped 30.
        XCTAssertEqual(WellnessScore.compute(breathingSessions: 10, tasksCompleted: 10, checkIns: 10), 100)
    }

    func testWellness_typicalWeek() {
        // 2 sessions (20) + 3 tasks (15) + 4 checkins (20) = 55
        XCTAssertEqual(WellnessScore.compute(breathingSessions: 2, tasksCompleted: 3, checkIns: 4), 55)
    }

    func testWellness_negativeInputsClampToZero() {
        XCTAssertEqual(WellnessScore.compute(breathingSessions: -5, tasksCompleted: -1, checkIns: 0), 0)
    }

    func testWellness_messageBands() {
        XCTAssertEqual(WellnessScore.message(for: 0), "A small start counts. One session today goes a long way.")
        XCTAssertEqual(WellnessScore.message(for: 60), "Strong week. Your brain thanks you.")
        XCTAssertEqual(WellnessScore.message(for: 100), "Outstanding week. Take pride in this.")
    }

    // MARK: - Deadline dates

    func testDeadline_today_isZeroDays() {
        let d = Deadline(title: "Test", dueDate: Date())
        XCTAssertEqual(d.daysUntil, 0)
        XCTAssertEqual(d.humanReadableDue, "Today")
    }

    func testDeadline_tomorrow() {
        let tomorrow = cal.date(byAdding: .day, value: 1, to: Date())!
        let d = Deadline(title: "Test", dueDate: tomorrow)
        XCTAssertEqual(d.daysUntil, 1)
        XCTAssertEqual(d.humanReadableDue, "Tomorrow")
    }

    func testDeadline_pastDue() {
        let past = cal.date(byAdding: .day, value: -2, to: Date())!
        let d = Deadline(title: "Test", dueDate: past)
        XCTAssertLessThan(d.daysUntil, 0)
        XCTAssertEqual(d.humanReadableDue, "Past due")
    }

    // MARK: - Breathing ratios

    func testRatio_oneToOne_isDefaultBalanced() {
        let p = BreathingRatio.oneToOne.phases
        XCTAssertEqual(p.inhale, p.exhale, "1:1 means inhale equals exhale")
        XCTAssertEqual(p.hold1, 0)
        XCTAssertEqual(p.hold2, 0)
    }

    func testRatio_oneToTwo_hasLongerExhale() {
        let p = BreathingRatio.oneToTwo.phases
        XCTAssertEqual(p.exhale, p.inhale * 2)
    }

    func testRatio_box_allEqualAndNonZero() {
        let p = BreathingRatio.box.phases
        XCTAssertTrue(p.inhale == p.hold1 && p.hold1 == p.exhale && p.exhale == p.hold2)
        XCTAssertGreaterThan(p.inhale, 0)
    }

    func testRatio_fourSevenEight_isFixed() {
        let p = BreathingRatio.fourSevenEight.phases
        XCTAssertEqual(p.inhale, 4)
        XCTAssertEqual(p.hold1, 7)
        XCTAssertEqual(p.exhale, 8)
    }

    func testDuration_secondsMatchMinutes() {
        XCTAssertEqual(BreathingDuration.two.seconds, 120)
        XCTAssertEqual(BreathingDuration.five.seconds, 300)
    }

    // MARK: - Assistant routing

    func testAssistant_examStress_suggestsBreathing() {
        let reply = AssistantService.reply(to: "I have a big exam tomorrow")
        XCTAssertTrue(reply.suggestBreathing)
        XCTAssertFalse(reply.text.isEmpty)
    }

    func testAssistant_sleep_mentionsBreathing() {
        let reply = AssistantService.reply(to: "I can't sleep at all")
        XCTAssertTrue(reply.suggestBreathing)
    }

    func testAssistant_unmatched_stillReturnsSupport() {
        let reply = AssistantService.reply(to: "asdfghjkl random text")
        XCTAssertFalse(reply.text.isEmpty, "there should always be a supportive fallback")
    }

    // MARK: - Calm Ring + Badges

    func testCalmRing_pointsAndClose() {
        let today = Date()
        let logs = [CalmLog(kind: .breathe, date: today), CalmLog(kind: .mood, date: today)]  // 50 + 20
        let pts = CalmRingLogic.points(on: today, logs: logs)
        XCTAssertEqual(pts, 70)
        XCTAssertFalse(CalmRingLogic.isClosed(pts))
        XCTAssertEqual(CalmRingLogic.progress(pts), 0.7, accuracy: 0.001)

        let logs2 = logs + [CalmLog(kind: .relax, date: today)]  // +40 -> 110
        let pts2 = CalmRingLogic.points(on: today, logs: logs2)
        XCTAssertTrue(CalmRingLogic.isClosed(pts2))
        XCTAssertEqual(CalmRingLogic.progress(pts2), 1.0, accuracy: 0.001)  // capped
    }

    func testCalmRing_closedStreakCountsConsecutiveDays() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        func day(_ n: Int) -> Date { cal.date(byAdding: .day, value: n, to: today)! }
        // Close yesterday and the day before; today not closed yet.
        let logs = [
            CalmLog(kind: .breathe, date: day(-1)), CalmLog(kind: .relax, date: day(-1)), CalmLog(kind: .mood, date: day(-1)),  // 110
            CalmLog(kind: .breathe, date: day(-2)), CalmLog(kind: .relax, date: day(-2)), CalmLog(kind: .mood, date: day(-2))   // 110
        ]
        XCTAssertEqual(CalmRingLogic.closedStreak(logs: logs, now: Date(), calendar: cal), 2)
    }

    func testBadges_earnedFromHistory() {
        let today = Date()
        let logs = [CalmLog(kind: .breathe, date: today), CalmLog(kind: .relax, date: today), CalmLog(kind: .mood, date: today)]
        let earned = BadgeLogic.earned(logs: logs, now: today)
        XCTAssertTrue(earned.contains("first-breath"))
        XCTAssertTrue(earned.contains("first-rest"))
        XCTAssertTrue(earned.contains("first-checkin"))
        XCTAssertTrue(earned.contains("ring-closed"))     // 110 >= 100
        XCTAssertTrue(earned.contains("well-rounded"))    // all 3 kinds same day
        XCTAssertFalse(earned.contains("ten-moments"))    // only 3 logs
    }


    func testChallenge_progressCountsWithinWindow() {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        func day(_ n: Int) -> Date { cal.date(byAdding: .day, value: n, to: start)!.addingTimeInterval(3600) }
        let t = ChallengeTemplate(id: "x", title: "T", detail: "", symbol: "wind", metric: .breatheSessions, target: 3, days: 7)
        let logs = [CalmLog(kind: .breathe, date: day(0)), CalmLog(kind: .breathe, date: day(1)),
                    CalmLog(kind: .relax, date: day(1)),
                    CalmLog(kind: .breathe, date: day(9))]  // day 9 is outside the 7-day window
        let p = ChallengeLogic.progress(template: t, start: start, logs: logs, now: day(1), calendar: cal)
        XCTAssertEqual(p.current, 2)          // 2 breathe sessions in window (relax ignored, day-9 excluded)
        XCTAssertEqual(p.target, 3)
        XCTAssertFalse(p.isComplete)
        XCTAssertEqual(p.daysLeft, 6)
    }

    func testChallenge_closedRingsMetricAndComplete() {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        func day(_ n: Int) -> Date { cal.date(byAdding: .day, value: n, to: start)!.addingTimeInterval(3600) }
        let t = ChallengeTemplate(id: "r", title: "R", detail: "", symbol: "circle", metric: .closedRings, target: 2, days: 7)
        // Close the ring on day 0 and day 1 (110 pts each).
        let logs = [
            CalmLog(kind: .breathe, date: day(0)), CalmLog(kind: .relax, date: day(0)), CalmLog(kind: .mood, date: day(0)),
            CalmLog(kind: .breathe, date: day(1)), CalmLog(kind: .relax, date: day(1)), CalmLog(kind: .mood, date: day(1))
        ]
        let p = ChallengeLogic.progress(template: t, start: start, logs: logs, now: day(1), calendar: cal)
        XCTAssertEqual(p.current, 2)
        XCTAssertTrue(p.isComplete)
    }


    @MainActor
    func testShareCardRenders() {
        let img = ShareCardView.render(headline: "🔥 5-day calm streak", subline: "Taking care of my mind. 🌿")
        XCTAssertNotNil(img)
        if let img {
            let a = XCTAttachment(image: img); a.name = "share-card"; a.lifetime = .keepAlways; add(a)
        }
    }

}
