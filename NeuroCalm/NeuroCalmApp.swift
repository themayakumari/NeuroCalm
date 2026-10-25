//
//  NeuroCalmApp.swift
//  NeuroCalm
//
//  Student Stress & Focus Companion
//

import SwiftUI
import SwiftData
import FirebaseCore
import GoogleSignIn

// @main marks this as the entry point of the app.
// The first thing that runs when you launch NeuroCalm.
@main
struct NeuroCalmApp: App {

    @StateObject private var auth = AuthService()

    init() {
        // Connect to the Firebase project (config comes from
        // GoogleService-Info.plist bundled in the app).
        FirebaseApp.configure()
    }

    // Sets up SwiftData — Apple's modern storage system.
    // Every model we want to save (mood check-ins, deadlines, etc.)
    // must be listed here so SwiftData knows about it.
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            UserProfile.self,
            MoodCheckIn.self,
            RoutineTask.self,
            Deadline.self,
            BreathingSession.self,
            Bookmark.self,
            CalmLog.self,
            ActiveChallenge.self,
            TeamMembership.self,
            AssistantConversation.self,
            AssistantMessage.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        // Try to open the on-disk store normally.
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // The store on disk couldn't be opened — most often an incompatible
            // schema left over from an earlier build, or a store that got
            // corrupted by an interrupted write. Rather than hard-crash on every
            // launch (a crash loop the user can only escape by deleting the app),
            // wipe the local store and start fresh. This app keeps nothing that
            // can't be re-seeded, so a reset is safe.
            print("⚠️ ModelContainer open failed (\(error)). Resetting local store.")
            Self.deleteStoreFiles()
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                // Disk is still unusable — fall back to an in-memory store so the
                // app at least launches instead of aborting. Data won't persist,
                // but the user gets a working session rather than a dead icon.
                print("⚠️ Rebuild after reset failed (\(error)). Falling back to in-memory store.")
                let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                do {
                    return try ModelContainer(for: schema, configurations: [memoryConfig])
                } catch {
                    fatalError("Could not create even an in-memory ModelContainer: \(error)")
                }
            }
        }
    }()

    /// Removes the default SwiftData store (and its -wal / -shm sidecars) from
    /// Application Support so a fresh container can be created.
    private static func deleteStoreFiles() {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        for name in ["default.store", "default.store-wal", "default.store-shm"] {
            try? FileManager.default.removeItem(at: appSupport.appendingPathComponent(name))
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                // Finish Google sign-in when it redirects back to the app.
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
                // The Exhale palette is a fixed dark design, not adaptive,
                // so we lock system chrome (forms, alerts, keyboard) to dark too.
                .preferredColorScheme(.dark)
        }
        .modelContainer(sharedModelContainer)
    }
}
