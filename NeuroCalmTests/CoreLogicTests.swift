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
import SwiftData
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

    // MARK: - Reset all data

    @MainActor
    func testEraseAll_deletesEveryKindOfData() throws {
        let container = try ModelContainer(
            for: Schema(LocalData.allModels),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        context.insert(UserProfile())
        context.insert(MoodCheckIn(mood: "calm", stressLevel: 2))
        context.insert(Deadline(title: "Essay", dueDate: .now, subject: "English"))
        context.insert(Bookmark(kind: "track", referenceId: "t1", title: "Track", subtitle: ""))
        context.insert(CalmLog(kind: .breathe))
        context.insert(ActiveChallenge(templateId: "week"))
        context.insert(TeamMembership(challengeId: "c1", title: "Team"))
        let chat = AssistantConversation()
        context.insert(chat)
        let message = AssistantMessage(text: "hi", isUser: true)
        message.conversation = chat
        context.insert(message)
        try context.save()
        UserDefaults.standard.set("school-1", forKey: "schoolId")

        LocalData.eraseAll(context: context)

        for type in LocalData.allModels {
            XCTAssertEqual(try count(type, in: context), 0, "\(type) was not erased")
        }
        XCTAssertNil(UserDefaults.standard.string(forKey: "schoolId"))
    }

    // MARK: - Team challenges and school

    func testLeaderboardName_trimsAndCaps() {
        XCTAssertEqual(TeamService.leaderboardName("  Maya  "), "Maya")
        XCTAssertEqual(TeamService.leaderboardName("   "), "Friend")
        let long = String(repeating: "a", count: 100)
        XCTAssertEqual(TeamService.leaderboardName(long).count, TeamService.maxNameLength)
    }

    func testSchoolStoredLocally_andCleared() {
        SchoolService.storeLocally(id: "s1", name: "Lincoln High")
        XCTAssertEqual(SchoolService.savedName, "Lincoln High")
        SchoolService.clearLocal()
        XCTAssertNil(SchoolService.savedName)
        XCTAssertNil(UserDefaults.standard.string(forKey: SchoolService.idKey))
    }

    @MainActor
    func testEraseAll_clearsLeaderboardName() throws {
        let container = try ModelContainer(
            for: Schema(LocalData.allModels),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        UserDefaults.standard.set("Maya", forKey: LeaderboardName.key)
        LocalData.eraseAll(context: container.mainContext)
        XCTAssertNil(UserDefaults.standard.string(forKey: LeaderboardName.key))
    }

    private func count<T: PersistentModel>(_ type: T.Type, in context: ModelContext) throws -> Int {
        try context.fetchCount(FetchDescriptor<T>())
    }

    // MARK: - Content file (practices + audio from Firebase)

    private let practiceJSON = """
    {"id": "bhramari", "name": "Humming Bee Breath", "aliases": [], "goodFor": ["calm"],
     "summary": "Humming breath.", "category": "Breathing techniques",
     "content": "Hum softly.", "source": "Traditional"}
    """

    func testContent_readsPracticesAndTracks() throws {
        let json = """
        {"practices": [\(practiceJSON)],
         "tracks": [{"id": "bee", "title": "Humming Bee", "duration": "6:00",
                     "category": "practice", "file": "audio/humming bee.mp3",
                     "practiceIds": ["bhramari"], "version": 2}]}
        """
        let content = try XCTUnwrap(RemoteContent.decode(Data(json.utf8), bucket: "demo.app"))
        XCTAssertEqual(content.practices.map(\.id), ["bhramari"])
        let track = try XCTUnwrap(content.tracks.first)
        XCTAssertEqual(track.category, .practice)
        XCTAssertEqual(track.practiceIds, ["bhramari"])
        XCTAssertEqual(track.version, 2)
        XCTAssertEqual(track.fileExtension, "mp3")
        XCTAssertEqual(track.remoteURL?.absoluteString,
                       "https://firebasestorage.googleapis.com/v0/b/demo.app/o/audio%2Fhumming%20bee.mp3?alt=media")
    }

    func testContent_skipsBrokenEntriesButKeepsTheRest() throws {
        let json = """
        {"practices": [\(practiceJSON), {"id": "missing-fields"}],
         "tracks": [{"id": "no-title"}, {"id": "ok", "title": "OK", "file": "https://example.com/a.m4a"}]}
        """
        let content = try XCTUnwrap(RemoteContent.decode(Data(json.utf8), bucket: "demo.app"))
        XCTAssertEqual(content.practices.map(\.id), ["bhramari"])
        XCTAssertEqual(content.tracks.map(\.id), ["ok"])
        XCTAssertEqual(content.tracks.first?.fileExtension, "m4a")
    }

    func testContent_brokenOrEmptyFileIsIgnored() {
        XCTAssertNil(RemoteContent.decode(Data("not json".utf8), bucket: "demo.app"))
        XCTAssertNil(RemoteContent.decode(Data("{}".utf8), bucket: "demo.app"))
        XCTAssertNil(RemoteContent.decode(Data(#"{"practices": [], "tracks": []}"#.utf8), bucket: "demo.app"))
    }

    func testMerge_remoteEntryUpdatesBundledTrackAndKeepsItsFile() throws {
        var update = MeditationTrack(id: "yoga-nap", title: "Yoga Nap (new)", subtitle: "Better audio",
                                     durationLabel: "16:00", order: 5)
        update.remoteURL = URL(string: "https://example.com/yoga-nap.mp3")
        let merged = MeditationLibrary.merge(bundled: MeditationLibrary.all, remote: [update])
        let track = try XCTUnwrap(merged.first { $0.id == "yoga-nap" })
        XCTAssertEqual(track.title, "Yoga Nap (new)")
        XCTAssertNotNil(track.bundledURL, "bundled file should stay as the offline backup")
        XCTAssertEqual(merged.count, MeditationLibrary.all.count)
    }

    func testMerge_inactiveHidesAndUnplayableIsDropped() {
        var retired = MeditationTrack(id: "shavasana-1", title: "Old", subtitle: "", durationLabel: "")
        retired.isActive = false
        let noFile = MeditationTrack(id: "nowhere", title: "No file", subtitle: "", durationLabel: "")
        let merged = MeditationLibrary.merge(bundled: MeditationLibrary.all, remote: [retired, noFile])
        XCTAssertFalse(merged.contains { $0.id == "shavasana-1" })
        XCTAssertFalse(merged.contains { $0.id == "nowhere" })
    }

    // MARK: - Leaderboard safety

    func testCodes_onlySafeOnesReachFirestore() {
        XCTAssertTrue(TeamService.isValidCode("ABC234"))
        for code in ["ABC/23", "abc234", "ABC23", "ABC2345", "..", ""] {
            XCTAssertFalse(TeamService.isValidCode(code), code)
        }
        XCTAssertTrue(SchoolService.isValidCode("NCREVIEW26"))
        XCTAssertTrue(SchoolService.isValidCode("BC2M2026"))
        XCTAssertFalse(SchoolService.isValidCode("A/B"))
    }

    func testNameFilter_blocksOffensiveNamesAndDisguises() {
        for name in ["fuck", "F U C K", "sh1t", "big bitch", "motherfucker", "$hit"] {
            XCTAssertFalse(TeamService.isNameAllowed(name), name)
        }
    }

    func testNameFilter_allowsNormalNames() {
        for name in ["Maya", "", "Sam K.", "Scunthorpe Sam", "Cassie", "Dickson", "José", "Player 1"] {
            XCTAssertTrue(TeamService.isNameAllowed(name), name)
        }
    }

    func testBlockedMembers_hidesOnlyBlockedPeopleAndRoundTrips() {
        let members = [MemberProgress(id: "a", name: "A", current: 3),
                       MemberProgress(id: "b", name: "B", current: 2)]
        let raw = BlockedMembers.raw(from: ["b", "c"])
        XCTAssertEqual(BlockedMembers.ids(from: raw), ["b", "c"])
        XCTAssertEqual(BlockedMembers.visible(members, raw: raw).map(\.id), ["a"])
        XCTAssertEqual(BlockedMembers.visible(members, raw: "").count, 2)
    }

    func testEraseAll_clearsBlockedMembers() {
        XCTAssertTrue(LocalData.personalKeys.contains(BlockedMembers.key))
    }

    // MARK: - Switching accounts

    @MainActor
    func testClaim_differentAccountErasesDataButSameAccountKeepsIt() throws {
        let container = try ModelContainer(
            for: Schema(LocalData.allModels),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        UserDefaults.standard.removeObject(forKey: LocalData.ownerKey)
        defer { UserDefaults.standard.removeObject(forKey: LocalData.ownerKey) }
        context.insert(CalmLog(kind: .breathe))
        context.insert(TeamMembership(challengeId: "c1", title: "Team"))
        try context.save()

        // An account already signed in on an older build keeps its data, and so
        // does signing back in.
        try LocalData.claim(forAccount: "a", wasSignedInAtLaunch: true, context: context)
        try LocalData.claim(forAccount: "a", wasSignedInAtLaunch: false, context: context)
        XCTAssertEqual(try count(CalmLog.self, in: context), 1)

        // A different account starts clean, with its restored school untouched.
        UserDefaults.standard.set("school-b", forKey: SchoolService.idKey)
        defer { UserDefaults.standard.removeObject(forKey: SchoolService.idKey) }
        try LocalData.claim(forAccount: "b", wasSignedInAtLaunch: false, context: context)
        XCTAssertEqual(try count(CalmLog.self, in: context), 0)
        XCTAssertEqual(try count(TeamMembership.self, in: context), 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<UserProfile>()).first?.hasCompletedOnboarding, false)
        XCTAssertEqual(UserDefaults.standard.string(forKey: SchoolService.idKey), "school-b")
        XCTAssertEqual(UserDefaults.standard.string(forKey: LocalData.ownerKey), "b")
    }

    @MainActor
    func testClaim_newSignInDoesNotInheritDataWithNoOwner() throws {
        let container = try ModelContainer(
            for: Schema(LocalData.allModels),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        UserDefaults.standard.removeObject(forKey: LocalData.ownerKey)
        defer { UserDefaults.standard.removeObject(forKey: LocalData.ownerKey) }
        context.insert(CalmLog(kind: .breathe))
        try context.save()

        try LocalData.claim(forAccount: "new", wasSignedInAtLaunch: false, context: context)
        XCTAssertEqual(try count(CalmLog.self, in: context), 0)
    }

    @MainActor
    func testSeed_realStudentsGetNoExampleTasks() throws {
        let container = try ModelContainer(
            for: Schema(LocalData.allModels),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        SampleData.seedIfNeeded(context: context)
        XCTAssertEqual(try count(UserProfile.self, in: context), 1)
        XCTAssertEqual(try count(RoutineTask.self, in: context), 0)
        XCTAssertEqual(try count(Deadline.self, in: context), 0)
    }

    /// On a real store (not in-memory), ticked tasks must not survive an erase.
    @MainActor
    func testEraseAll_onDiskRemovesTickedTasks() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".store")
        let schema = Schema(LocalData.allModels)
        var container: ModelContainer? = try ModelContainer(
            for: schema, configurations: ModelConfiguration(schema: schema, url: url)
        )
        let context = container!.mainContext
        context.insert(RoutineTask(title: "Saved", scheduledTime: .now))
        context.insert(RoutineTask(title: "Ticked", scheduledTime: .now))
        try context.save()

        // Hold the tasks the way a screen does, and leave one tick unsaved.
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        tasks.first { $0.title == "Ticked" }?.isCompleted = true

        LocalData.eraseAll(context: context)
        XCTAssertEqual(try count(RoutineTask.self, in: context), 0, "same session")
        try? context.save()
        XCTAssertEqual(try context.fetch(FetchDescriptor<RoutineTask>()).count, 0, "after another save")
        withExtendedLifetime(tasks) {}

        container = nil
        let reopened = try ModelContainer(
            for: schema, configurations: ModelConfiguration(schema: schema, url: url)
        )
        XCTAssertEqual(try count(RoutineTask.self, in: reopened.mainContext), 0, "after relaunch")
    }

    // MARK: - Assistant crisis reply

    func testAssistant_crisisMessagesPointToRealHelp() {
        for message in ["I want to kill myself", "thinking about SUICIDE", "i don’t want to live",
                        "hi i keep hurting myself", "I want to hurt myself before my exam"] {
            XCTAssertTrue(AssistantService.mentionsCrisis(message), message)
            XCTAssertTrue(AssistantService.reply(to: message).text.contains("988"), message)
        }
    }

    func testAssistant_crisisCheckSkipsOrdinaryStress() {
        for message in ["I'm stressed about my test", "I can't sleep", "this homework is killing me"] {
            XCTAssertFalse(AssistantService.mentionsCrisis(message), message)
        }
    }

    func testAssistant_crisisReplyWinsOverOnDeviceModel() async {
        let result = await AssistantService.generateReply(history: [(role: "user", text: "I want to die")])
        XCTAssertTrue(result.text.contains("988"))
        XCTAssertEqual(result.source, .local)
    }

    func testMerge_newTrackIsAddedInOrder() {
        var extra = MeditationTrack(id: "body-scan", title: "Body Scan", subtitle: "", durationLabel: "10:00", order: 0)
        extra.remoteURL = URL(string: "https://example.com/body-scan.mp3")
        let merged = MeditationLibrary.merge(bundled: MeditationLibrary.all, remote: [extra])
        XCTAssertEqual(merged.first?.id, "body-scan")
        XCTAssertTrue(merged.first?.needsDownload ?? false)
    }

}
