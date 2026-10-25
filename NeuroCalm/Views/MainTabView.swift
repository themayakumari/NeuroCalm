//
//  MainTabView.swift
//  NeuroCalm
//
//  The bottom tab bar of the main app.
//

import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            ForEach(AppSection.tabItems) { section in
                section.destination
                    .tabItem {
                        Label(section.title, systemImage: section.icon)
                    }
            }
        }
        .tint(AppTheme.primaryBlue)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AudioPlayerService())
        .modelContainer(for: [
            UserProfile.self,
            MoodCheckIn.self,
            RoutineTask.self,
            Deadline.self,
            BreathingSession.self
        ], inMemory: true)
}
