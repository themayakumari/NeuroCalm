//
//  MainSplitView.swift
//  NeuroCalm
//
//  The iPad/regular-width equivalent of MainTabView: a persistent
//  sidebar instead of a bottom tab bar, which is the idiomatic
//  navigation pattern on the bigger screen (matches Health, Notes,
//  Settings, etc). AdaptiveMainView decides which one to show.
//

import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case home, breathe, relax, practices, challenges, planner, assistant, progress

    var id: String { rawValue }

    /// iPad sidebar has room for everything.
    static var sidebarItems: [AppSection] { allCases }

    /// iPhone's tab bar shows at most 5 before iOS buries the rest under
    /// "More", so Relax, Practices, and Challenges live on the Home screen
    /// there (as cards) instead of tabs.
    static var tabItems: [AppSection] { [.home, .breathe, .planner, .assistant, .progress] }

    var title: String {
        switch self {
        case .home: return "Home"
        case .breathe: return "Breathe"
        case .relax: return "Relax"
        case .practices: return "Practices"
        case .challenges: return "Challenges"
        case .planner: return "Planner"
        case .assistant: return "Assistant"
        case .progress: return "Progress"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .breathe: return "wind"
        case .relax: return "moon.stars.fill"
        case .practices: return "leaf.fill"
        case .challenges: return "trophy.fill"
        case .planner: return "calendar"
        case .assistant: return "message.fill"
        case .progress: return "chart.bar.fill"
        }
    }

    /// The screen this section shows — shared by both the sidebar (iPad)
    /// and the tab bar (iPhone) so they can never drift apart.
    @ViewBuilder
    var destination: some View {
        switch self {
        case .home: HomeView()
        case .breathe: BreathingView()
        case .relax: RelaxView()
        case .practices: PracticeLibraryView()
        case .challenges: ChallengesView()
        case .planner: PlannerView()
        case .assistant: AssistantView()
        case .progress: StatsView()
        }
    }
}

struct MainSplitView: View {
    @State private var selection: AppSection? = .home

    var body: some View {
        NavigationSplitView {
            List(AppSection.sidebarItems, selection: $selection) { section in
                Label(section.title, systemImage: section.icon)
                    .tag(section)
            }
            .navigationTitle("NeuroCalm")
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
        } detail: {
            (selection ?? .home).destination
        }
        .tint(AppTheme.primaryBlue)
    }
}

#Preview {
    MainSplitView()
        .environmentObject(AudioPlayerService())
        .modelContainer(for: [
            UserProfile.self,
            MoodCheckIn.self,
            RoutineTask.self,
            Deadline.self,
            BreathingSession.self,
            CalmLog.self,
            ActiveChallenge.self
        ], inMemory: true)
}
