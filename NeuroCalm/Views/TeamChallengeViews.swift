//
//  TeamChallengeViews.swift
//  NeuroCalm
//
//  Create / join sheets and the leaderboard for shared "with friends" challenges.
//

import SwiftUI
import SwiftData

// MARK: - Create

struct CreateTeamChallengeSheet: View {
    @EnvironmentObject private var auth: AuthService
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

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
                let tc = try await TeamService.create(template: template, uid: uid, name: auth.friendlyName)
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
                let tc = try await TeamService.join(code: code, uid: uid, name: auth.friendlyName)
                context.insert(TeamMembership(challengeId: tc.id, title: tc.title))
                try? context.save()
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
    @Query private var logs: [CalmLog]

    @State private var challenge: TeamChallenge?
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let challenge, let template = challenge.template {
                    header(challenge, template)
                    Text("Leaderboard")
                        .font(AppTheme.mono(11)).textCase(.uppercase).foregroundStyle(AppTheme.mist)
                    ForEach(Array(challenge.members.enumerated()), id: \.element.id) { index, member in
                        memberRow(index: index, member: member, target: template.target, unit: template.metric.unit)
                    }
                } else if let error {
                    Text(error).font(.subheadline).foregroundStyle(AppTheme.ember)
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
}
