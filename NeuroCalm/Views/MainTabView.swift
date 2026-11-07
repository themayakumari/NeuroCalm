//
//  MainTabView.swift
//  NeuroCalm
//
//  The bottom tab bar of the main app, with the shared NowPlayingBar
//  above it.
//

import SwiftUI

struct MainTabView: View {
    @State private var showRelax = false

    var body: some View {
        TabView {
            ForEach(AppSection.tabItems) { section in
                section.destination
                    // Inset on each tab (not the TabView) so the bar sits
                    // above the tab bar, including on pushed screens.
                    .safeAreaInset(edge: .bottom) {
                        NowPlayingBar { showRelax = true }
                    }
                    .tabItem {
                        Label(section.title, systemImage: section.icon)
                    }
            }
        }
        .tint(AppTheme.primaryBlue)
        // Relax isn't a tab on iPhone, so the bar opens it as a sheet.
        .sheet(isPresented: $showRelax) {
            RelaxView()
                .safeAreaInset(edge: .bottom) { NowPlayingBar() }
        }
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
