//
//  AdaptiveMainView.swift
//  NeuroCalm
//
//  Picks the sidebar (iPad, regular width) or the bottom tab bar
//  (iPhone, and iPad in Slide Over / compact Split View — the
//  system reports .compact there too, so this "just works").
//

import SwiftUI

struct AdaptiveMainView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // Shared across every section so relaxation audio keeps playing while
    // the user moves around the app.
    @StateObject private var audioPlayer = AudioPlayerService()

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                MainSplitView()
            } else {
                MainTabView()
            }
        }
        .environmentObject(audioPlayer)
    }
}

#Preview {
    AdaptiveMainView()
        .modelContainer(for: [
            UserProfile.self,
            MoodCheckIn.self,
            RoutineTask.self,
            Deadline.self,
            BreathingSession.self
        ], inMemory: true)
}
