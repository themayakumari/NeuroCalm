//
//  RootView.swift
//  NeuroCalm
//
//  Decides whether to show Welcome/Onboarding or the main app.
//

import SwiftUI
import SwiftData

struct RootView: View {
    @EnvironmentObject private var auth: AuthService
    // @Query automatically reads from SwiftData and updates the view
    // when the data changes. We use it to check if a profile exists.
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext
    /// The account this phone's data has been confirmed to belong to.
    @State private var claimedUid: String?
    @State private var claimFailed = false
    @State private var didOpen = false

    /// UI tests bypass sign-in so the screen tour can reach the app.
    private var bypassAuth: Bool {
        ProcessInfo.processInfo.arguments.contains("UI-TESTING")
    }

    var body: some View {
        Group {
            if !auth.isSignedIn && !bypassAuth {
                // Signed out → sign in first.
                LoginView()
            } else if !bypassAuth && claimedUid != auth.uid {
                // Keep this phone's data hidden until it's confirmed to be theirs.
                claimStatus
            } else if let profile = profiles.first, profile.hasCompletedOnboarding {
                // Signed in and onboarded → the main app.
                AdaptiveMainView()
            } else {
                // Signed in but new → welcome + onboarding.
                WelcomeView()
            }
        }
        .onAppear {
            // Seed sample data the very first time the app runs,
            // so the screens look populated when you're exploring.
            SampleData.seedIfNeeded(context: modelContext)
            // This also runs each time the screen switches, so only the first
            // run tells us who was signed in when the app opened.
            guard !didOpen else { return }
            didOpen = true
            claimLocalData(wasSignedInAtLaunch: true)
        }
        .onChange(of: auth.uid) { _, _ in claimLocalData(wasSignedInAtLaunch: false) }
    }

    @ViewBuilder
    private var claimStatus: some View {
        if claimFailed {
            VStack(spacing: 16) {
                Text("We couldn't clear the previous account's data from this phone.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppTheme.textPrimary)
                Button("Try again") { claimLocalData(wasSignedInAtLaunch: false) }
                Button("Sign out", role: .destructive) { auth.signOut() }
            }
            .padding(32)
        } else {
            ProgressView()
        }
    }

    /// Bring back challenges from the account, after a reinstall or on a new phone.
    private func restoreTeamChallenges(uid: String) async {
        guard let saved = try? await TeamService.accountChallenges(uid: uid), auth.uid == uid else { return }
        let existing = (try? modelContext.fetch(FetchDescriptor<TeamMembership>())) ?? []
        for challenge in saved where !existing.contains(where: { $0.challengeId == challenge.id }) {
            modelContext.insert(TeamMembership(challengeId: challenge.id, title: challenge.title))
        }
        try? modelContext.save()
    }

    /// A different account never sees the previous student's moods and chats.
    private func claimLocalData(wasSignedInAtLaunch: Bool) {
        claimFailed = false
        guard let uid = auth.uid else {
            claimedUid = nil
            return
        }
        do {
            try LocalData.claim(forAccount: uid, wasSignedInAtLaunch: wasSignedInAtLaunch, context: modelContext)
            claimedUid = uid
            Task { await restoreTeamChallenges(uid: uid) }
        } catch {
            claimFailed = true
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AuthService())
        .modelContainer(for: [
            UserProfile.self,
            MoodCheckIn.self,
            RoutineTask.self,
            Deadline.self,
            BreathingSession.self
        ], inMemory: true)
}
