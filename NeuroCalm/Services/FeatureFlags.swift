//
//  FeatureFlags.swift
//  NeuroCalm
//
//  One place to switch features on/off for a given release. The MVP ships the
//  self-contained, offline core; features that depend on a live backend are
//  turned off here so students get a clean experience with zero setup.
//

enum FeatureFlags {

    /// Team / multiplayer challenges write to Firestore and need the rules in
    /// `firestore.rules` deployed. Off for the 1.0 MVP, on from 1.1. Shows the
    /// "With friends" section on the Challenges screen.
    static let teamChallengesEnabled = true
}
