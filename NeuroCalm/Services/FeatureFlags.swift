//
//  FeatureFlags.swift
//  NeuroCalm
//
//  One place to switch features on/off for a given release. The MVP ships the
//  self-contained, offline core; features that depend on a live backend are
//  turned off here so students get a clean experience with zero setup.
//

enum FeatureFlags {

    /// Team / multiplayer challenges write to Firestore and need the backend
    /// configured with security rules (and friends who also use the app). Off
    /// for the MVP. Flip to `true` once the Firebase/Firestore backend is live
    /// to bring back the "With friends" section on the Challenges screen.
    static let teamChallengesEnabled = false
}
