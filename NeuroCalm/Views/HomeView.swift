//
//  HomeView.swift
//  NeuroCalm
//
//  The main dashboard the user sees on launch.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query private var profiles: [UserProfile]
    @Query(sort: \Deadline.dueDate, order: .forward) private var deadlines: [Deadline]
    @Query(sort: \RoutineTask.scheduledTime, order: .forward) private var tasks: [RoutineTask]
    @Query(sort: \MoodCheckIn.date, order: .reverse) private var moods: [MoodCheckIn]
    @Query private var calmLogs: [CalmLog]

    @State private var showBreathing = false
    @State private var showMoodSheet = false

    /// iPad / wide layouts get the multi-column dashboard.
    private var isRegular: Bool { horizontalSizeClass == .regular }

    var profile: UserProfile? { profiles.first }

    var nextDeadline: Deadline? {
        deadlines.first(where: { !$0.isCompleted && $0.daysUntil >= 0 })
    }

    var todaysTasks: [RoutineTask] {
        let calendar = Calendar.current
        return tasks.filter { calendar.isDateInToday($0.scheduledTime) }
    }

    var latestMood: MoodCheckIn? { moods.first }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                // Only go two-column when there's genuinely room — on a narrow
                // iPad (portrait / split view) the columns get squished, so fall
                // back to the single scrolling column.
                let wide = geo.size.width >= 720
                ScrollView {
                    Group {
                        if wide {
                            regularDashboard
                        } else {
                            compactStack
                        }
                    }
                    .padding()
                    .adaptiveContentWidth(wide ? 1100 : AppTheme.maxContentWidth)
                }
                .background(AppTheme.background.ignoresSafeArea())
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape")
                            .foregroundStyle(AppTheme.primaryBlue)
                    }
                    .accessibilityLabel("Settings")
                }
            }
        }
        .fullScreenCover(isPresented: $showBreathing) {
            BreathingView()
        }
        .sheet(isPresented: $showMoodSheet) {
            MoodCheckInSheet()
                .presentationDetents([.medium])
        }
    }

    /// iPhone (and narrow iPad) — one scrolling column.
    private var compactStack: some View {
        VStack(alignment: .leading, spacing: 20) {
            greetingHeader
            calmRingCard
            moodAndStreakRow
            if let deadline = nextDeadline {
                upcomingDeadlineCard(deadline)
            }
            breatheNowCard
            relaxCard
            practicesCard
            challengesCard
            todaysPlanCard
            encouragementCard
            supportCard
        }
    }

    /// iPad / wide — greeting on top, then two columns: status + actions on the
    /// left, the full day's plan on the right, so more is visible without scrolling.
    private var regularDashboard: some View {
        VStack(alignment: .leading, spacing: 20) {
            greetingHeader
            HStack(alignment: .top, spacing: 20) {
                VStack(spacing: 20) {
                    calmRingCard
                    moodAndStreakRow
                    if let deadline = nextDeadline {
                        upcomingDeadlineCard(deadline)
                    }
                    breatheNowCard
                    relaxCard
                    practicesCard
                    challengesCard
                }
                .frame(maxWidth: .infinity, alignment: .top)

                VStack(spacing: 20) {
                    todaysPlanCard
                    encouragementCard
                    supportCard
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
    }

    // MARK: - Sub-views

    private var greetingHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Hey \(profile?.name ?? "there")")
                .font(AppTheme.display(30))
                .foregroundStyle(AppTheme.textPrimary)
            Text(subgreeting)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    // MARK: - Calm Ring

    private var todayCalmPoints: Int { CalmRingLogic.points(on: Date(), logs: calmLogs) }
    private var ringProgress: Double { CalmRingLogic.progress(todayCalmPoints) }
    private var ringClosed: Bool { CalmRingLogic.isClosed(todayCalmPoints) }
    private var calmStreak: Int { CalmRingLogic.closedStreak(logs: calmLogs) }

    private var calmRingCard: some View {
        HStack(spacing: 18) {
            CalmRingView(progress: ringProgress, closed: ringClosed, size: 92, lineWidth: 11)
            VStack(alignment: .leading, spacing: 6) {
                Text("Daily Calm")
                    .font(.headline)
                    .foregroundStyle(AppTheme.cream)
                Text(ringClosed
                     ? "You closed your ring today — nice one. 🌿"
                     : "Breathe, relax, or check in to fill your ring.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.mist)
                if calmStreak > 0 {
                    Text("🔥 \(calmStreak)-day calm streak")
                        .font(.caption)
                        .foregroundStyle(AppTheme.ember)
                }
            }
            Spacer()
        }
        .padding(20)
        .background(AppTheme.twilight2)
        .cornerRadius(AppTheme.cardRadius)
    }

    private var moodAndStreakRow: some View {
        HStack(spacing: 12) {
            // Mood card — tap to check in
            Button { showMoodSheet = true } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Today's mood")
                        .font(AppTheme.mono(10))
                        .textCase(.uppercase)
                        .foregroundStyle(AppTheme.textSecondary)
                    HStack {
                        Text(currentMoodEmoji)
                            .font(.title)
                        Text(currentMoodLabel)
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()
            }

            // Streak card — flame + count, mirrors the mockup's streak row
            VStack(alignment: .leading, spacing: 6) {
                Text("Streak")
                    .font(AppTheme.mono(10))
                    .textCase(.uppercase)
                    .foregroundStyle(AppTheme.textSecondary)
                HStack {
                    Text("🔥")
                        .font(.title)
                    Text("\(profile?.currentStreak ?? 0) days")
                        .font(AppTheme.mono(16, weight: .semibold))
                        .foregroundStyle(AppTheme.ember)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
        }
    }

    private func upcomingDeadlineCard(_ deadline: Deadline) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Upcoming · \(deadline.humanReadableDue)")
                .font(AppTheme.mono(10))
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(AppTheme.sage)

            Text("\(deadline.title) — want to breathe through the nerves for a minute?")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(AppTheme.cream)
                .fixedSize(horizontal: false, vertical: true)

            Button { showBreathing = true } label: {
                Text("Start breathing ↗")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(AppTheme.sage)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppTheme.sageDim)
        .cornerRadius(AppTheme.cardRadius)
    }

    private var breatheNowCard: some View {
        Button { showBreathing = true } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(AppTheme.sage.opacity(0.15))
                        .frame(width: 56, height: 56)
                    Image(systemName: "wind")
                        .font(.title)
                        .foregroundStyle(AppTheme.sage)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Breathe Now")
                        .font(.headline)
                        .foregroundStyle(AppTheme.cream)
                    Text("A 2-minute calming session")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.mist)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppTheme.mist)
            }
            .padding(20)
            .background(AppTheme.twilight2)
            .cornerRadius(AppTheme.cardRadius)
        }
    }

    private var challengesCard: some View {
        NavigationLink {
            ChallengesView()
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(AppTheme.ember.opacity(0.15))
                        .frame(width: 56, height: 56)
                    Image(systemName: "trophy.fill")
                        .font(.title2)
                        .foregroundStyle(AppTheme.ember)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Challenges")
                        .font(.headline)
                        .foregroundStyle(AppTheme.cream)
                    Text("Set a calm goal — solo, or with friends soon")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.mist)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppTheme.mist)
            }
            .padding(20)
            .background(AppTheme.twilight2)
            .cornerRadius(AppTheme.cardRadius)
        }
    }

    private var practicesCard: some View {
        NavigationLink {
            PracticeLibraryView()
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(AppTheme.sage.opacity(0.15))
                        .frame(width: 56, height: 56)
                    Image(systemName: "leaf.fill")
                        .font(.title2)
                        .foregroundStyle(AppTheme.sage)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Practices")
                        .font(.headline)
                        .foregroundStyle(AppTheme.cream)
                    Text("Learn the calming techniques — in plain language")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.mist)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppTheme.mist)
            }
            .padding(20)
            .background(AppTheme.twilight2)
            .cornerRadius(AppTheme.cardRadius)
        }
    }

    private var relaxCard: some View {
        NavigationLink {
            RelaxView()
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(AppTheme.mist.opacity(0.15))
                        .frame(width: 56, height: 56)
                    Image(systemName: "moon.stars.fill")
                        .font(.title2)
                        .foregroundStyle(AppTheme.mist)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Relax")
                        .font(.headline)
                        .foregroundStyle(AppTheme.cream)
                    Text("Guided rest — Deep Relaxation & Yoga Nap")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.mist)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppTheme.mist)
            }
            .padding(20)
            .background(AppTheme.twilight2)
            .cornerRadius(AppTheme.cardRadius)
        }
    }

    private var todaysPlanCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today's routine")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                NavigationLink {
                    PlannerView()
                } label: {
                    Text("See all")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.primaryBlue)
                }
            }

            if todaysTasks.isEmpty {
                Text("No tasks for today yet. Add some in the Planner.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                // iPad has the vertical room to show the whole day; iPhone stays
                // to a preview of the next few so the dashboard doesn't get long.
                ForEach(isRegular ? todaysTasks : Array(todaysTasks.prefix(4))) { task in
                    TaskRow(task: task)
                }
            }
        }
        .cardStyle()
    }

    private var encouragementCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundStyle(AppTheme.sage)
            Text(EncouragementService.randomMessage())
                .font(.body)
                .foregroundStyle(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(AppTheme.cardGradient)
        .cornerRadius(AppTheme.cardRadius)
    }

    /// Always-present, calm entry to crisis/mental-health support lines.
    private var supportCard: some View {
        NavigationLink(destination: SupportView()) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(AppTheme.sage.opacity(0.16)).frame(width: 46, height: 46)
                    Image(systemName: "hand.raised.fill")
                        .font(.title3).foregroundStyle(AppTheme.sage)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Need to talk to someone?")
                        .font(.headline).foregroundStyle(AppTheme.cream)
                    Text("Free, confidential support lines — any time.")
                        .font(.subheadline).foregroundStyle(AppTheme.mist)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(AppTheme.mist)
            }
            .padding(18)
            .frame(maxWidth: .infinity)
            .background(AppTheme.twilight2)
            .cornerRadius(AppTheme.cardRadius)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    /// Day of week + a nudge about the nearest deadline, e.g. "Thursday, chem test in 2 days".
    private var subgreeting: String {
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE"
        let day = dayFormatter.string(from: Date())

        guard let deadline = nextDeadline else { return "\(day), \(greeting.lowercased())" }
        let due = deadline.daysUntil
        let when = due == 0 ? "today" : due == 1 ? "tomorrow" : "in \(due) days"
        return "\(day), \(deadline.title.lowercased()) \(when)"
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Hello"
        }
    }

    private var currentMoodEmoji: String {
        guard let mood = latestMood,
              let m = Mood(rawValue: mood.mood) else { return "🙂" }
        return m.emoji
    }

    private var currentMoodLabel: String {
        guard let mood = latestMood,
              let m = Mood(rawValue: mood.mood) else { return "Tap to check in" }
        return m.label
    }
}

// MARK: - Single task row

struct TaskRow: View {
    @Environment(\.modelContext) private var context
    @Bindable var task: RoutineTask
    @State private var showEdit = false

    /// Breathing/break blocks get the sage highlight treatment, like the
    /// "Breathing break" row in the mockup's routine builder.
    private var isHighlighted: Bool { task.category == "break" }

    var body: some View {
        HStack(spacing: 12) {
            Text(task.scheduledTime, style: .time)
                .font(AppTheme.mono(10))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 46, alignment: .leading)

            Text(task.title)
                .font(.subheadline)
                .strikethrough(task.isCompleted)
                .foregroundStyle(task.isCompleted ? AppTheme.textSecondary : AppTheme.textPrimary)

            Spacer()

            Button {
                task.isCompleted.toggle()
                try? context.save()
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isCompleted ? AppTheme.softTeal : AppTheme.textSecondary)
            }

            Menu {
                Button { showEdit = true } label: { Label("Edit", systemImage: "pencil") }
                Button(role: .destructive) {
                    context.delete(task)
                    try? context.save()
                } label: { Label("Delete", systemImage: "trash") }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 28, height: 28)
            }
            .accessibilityLabel("Task options")
        }
        .padding(.vertical, 4)
        .padding(.horizontal, isHighlighted ? 10 : 0)
        .background(isHighlighted ? AppTheme.sageDim.opacity(0.6) : .clear)
        .cornerRadius(10)
        .sheet(isPresented: $showEdit) { AddTaskSheet(editing: task) }
    }
}

// MARK: - Mood Check-In sheet (used by tapping the mood card)

struct MoodCheckInSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]

    @State private var selected: Mood? = nil

    var body: some View {
        VStack(spacing: 20) {
            Text("Check in")
                .font(.title2.bold())
                .padding(.top, 24)
            Text("How are you feeling right now?")
                .foregroundStyle(AppTheme.textSecondary)

            VStack(spacing: 10) {
                ForEach(Mood.allCases) { mood in
                    Button {
                        selected = mood
                    } label: {
                        HStack {
                            Text(mood.emoji).font(.title)
                            Text(mood.label).foregroundStyle(AppTheme.textPrimary)
                            Spacer()
                            if selected == mood {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(AppTheme.primaryBlue)
                            }
                        }
                        .padding()
                        .background(AppTheme.twilight2)
                        .cornerRadius(AppTheme.buttonRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.buttonRadius)
                                .stroke(selected == mood ? AppTheme.primaryBlue : .clear, lineWidth: 2)
                        )
                    }
                }
            }
            .padding(.horizontal)

            Spacer()

            Button {
                save()
            } label: {
                Text("Save")
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selected == nil ? AppTheme.primaryBlue.opacity(0.3) : AppTheme.primaryBlue)
                    .cornerRadius(AppTheme.buttonRadius)
            }
            .disabled(selected == nil)
            .padding()
        }
        .background(AppTheme.background.ignoresSafeArea())
    }

    private func save() {
        guard let m = selected else { return }
        let level: Int = {
            switch m {
            case .calm: return 1
            case .okay: return 2
            case .stressed: return 3
            case .overwhelmed: return 4
            case .tired: return 3
            }
        }()
        context.insert(MoodCheckIn(mood: m.rawValue, stressLevel: level))
        context.insert(CalmLog(kind: .mood))   // feeds the Calm Ring + badges

        // Update the streak via the shared, unit-tested rules.
        if let profile = profiles.first {
            let result = StreakLogic.afterCheckIn(
                currentStreak: profile.currentStreak,
                longestStreak: profile.longestStreak,
                lastCheckIn: profile.lastCheckInDate
            )
            profile.currentStreak = result.currentStreak
            profile.longestStreak = result.longestStreak
            profile.lastCheckInDate = result.lastCheckIn
        }
        try? context.save()
        dismiss()
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [
            UserProfile.self,
            MoodCheckIn.self,
            RoutineTask.self,
            Deadline.self,
            BreathingSession.self
        ], inMemory: true)
}
