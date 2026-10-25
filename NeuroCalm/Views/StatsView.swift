//
//  StatsView.swift
//  NeuroCalm
//
//  Shows weekly progress: streak, sessions, tasks completed.
//

import SwiftUI
import SwiftData
import UIKit

struct StatsView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query private var profiles: [UserProfile]
    @Query private var sessions: [BreathingSession]
    @Query private var tasks: [RoutineTask]
    @Query private var moods: [MoodCheckIn]
    @Query private var calmLogs: [CalmLog]

    private var isRegular: Bool { horizontalSizeClass == .regular }

    private var earnedBadges: Int { BadgeLogic.earned(logs: calmLogs).count }

    @State private var shareImage: UIImage?
    @State private var showShare = false

    var profile: UserProfile? { profiles.first }

    var sessionsThisWeek: Int {
        sessions.filter { isThisWeek($0.date) }.count
    }

    var completedTasksThisWeek: Int {
        tasks.filter { $0.isCompleted && isThisWeek($0.scheduledTime) }.count
    }

    var checkInsThisWeek: Int {
        moods.filter { isThisWeek($0.date) }.count
    }

    /// 0...100 wellness score based on activity (see WellnessScore).
    var wellnessScore: Int {
        WellnessScore.compute(
            breathingSessions: sessionsThisWeek,
            tasksCompleted: completedTasksThisWeek,
            checkIns: checkInsThisWeek
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if isRegular {
                        // iPad: streak and wellness share the top row.
                        HStack(alignment: .top, spacing: 16) {
                            streakCard.frame(maxWidth: .infinity, alignment: .top)
                            wellnessCard.frame(maxWidth: .infinity, alignment: .top)
                        }
                        statGrid
                        badgesCard
                        shareCard
                        encouragementCard
                    } else {
                        streakCard
                        statGrid
                        badgesCard
                        shareCard
                        wellnessCard
                        encouragementCard
                    }
                }
                .padding()
                .adaptiveContentWidth(isRegular ? 1100 : AppTheme.maxContentWidth)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Progress")
            .sheet(isPresented: $showShare) {
                if let shareImage {
                    ShareSheet(items: [shareImage, "Taking care of my mind with NeuroCalm 🌿"])
                }
            }
        }
    }

    private var shareCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(AppTheme.ember.opacity(0.15)).frame(width: 46, height: 46)
                    Image(systemName: "sparkles")
                        .font(.title3).foregroundStyle(AppTheme.ember)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Share your progress")
                        .font(.headline).foregroundStyle(AppTheme.cream)
                    Text("Post your streak, or send it to a friend")
                        .font(.subheadline).foregroundStyle(AppTheme.mist)
                }
                Spacer(minLength: 0)
            }
            // Tap a network to share your streak card there.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(SocialPlatform.allCases) { platform in
                        SocialTile(platform: platform) { share(to: platform) }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(AppTheme.twilight2)
        .cornerRadius(AppTheme.cardRadius)
    }

    /// The streak card image to share, built from the latest progress.
    private func makeShareImage() -> UIImage? {
        let headline: String
        let calmStreak = CalmRingLogic.closedStreak(logs: calmLogs)
        if calmStreak >= 1 {
            headline = "🔥 \(calmStreak)-day calm streak"
        } else if let s = profile?.currentStreak, s >= 1 {
            headline = "🔥 \(s)-day streak"
        } else if !calmLogs.isEmpty {
            headline = "\(calmLogs.count) calm moments"
        } else {
            headline = "Starting my calm journey"
        }
        return ShareCardView.render(headline: headline, subline: "Taking care of my mind. 🌿")
    }

    private func share(to platform: SocialPlatform) {
        guard let image = makeShareImage() else { return }
        // Instagram lets us hand the image straight to Stories; if it isn't
        // installed (or for any other network), fall back to the iOS share
        // sheet, which surfaces the chosen app when it's installed.
        if platform == .instagram, SocialShare.shareToInstagramStories(image: image) { return }
        shareImage = image
        showShare = true
    }

    private var badgesCard: some View {
        NavigationLink {
            BadgesView()
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(AppTheme.sage.opacity(0.15)).frame(width: 52, height: 52)
                    Image(systemName: "rosette")
                        .font(.title3)
                        .foregroundStyle(AppTheme.sage)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Badges")
                        .font(.headline)
                        .foregroundStyle(AppTheme.cream)
                    Text("\(earnedBadges) of \(BadgeCatalog.all.count) earned")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.mist)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppTheme.mist)
            }
            .padding(18)
            .frame(maxWidth: .infinity)
            .background(AppTheme.twilight2)
            .cornerRadius(AppTheme.cardRadius)
        }
    }

    private var streakCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Current streak")
                    .font(AppTheme.mono(10))
                    .textCase(.uppercase)
                    .foregroundStyle(AppTheme.mist)
                Text("\(profile?.currentStreak ?? 0) days")
                    .font(AppTheme.mono(32, weight: .semibold))
                    .foregroundStyle(AppTheme.ember)
                Text("Longest: \(profile?.longestStreak ?? 0) days")
                    .font(.caption)
                    .foregroundStyle(AppTheme.mist)
            }
            Spacer()
            Text("🔥")
                .font(.system(size: 64))
        }
        .padding(20)
        .background(AppTheme.twilight2)
        .cornerRadius(AppTheme.cardRadius)
    }

    private var statGrid: some View {
        // Four across on iPad (one row), two across on iPhone.
        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: isRegular ? 4 : 2)
        return LazyVGrid(columns: columns, spacing: 12) {
            statTile(value: "\(sessionsThisWeek)", label: "Breathing sessions", icon: "wind", color: AppTheme.softTeal)
            statTile(value: "\(completedTasksThisWeek)", label: "Tasks completed", icon: "checkmark.circle.fill", color: AppTheme.primaryBlue)
            statTile(value: "\(checkInsThisWeek)", label: "Mood check-ins", icon: "face.smiling", color: AppTheme.lavender)
            statTile(value: "\(totalBreathingMinutes)", label: "Minutes breathing", icon: "clock.fill", color: AppTheme.warmCoral)
        }
    }

    private func statTile(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            Text(label)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppTheme.twilight2)
        .cornerRadius(AppTheme.cardRadius)
    }

    private var wellnessCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Brain Wellness Score")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            HStack {
                Text("\(wellnessScore)")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(AppTheme.primaryBlue)
                Text("/ 100")
                    .font(.title3)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            ProgressView(value: Double(wellnessScore), total: 100)
                .tint(AppTheme.primaryBlue)

            Text(wellnessMessage)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .cardStyle()
    }

    private var encouragementCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundStyle(AppTheme.lavender)
            Text(EncouragementService.randomMessage())
                .foregroundStyle(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(AppTheme.cardGradient)
        .cornerRadius(AppTheme.cardRadius)
    }

    // MARK: - Helpers

    private var totalBreathingMinutes: Int {
        let total = sessions
            .filter { isThisWeek($0.date) }
            .reduce(0) { $0 + $1.durationSeconds }
        return total / 60
    }

    private var wellnessMessage: String {
        WellnessScore.message(for: wellnessScore)
    }

    private func isThisWeek(_ date: Date) -> Bool {
        let cal = Calendar.current
        return cal.isDate(date, equalTo: Date(), toGranularity: .weekOfYear)
    }
}

#Preview {
    StatsView()
        .modelContainer(for: [
            UserProfile.self,
            MoodCheckIn.self,
            RoutineTask.self,
            Deadline.self,
            BreathingSession.self
        ], inMemory: true)
}
