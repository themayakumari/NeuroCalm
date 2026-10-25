//
//  ChallengesView.swift
//  NeuroCalm
//
//  Calm challenges — your active goals with progress, featured challenges to
//  start, and a "with friends" team section (the shared/multiplayer part lands
//  with the team backend).
//

import SwiftUI
import SwiftData

struct ChallengesView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var auth: AuthService
    @Query private var active: [ActiveChallenge]
    @Query private var logs: [CalmLog]
    @Query(sort: \TeamMembership.joinedAt, order: .reverse) private var memberships: [TeamMembership]

    @State private var showCreate = false
    @State private var showJoin = false

    private var activeIds: Set<String> { Set(active.map { $0.templateId }) }
    private var availableTemplates: [ChallengeTemplate] {
        ChallengeCatalog.featured.filter { !activeIds.contains($0.id) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if !active.isEmpty {
                    sectionHeader("Your challenges")
                    ForEach(active) { ac in
                        if let template = ChallengeCatalog.template(id: ac.templateId) {
                            activeCard(ac, template)
                        }
                    }
                }

                if !availableTemplates.isEmpty {
                    sectionHeader("Featured challenges")
                    ForEach(availableTemplates) { template in
                        availableCard(template)
                    }
                }

                if FeatureFlags.teamChallengesEnabled {
                sectionHeader("With friends")
                if auth.isSignedIn {
                    ForEach(memberships) { m in
                        NavigationLink {
                            TeamChallengeDetailView(challengeId: m.challengeId)
                        } label: {
                            teamRow(symbol: "person.3.fill", title: m.title,
                                    subtitle: "See the leaderboard", trailing: "chevron.right")
                        }
                        .buttonStyle(.plain)
                    }
                    Button { showJoin = true } label: {
                        teamRow(symbol: "person.2.fill", title: "Join with a code",
                                subtitle: "Join a friend's challenge", trailing: "chevron.right")
                    }
                    .buttonStyle(.plain)
                    Button { showCreate = true } label: {
                        teamRow(symbol: "plus.circle.fill", title: "Create a challenge",
                                subtitle: "Start one with friends", trailing: "chevron.right")
                    }
                    .buttonStyle(.plain)
                } else {
                    teamRow(symbol: "person.crop.circle.badge.exclamationmark",
                            title: "Sign in to play with friends",
                            subtitle: "Team challenges need an account", trailing: nil)
                }
                }
            }
            .padding()
            .adaptiveContentWidth()
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Challenges")
        .sheet(isPresented: $showCreate) { CreateTeamChallengeSheet() }
        .sheet(isPresented: $showJoin) { JoinTeamChallengeSheet() }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(AppTheme.mono(11))
            .textCase(.uppercase)
            .foregroundStyle(AppTheme.mist)
    }

    // MARK: - Active challenge card (with progress)

    private func activeCard(_ ac: ActiveChallenge, _ template: ChallengeTemplate) -> some View {
        let p = ChallengeLogic.progress(template: template, start: ac.startDate, logs: logs)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                icon(template.symbol, filled: true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(template.title).font(.headline).foregroundStyle(AppTheme.cream)
                    Text(statusLine(p, template)).font(.caption).foregroundStyle(AppTheme.mist)
                }
                Spacer()
                if p.isComplete {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title3).foregroundStyle(AppTheme.sage)
                }
            }

            // Progress bar.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppTheme.background).frame(height: 10)
                    Capsule()
                        .fill(p.isComplete ? AnyShapeStyle(AppTheme.sage)
                              : AnyShapeStyle(LinearGradient(colors: [AppTheme.sage, AppTheme.ember], startPoint: .leading, endPoint: .trailing)))
                        .frame(width: max(10, geo.size.width * p.fraction), height: 10)
                }
            }
            .frame(height: 10)

            HStack {
                Text("\(p.current) / \(p.target) \(template.metric.unit)")
                    .font(AppTheme.mono(12)).foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Button(role: .destructive) { leave(ac) } label: {
                    Text("Leave").font(.caption)
                }
            }
        }
        .padding(18)
        .background(AppTheme.twilight2)
        .cornerRadius(AppTheme.cardRadius)
    }

    private func statusLine(_ p: ChallengeProgress, _ template: ChallengeTemplate) -> String {
        if p.isComplete { return "Completed — nice work! 🎉" }
        if p.isExpired { return "Challenge ended" }
        return "\(p.daysLeft) day\(p.daysLeft == 1 ? "" : "s") left"
    }

    // MARK: - Available (featured) card

    private func availableCard(_ template: ChallengeTemplate) -> some View {
        HStack(spacing: 14) {
            icon(template.symbol, filled: false)
            VStack(alignment: .leading, spacing: 3) {
                Text(template.title).font(.headline).foregroundStyle(AppTheme.cream)
                Text(template.detail).font(.subheadline).foregroundStyle(AppTheme.mist)
            }
            Spacer()
            Button { start(template) } label: {
                Text("Start")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(AppTheme.ink)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(AppTheme.sage)
                    .clipShape(Capsule())
            }
        }
        .padding(18)
        .background(AppTheme.twilight2)
        .cornerRadius(AppTheme.cardRadius)
    }

    // MARK: - Team rows

    private func teamRow(symbol: String, title: String, subtitle: String, trailing: String?) -> some View {
        HStack(spacing: 14) {
            icon(symbol, filled: false)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline).foregroundStyle(AppTheme.cream)
                Text(subtitle).font(.subheadline).foregroundStyle(AppTheme.mist)
            }
            Spacer()
            if let trailing {
                Image(systemName: trailing).foregroundStyle(AppTheme.mist)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.twilight2)
        .cornerRadius(AppTheme.cardRadius)
    }

    private func icon(_ symbol: String, filled: Bool) -> some View {
        ZStack {
            Circle().fill(AppTheme.sage.opacity(filled ? 0.22 : 0.12)).frame(width: 48, height: 48)
            Image(systemName: symbol).font(.title3).foregroundStyle(AppTheme.sage)
        }
    }

    private func start(_ template: ChallengeTemplate) {
        context.insert(ActiveChallenge(templateId: template.id))
        // Drop a matching entry into the Planner so the challenge shows up
        // alongside the student's other deadlines.
        let due = Calendar.current.date(byAdding: .day, value: template.days, to: .now) ?? .now
        let deadline = Deadline(title: planEntryTitle(template),
                                dueDate: due, subject: "NeuroCalm Challenge")
        context.insert(deadline)
        NotificationService.shared.scheduleDeadlineReminder(for: deadline)
        try? context.save()
    }

    private func leave(_ ac: ActiveChallenge) {
        // Remove the Planner entry we created when the challenge started.
        if let template = ChallengeCatalog.template(id: ac.templateId) {
            let title = planEntryTitle(template)
            let descriptor = FetchDescriptor<Deadline>(predicate: #Predicate { $0.title == title })
            if let matches = try? context.fetch(descriptor) {
                for d in matches { context.delete(d) }
            }
        }
        context.delete(ac)
        try? context.save()
    }

    private func planEntryTitle(_ template: ChallengeTemplate) -> String {
        "Challenge: \(template.title)"
    }
}

#Preview {
    NavigationStack { ChallengesView() }
        .environmentObject(AuthService())
        .modelContainer(for: [ActiveChallenge.self, CalmLog.self, TeamMembership.self], inMemory: true)
        .preferredColorScheme(.dark)
}
