//
//  TeamChallengeViews.swift
//  NeuroCalm
//
//  Create / join sheets and the leaderboard for shared "with friends" challenges.
//  The only things friends see are the name picked here and the challenge count.
//

import SwiftUI
import SwiftData

// MARK: - Create

struct CreateTeamChallengeSheet: View {
    @EnvironmentObject private var auth: AuthService
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @AppStorage(LeaderboardName.key) private var leaderboardName = ""

    @State private var created: TeamChallenge?
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let created {
                        successView(created)
                    } else {
                        Text("Pick a challenge to start with friends. You'll get a code to share.")
                            .font(.subheadline).foregroundStyle(AppTheme.textSecondary)
                        LeaderboardNameField(name: $leaderboardName)
                        ForEach(ChallengeCatalog.featured) { template in
                            Button { create(template) } label: { templateRow(template) }
                                .buttonStyle(.plain)
                                .disabled(busy)
                        }
                    }
                    if let error {
                        Text(error).font(.caption).foregroundStyle(AppTheme.ember)
                    }
                }
                .padding()
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Create challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
    }

    private func templateRow(_ t: ChallengeTemplate) -> some View {
        HStack(spacing: 14) {
            Image(systemName: t.symbol).font(.title3).foregroundStyle(AppTheme.sage).frame(width: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(t.title).font(.headline).foregroundStyle(AppTheme.cream)
                Text(t.detail).font(.caption).foregroundStyle(AppTheme.mist)
            }
            Spacer()
            if busy { ProgressView() } else { Image(systemName: "chevron.right").foregroundStyle(AppTheme.mist) }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.twilight2).cornerRadius(AppTheme.cardRadius)
    }

    private func successView(_ tc: TeamChallenge) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill").font(.largeTitle).foregroundStyle(AppTheme.sage)
            Text(tc.title).font(AppTheme.display(22)).foregroundStyle(AppTheme.textPrimary)
            Text("Share this code with friends:").font(.subheadline).foregroundStyle(AppTheme.textSecondary)
            Text(tc.code)
                .font(AppTheme.mono(30, weight: .bold))
                .foregroundStyle(AppTheme.sage)
                .padding(.vertical, 12).padding(.horizontal, 24)
                .background(AppTheme.twilight2).cornerRadius(AppTheme.cardRadius)
            ShareLink(item: "Join my NeuroCalm challenge with code \(tc.code) 🌿") {
                Text("Share code").fontWeight(.semibold)
                    .foregroundStyle(AppTheme.ink)
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(AppTheme.sage).clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity).padding(.top, 20)
    }

    private func create(_ template: ChallengeTemplate) {
        guard let uid = auth.uid else { error = TeamError.notSignedIn.errorDescription; return }
        busy = true; error = nil
        Task { @MainActor in
            defer { busy = false }
            do {
                let tc = try await TeamService.create(template: template, uid: uid, name: leaderboardName)
                context.insert(TeamMembership(challengeId: tc.id, title: tc.title))
                try? context.save()
                created = tc
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}

// MARK: - Join

struct JoinTeamChallengeSheet: View {
    @EnvironmentObject private var auth: AuthService
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @AppStorage(LeaderboardName.key) private var leaderboardName = ""
    @Query private var memberships: [TeamMembership]

    @State private var code = ""
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Text("Enter the code your friend shared.")
                    .font(.subheadline).foregroundStyle(AppTheme.textSecondary)
                    .padding(.top, 8)
                TextField("CHALLENGE CODE", text: $code)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.center)
                    .font(AppTheme.mono(24, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding().background(AppTheme.twilight2).cornerRadius(AppTheme.cardRadius)
                LeaderboardNameField(name: $leaderboardName)
                if let error { Text(error).font(.caption).foregroundStyle(AppTheme.ember).multilineTextAlignment(.center) }
                Button { join() } label: {
                    Group { if busy { ProgressView().tint(AppTheme.ink) } else { Text("Join").fontWeight(.semibold) } }
                        .foregroundStyle(AppTheme.ink).frame(maxWidth: .infinity).frame(height: 52)
                        .background(AppTheme.sage).clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
                }
                .disabled(code.isEmpty || busy)
                Spacer()
            }
            .padding()
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Join with a code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }

    private func join() {
        guard let uid = auth.uid else { error = TeamError.notSignedIn.errorDescription; return }
        busy = true; error = nil
        Task { @MainActor in
            defer { busy = false }
            do {
                let tc = try await TeamService.join(code: code, uid: uid, name: leaderboardName)
                if !memberships.contains(where: { $0.challengeId == tc.id }) {
                    context.insert(TeamMembership(challengeId: tc.id, title: tc.title))
                    try? context.save()
                }
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}

// MARK: - Leaderboard

struct TeamChallengeDetailView: View {
    let challengeId: String

    @EnvironmentObject private var auth: AuthService
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var logs: [CalmLog]
    @Query private var memberships: [TeamMembership]

    @State private var challenge: TeamChallenge?
    @State private var error: String?
    @State private var showLeaveConfirm = false
    @State private var leaving = false
    @AppStorage(BlockedMembers.key) private var blockedRaw = ""
    @State private var reportTarget: MemberProgress?
    @State private var blockTarget: MemberProgress?
    @State private var showReportSent = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let challenge, let template = challenge.template {
                    header(challenge, template)
                    Text("Leaderboard")
                        .font(AppTheme.mono(11)).textCase(.uppercase).foregroundStyle(AppTheme.mist)
                    let visible = BlockedMembers.visible(challenge.members, raw: blockedRaw)
                    ForEach(Array(visible.enumerated()), id: \.element.id) { index, member in
                        memberRow(index: index, member: member, target: template.target, unit: template.metric.unit)
                    }
                    if visible.count < challenge.members.count {
                        Button { unblock(challenge.members) } label: {
                            Text("Unblock hidden members (\(challenge.members.count - visible.count))")
                                .font(.caption)
                        }
                    }
                    if let error {
                        Text(error).font(.caption).foregroundStyle(AppTheme.ember)
                    }
                    Button(role: .destructive) { showLeaveConfirm = true } label: {
                        Group { if leaving { ProgressView() } else { Text("Leave challenge") } }
                            .font(.subheadline).frame(maxWidth: .infinity).padding(.vertical, 12)
                    }
                    .disabled(leaving)
                    .padding(.top, 8)
                } else if let error {
                    Text(error).font(.subheadline).foregroundStyle(AppTheme.ember)
                    Button(role: .destructive) { leave() } label: {
                        Text("Remove from my list").font(.subheadline)
                    }
                } else {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                }
            }
            .padding()
            .adaptiveContentWidth()
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle(challenge?.title ?? "Challenge")
        .navigationBarTitleDisplayMode(.inline)
        .task { await refresh() }
        .refreshable { await refresh() }
        .alert("Leave this challenge?", isPresented: $showLeaveConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Leave", role: .destructive) { leave() }
        } message: {
            Text("Your name and progress will be removed from the leaderboard. You can rejoin with the code.")
        }
        .alert("Report this name?", isPresented: Binding(
            get: { reportTarget != nil },
            set: { if !$0 { reportTarget = nil } }
        ), presenting: reportTarget) { member in
            Button("Cancel", role: .cancel) {}
            Button("Report", role: .destructive) { report(member) }
        } message: { member in
            Text("We'll review \"\(member.name)\" and remove it if it's offensive. They won't know who reported it.")
        }
        .alert("Report sent", isPresented: $showReportSent) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Thanks for letting us know. We review reports every day.")
        }
        .alert("Block this person?", isPresented: Binding(
            get: { blockTarget != nil },
            set: { if !$0 { blockTarget = nil } }
        ), presenting: blockTarget) { member in
            Button("Cancel", role: .cancel) {}
            Button("Block", role: .destructive) { block(member) }
        } message: { member in
            Text("You won't see \"\(member.name)\" on your leaderboards. They won't be told.")
        }
    }

    private func header(_ tc: TeamChallenge, _ template: ChallengeTemplate) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(template.detail).font(.subheadline).foregroundStyle(AppTheme.textSecondary)
            HStack(spacing: 6) {
                Text("Code").font(.caption).foregroundStyle(AppTheme.mist)
                Text(tc.code).font(AppTheme.mono(14, weight: .semibold)).foregroundStyle(AppTheme.sage)
                Spacer()
                ShareLink(item: "Join my NeuroCalm challenge with code \(tc.code) 🌿") {
                    Label("Invite", systemImage: "square.and.arrow.up").font(.caption)
                }
            }
            .padding(12).background(AppTheme.twilight2).cornerRadius(AppTheme.cardRadius)
        }
    }

    private func memberRow(index: Int, member: MemberProgress, target: Int, unit: String) -> some View {
        let isMe = member.id == auth.uid
        let fraction = target == 0 ? 0 : min(1.0, Double(member.current) / Double(target))
        return HStack(spacing: 12) {
            Text("\(index + 1)")
                .font(AppTheme.mono(13, weight: .semibold))
                .foregroundStyle(index == 0 ? AppTheme.ember : AppTheme.mist)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(isMe ? "\(member.name) (you)" : member.name)
                        .font(.subheadline).fontWeight(isMe ? .semibold : .regular)
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Text("\(member.current)/\(target) \(unit)")
                        .font(AppTheme.mono(11)).foregroundStyle(AppTheme.textSecondary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(AppTheme.background).frame(height: 8)
                        Capsule().fill(isMe ? AppTheme.sage : AppTheme.mist)
                            .frame(width: max(8, geo.size.width * fraction), height: 8)
                    }
                }
                .frame(height: 8)
            }
            if !isMe {
                Menu {
                    Button { reportTarget = member } label: {
                        Label("Report name", systemImage: "flag")
                    }
                    Button(role: .destructive) { blockTarget = member } label: {
                        Label("Block", systemImage: "hand.raised")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.mist)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Options for \(member.name)")
            }
        }
        .padding(14)
        .background(AppTheme.twilight2)
        .cornerRadius(AppTheme.cardRadius)
        .overlay(RoundedRectangle(cornerRadius: AppTheme.cardRadius).stroke(isMe ? AppTheme.sage.opacity(0.5) : .clear, lineWidth: 1))
    }

    private func refresh() async {
        guard let uid = auth.uid else { error = TeamError.notSignedIn.errorDescription; return }
        do {
            var tc = try await TeamService.fetch(id: challengeId)
            if let template = tc.template {
                // Push my latest progress, then re-read so the board is current.
                let mine = ChallengeLogic.progress(template: template, start: tc.startDate, logs: logs).current
                try? await TeamService.updateProgress(id: challengeId, uid: uid, current: mine)
                tc = try await TeamService.fetch(id: challengeId)
            }
            challenge = tc
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func leave() {
        guard let uid = auth.uid else { error = TeamError.notSignedIn.errorDescription; return }
        leaving = true
        Task { @MainActor in
            defer { leaving = false }
            do {
                try await TeamService.leave(id: challengeId, uid: uid)
            } catch TeamError.notFound {
                // Already gone; just drop it from this phone.
            } catch {
                self.error = error.localizedDescription
                return
            }
            removeLocal()
            dismiss()
        }
    }

    private func report(_ member: MemberProgress) {
        guard let uid = auth.uid else { error = TeamError.notSignedIn.errorDescription; return }
        Task { @MainActor in
            do {
                try await TeamService.report(challengeId: challengeId, member: member, reporterUid: uid)
                showReportSent = true
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    private func block(_ member: MemberProgress) {
        var ids = BlockedMembers.ids(from: blockedRaw)
        ids.insert(member.id)
        blockedRaw = BlockedMembers.raw(from: ids)
    }

    /// Show this challenge's blocked members again.
    private func unblock(_ members: [MemberProgress]) {
        let ids = BlockedMembers.ids(from: blockedRaw).subtracting(members.map(\.id))
        blockedRaw = BlockedMembers.raw(from: ids)
    }

    /// Forget this challenge on this phone.
    private func removeLocal() {
        for m in memberships where m.challengeId == challengeId { context.delete(m) }
        try? context.save()
    }
}

// MARK: - Leaderboard name

/// The name friends see on team leaderboards, remembered between challenges.
enum LeaderboardName {
    static let key = "teamDisplayName"
}

struct LeaderboardNameField: View {
    @Binding var name: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Your name on the leaderboard")
                .font(.caption).foregroundStyle(AppTheme.mist)
            TextField("Nickname", text: $name)
                .textInputAutocapitalization(.words)
                .foregroundStyle(AppTheme.textPrimary)
                .padding(12).background(AppTheme.twilight2).cornerRadius(AppTheme.cardRadius)
                .onChange(of: name) { _, new in
                    if new.count > TeamService.maxNameLength {
                        name = String(new.prefix(TeamService.maxNameLength))
                    }
                }
            Text("Use a nickname, not your full name. If you leave it blank, you'll show as Friend. People in the challenge see this name and your count, nothing else. Offensive names aren't allowed and will be removed.")
                .font(.caption2).foregroundStyle(AppTheme.textSecondary)
        }
    }
}
