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

    /// UI tests bypass sign-in so the screen tour can reach the app.
    private var bypassAuth: Bool {
        ProcessInfo.processInfo.arguments.contains("UI-TESTING")
    }

    var body: some View {
        Group {
            if !auth.isSignedIn && !bypassAuth {
                // Signed out → sign in first.
                LoginView()
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
