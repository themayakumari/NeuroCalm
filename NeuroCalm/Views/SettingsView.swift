//
//  SettingsView.swift
//  NeuroCalm
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @EnvironmentObject private var auth: AuthService
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var context

    @AppStorage("healthKitEnabled") private var healthKitEnabled = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("calendarSyncEnabled") private var calendarSyncEnabled = false
    @AppStorage("parentSquareICSURL") private var parentSquareICSURL = ""

    @State private var showResetConfirm = false
    @State private var showSignOutConfirm = false

    var profile: UserProfile? { profiles.first }

    var body: some View {
        Form {
            Section("Profile") {
                if let profile {
                    LabeledContent("Name", value: profile.name)
                    LabeledContent("Streak", value: "\(profile.currentStreak) days")
                    LabeledContent("Goals") {
                        Text(profile.goals.joined(separator: ", "))
                            .multilineTextAlignment(.trailing)
                    }
                }
            }

            Section("Account") {
                if auth.isSignedIn {
                    LabeledContent("Signed in as", value: auth.displayName ?? "Apple ID")
                    Button(role: .destructive) { showSignOutConfirm = true } label: {
                        Text("Sign out")
                    }
                } else {
                    Text("Not signed in.")
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }

            Section("Support") {
                NavigationLink {
                    SupportView()
                } label: {
                    Label("Get help now", systemImage: "hand.raised.fill")
                }
                Text("Free, confidential crisis and mental-health lines — any time.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Section("Apple Health") {
                Toggle("Save Mindful Minutes", isOn: $healthKitEnabled)
                    .onChange(of: healthKitEnabled) { _, enabled in
                        if enabled {
                            HealthKitService.shared.requestAuthorization { granted in
                                healthKitEnabled = granted
                            }
                        }
                    }
                Text("Sync your breathing sessions to the Health app as Mindful Minutes.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Section("Calendars") {
                Toggle("Sync iPhone Calendar", isOn: $calendarSyncEnabled)
                Text("Show events from the Calendar app (Apple, Google, or school accounts on your phone) in the Planner.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)

                TextField("Paste a calendar link (.ics / webcal)", text: $parentSquareICSURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                Text("Paste your ParentSquare calendar's subscribe link. In ParentSquare: Account › Calendar › Subscribe/Export to copy the .ics (or webcal) URL. Leave blank to turn off.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Section("Notifications") {
                Toggle("Reminders", isOn: $notificationsEnabled)
                    .onChange(of: notificationsEnabled) { _, enabled in
                        if enabled {
                            NotificationService.shared.requestAuthorization { granted in
                                notificationsEnabled = granted
                                if granted {
                                    NotificationService.shared.scheduleDailyCheckIn()
                                }
                            }
                        } else {
                            NotificationService.shared.cancelDailyCheckIn()
                        }
                    }
                Text("Deadline reminders, routine-task reminders, and a daily check-in nudge.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Section("Assistant") {
                LabeledContent("On-device assistant", value: AppleIntelligenceService.statusDescription)
                Text("The assistant uses on-device Apple Intelligence when available, falling back to the built-in helper. Your chats never leave your phone. A tag under each reply shows which one answered.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Section("About") {
                LabeledContent("Version", value: "1.0 (MVP)")
                LabeledContent("Build", value: buildTimestamp)
                Link("View on GitHub (you)", destination: URL(string: "https://github.com")!)
            }

            Section {
                Button(role: .destructive) {
                    showResetConfirm = true
                } label: {
                    Text("Reset all data")
                }
            }
        }
        .navigationTitle("Settings")
        .alert("Reset everything?", isPresented: $showResetConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) { resetAll() }
        } message: {
            Text("This deletes your profile, streaks, tasks, deadlines, and sessions.")
        }
        .alert("Sign out?", isPresented: $showSignOutConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Sign out", role: .destructive) { auth.signOut() }
        } message: {
            Text("You can sign back in any time with the same account.")
        }
    }

    /// When the app binary was last built — lets you confirm you're running
    /// the newest build (should read close to "now" right after a rebuild).
    private var buildTimestamp: String {
        guard let url = Bundle.main.executableURL,
              let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let date = attrs[.modificationDate] as? Date else { return "unknown" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter.string(from: date)
    }

    private func resetAll() {
        // Delete every entity. SwiftData's modelContext doesn't have a "delete all,"
        // so we iterate.
        let containers: [any PersistentModel.Type] = [
            UserProfile.self, MoodCheckIn.self,
            RoutineTask.self, Deadline.self, BreathingSession.self
        ]
        for type in containers {
            try? context.delete(model: type)
        }
        try? context.save()
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .environmentObject(AuthService())
        .modelContainer(for: [UserProfile.self], inMemory: true)
}
