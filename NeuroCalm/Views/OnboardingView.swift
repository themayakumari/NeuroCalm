//
//  OnboardingView.swift
//  NeuroCalm
//
//  Multi-step onboarding: name → mood → goals → done.
//

import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]

    // Track which onboarding step we're on (0..2)
    @State private var step: Int = 0

    // Values collected during onboarding
    @State private var name: String = ""
    @State private var selectedMood: Mood? = nil
    @State private var selectedGoals: Set<String> = []

    private let availableGoals = [
        "Study Focus", "Stress Relief", "Better Sleep",
        "Daily Routine", "Exam Prep", "Build Confidence"
    ]

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 24) {
                // Progress dots at the top
                HStack(spacing: 8) {
                    ForEach(0..<3) { i in
                        Capsule()
                            .fill(i == step ? AppTheme.primaryBlue : AppTheme.lavender.opacity(0.4))
                            .frame(width: i == step ? 24 : 8, height: 8)
                            .animation(.spring(), value: step)
                    }
                }
                .padding(.top, 24)

                // Show the right step
                Group {
                    switch step {
                    case 0: nameStep
                    case 1: moodStep
                    default: goalsStep
                    }
                }
                .frame(maxHeight: .infinity)
                .transition(.opacity)

                // Continue / Finish button
                Button {
                    advance()
                } label: {
                    Text(step == 2 ? "Finish Setup" : "Continue")
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canAdvance ? AppTheme.primaryBlue : AppTheme.primaryBlue.opacity(0.3))
                        .cornerRadius(AppTheme.buttonRadius)
                }
                .disabled(!canAdvance)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .adaptiveContentWidth(480)
        }
    }

    // MARK: - Step 0: Name

    private var nameStep: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("What should we call you?")
                    .font(AppTheme.display(28))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("First name is fine — it stays on your device.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            TextField("Your name", text: $name)
                .font(.title3)
                .foregroundStyle(AppTheme.textPrimary)
                .padding()
                .background(AppTheme.twilight2)
                .cornerRadius(AppTheme.buttonRadius)
                .padding(.horizontal, 32)
                .autocorrectionDisabled()
        }
        .padding()
    }

    // MARK: - Step 1: Mood

    private var moodStep: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("How are you feeling today?")
                    .font(AppTheme.display(28))
                    .foregroundStyle(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                Text("There's no wrong answer.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            VStack(spacing: 12) {
                ForEach(Mood.allCases) { mood in
                    Button {
                        selectedMood = mood
                    } label: {
                        HStack {
                            Text(mood.emoji)
                                .font(.title)
                            Text(mood.label)
                                .font(.title3)
                                .foregroundStyle(AppTheme.textPrimary)
                            Spacer()
                            if selectedMood == mood {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(AppTheme.primaryBlue)
                            }
                        }
                        .padding()
                        .background(AppTheme.twilight2)
                        .cornerRadius(AppTheme.buttonRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.buttonRadius)
                                .stroke(selectedMood == mood ? AppTheme.primaryBlue : .clear, lineWidth: 2)
                        )
                    }
                }
            }
            .padding(.horizontal, 24)
        }
        .padding()
    }

    // MARK: - Step 2: Goals

    private var goalsStep: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("What would help you most?")
                    .font(AppTheme.display(28))
                    .foregroundStyle(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Pick as many as you like.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            // 2-column grid of selectable goal chips
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(availableGoals, id: \.self) { goal in
                    let isSelected = selectedGoals.contains(goal)
                    Button {
                        if isSelected { selectedGoals.remove(goal) }
                        else { selectedGoals.insert(goal) }
                    } label: {
                        Text(goal)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(isSelected ? AppTheme.ink : AppTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(isSelected ? AppTheme.primaryBlue : AppTheme.twilight2)
                            .cornerRadius(AppTheme.buttonRadius)
                    }
                }
            }
            .padding(.horizontal, 24)
        }
        .padding()
    }

    // MARK: - Logic

    /// Whether the user can move to the next step.
    private var canAdvance: Bool {
        switch step {
        case 0: return !name.trimmingCharacters(in: .whitespaces).isEmpty
        case 1: return selectedMood != nil
        case 2: return !selectedGoals.isEmpty
        default: return false
        }
    }

    private func advance() {
        if step < 2 {
            withAnimation { step += 1 }
        } else {
            finishOnboarding()
        }
    }

    /// Save everything and exit onboarding.
    private func finishOnboarding() {
        // Grab (or create) the profile from SwiftData.
        let profile = profiles.first ?? UserProfile()
        if profiles.first == nil { modelContext.insert(profile) }

        profile.name = name.trimmingCharacters(in: .whitespaces)
        profile.goals = Array(selectedGoals)
        profile.hasCompletedOnboarding = true
        profile.lastCheckInDate = Date()
        profile.currentStreak = 1

        // Save the mood check-in too.
        if let mood = selectedMood {
            let level: Int = {
                switch mood {
                case .calm: return 1
                case .okay: return 2
                case .stressed: return 3
                case .overwhelmed: return 4
                case .tired: return 3
                }
            }()
            let checkIn = MoodCheckIn(mood: mood.rawValue, stressLevel: level)
            modelContext.insert(checkIn)
        }

        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    OnboardingView()
        .modelContainer(for: [UserProfile.self, MoodCheckIn.self], inMemory: true)
}
