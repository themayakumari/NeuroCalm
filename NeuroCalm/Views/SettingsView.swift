//
//  SettingsView.swift
//  NeuroCalm
//

import SwiftUI
import SwiftData
import AuthenticationServices

struct SettingsView: View {
    @EnvironmentObject private var auth: AuthService
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var context

    @AppStorage("healthKitEnabled") private var healthKitEnabled = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("calendarSyncEnabled") private var calendarSyncEnabled = false
    @AppStorage("parentSquareICSURL") private var parentSquareICSURL = ""
    @AppStorage(SchoolService.nameKey) private var schoolName = ""

    @State private var showResetConfirm = false
    @State private var showSignOutConfirm = false
    @State private var showDeleteConfirm = false
    @State private var isDeletingAccount = false
    @State private var deleteError: String?
    @State private var showSchoolSheet = false
    @State private var showRemoveSchoolConfirm = false
    @State private var schoolError: String?

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
                    if schoolName.isEmpty {
                        Button("Add my school") { showSchoolSheet = true }
                    } else {
                        LabeledContent("School", value: schoolName)
                        Button("Change school") { showSchoolSheet = true }
                        if !auth.isAnonymous {
                            Button("Remove school", role: .destructive) { showRemoveSchoolConfirm = true }
                        }
                    }
                    if let schoolError {
                        Text(schoolError).font(.caption).foregroundStyle(AppTheme.ember)
                    }
                    Button(role: .destructive) { showSignOutConfirm = true } label: {
                        Text("Sign out")
                    }
                    Button(role: .destructive) { showDeleteConfirm = true } label: {
                        if isDeletingAccount {
                            HStack {
                                Text("Deleting account…")
                                Spacer()
                                ProgressView()
                            }
                        } else {
                            Text("Delete my account")
                        }
                    }
                    .disabled(isDeletingAccount)
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
                LabeledContent("Version", value: appVersion)
                Link("Privacy policy", destination: URL(string: "https://github.com/themayakumari/NeuroCalm/blob/main/docs/privacy.md")!)
                Link("Contact us: themayakumari@gmail.com", destination: URL(string: "mailto:themayakumari@gmail.com")!)
                Link("View on GitHub", destination: URL(string: "https://github.com/themayakumari/NeuroCalm")!)
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
            Text("This deletes everything on this phone: your profile, streaks, moods, tasks, deadlines, sessions, Calm Log, bookmarks, challenges, and assistant chats.")
        }
        .alert("Delete your account?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { deleteAccount() }
        } message: {
            Text(auth.usesAppleSignIn
                 ? "This permanently deletes your NeuroCalm account and all your data on this phone. It can't be undone.\n\nApple will ask you to confirm next. Tap Continue there to finish."
                 : "This permanently deletes your NeuroCalm account and all your data on this phone. It can't be undone.")
        }
        .alert("Couldn't delete your account", isPresented: Binding(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteError ?? "")
        }
        .sheet(isPresented: $showSchoolSheet) { SchoolCodeSheet() }
        .alert("Remove your school?", isPresented: $showRemoveSchoolConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) { removeSchool() }
        } message: {
            Text("Your account will no longer be linked to \(schoolName). You can add it again with the school code.")
        }
        .alert("Sign out?", isPresented: $showSignOutConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Sign out", role: .destructive) { auth.signOut() }
        } message: {
            Text(auth.isAnonymous
                 ? "You joined with a school code, so you can't get back into this account after signing out, and your data on this phone is erased at the next sign-in. To remove your account, use Delete my account instead."
                 : "You can sign back in any time with the same account. If a different account signs in on this phone, your data here is erased.")
        }
    }

    /// "1.1 (2)": the version and build number from the app bundle.
    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    private func removeSchool() {
        guard let uid = auth.uid else { return }
        schoolError = nil
        Task {
            do {
                try await SchoolService.removeFromAccount(uid: uid)
            } catch {
                schoolError = error.localizedDescription
            }
        }
    }

    private func resetAll() {
        LocalData.eraseAll(context: context)
    }

    private func deleteAccount() {
        isDeletingAccount = true
        Task {
            defer { isDeletingAccount = false }
            let teamIds = ((try? context.fetch(FetchDescriptor<TeamMembership>())) ?? [])
                .map(\.challengeId)
            do {
                try await auth.deleteAccount(teamChallengeIds: teamIds)
                LocalData.eraseAll(context: context)
            } catch let error as ASAuthorizationError where error.code == .canceled {
                // The student closed the Apple sheet; nothing was deleted.
                deleteError = "Your account wasn't deleted. To delete it, confirm with Apple when asked."
            } catch {
                deleteError = error.localizedDescription
            }
        }
    }
}

/// Wipes everything NeuroCalm keeps on this device. Used by "Reset all data"
/// and after deleting an account.
enum LocalData {
    /// Every SwiftData model the app stores. Keep in sync with the schema in
    /// `NeuroCalmApp`. Conversations come before messages so the cascade
    /// removes messages cleanly.
    static let allModels: [any PersistentModel.Type] = [
        UserProfile.self, MoodCheckIn.self,
        RoutineTask.self, Deadline.self, BreathingSession.self,
        Bookmark.self, CalmLog.self,
        ActiveChallenge.self, TeamMembership.self,
        AssistantConversation.self, AssistantMessage.self
    ]

    /// Saved settings that hold personal data rather than preferences.
    static let personalKeys = [SchoolService.idKey, SchoolService.nameKey,
                               LeaderboardName.key, BlockedMembers.key, "parentSquareICSURL"]

    /// The account this phone's data belongs to.
    static let ownerKey = "localDataOwnerUid"

    static func eraseAll(context: ModelContext, keepingSchool: Bool = false) {
        try? erase(context: context, keepingSchool: keepingSchool)
    }

    /// Same as `eraseAll`, but reports a failure instead of hiding it.
    static func erase(context: ModelContext, keepingSchool: Bool) throws {
        // SwiftData's modelContext doesn't have a "delete all," so we iterate.
        for type in allModels {
            try context.delete(model: type)
        }
        try context.save()
        let schoolKeys = [SchoolService.idKey, SchoolService.nameKey]
        for key in personalKeys where !(keepingSchool && schoolKeys.contains(key)) {
            UserDefaults.standard.removeObject(forKey: key)
        }
        NotificationService.shared.cancelAllItemReminders()
    }

    /// Call before showing the app to an account. Data on this phone stays for
    /// the account that made it, and is erased for anyone else. Data with no
    /// owner (from an older build) stays only if this account was already
    /// signed in when the app opened; a new sign-in can't be assumed to own it.
    /// The new account's school is left alone, since it may already be restored.
    /// Throws if the erase fails, so the owner stays unchanged and the caller
    /// can keep the old data hidden.
    static func claim(forAccount uid: String, wasSignedInAtLaunch: Bool, context: ModelContext) throws {
        let owner = UserDefaults.standard.string(forKey: ownerKey)
        let keepsData = owner == uid || (owner == nil && wasSignedInAtLaunch)
        if !keepsData {
            try erase(context: context, keepingSchool: true)
            SampleData.seedIfNeeded(context: context)
        }
        UserDefaults.standard.set(uid, forKey: ownerKey)
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .environmentObject(AuthService())
        .modelContainer(for: [UserProfile.self], inMemory: true)
}
