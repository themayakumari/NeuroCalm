//
//  PracticeDetailView.swift
//  NeuroCalm
//
//  "About this practice" — the teen-friendly intro up top, when it helps, and
//  the fuller description with its source note below.
//

import SwiftUI

struct PracticeDetailView: View {
    let practice: Practice
    @EnvironmentObject private var player: AudioPlayerService
    @Environment(\.modelContext) private var context

    /// Guided-audio tracks linked to this practice (from the Relax library).
    private var audioTracks: [MeditationTrack] {
        guard let ids = practice.audioTrackIds else { return [] }
        return MeditationLibrary.all.filter { ids.contains($0.id) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // Signature animation for this practice.
                PracticeAnimationView(style: practice.animation ?? "breathe")
                    .frame(height: 160)
                    .frame(maxWidth: .infinity)

                // Teen-friendly intro.
                Text(practice.teenFriendly)
                    .font(.title3)
                    .foregroundStyle(AppTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                // "Good for" tags.
                if !practice.goodFor.isEmpty {
                    section("Good for") {
                        FlowChips(items: Array(practice.goodFor.prefix(8)))
                    }
                }

                // The fuller practice description.
                section("The practice") {
                    Text(practice.content)
                        .font(.body)
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Guided audio — playable tracks if linked, else a placeholder.
                section("Guided audio") {
                    if audioTracks.isEmpty {
                        audioPlaceholder
                    } else {
                        VStack(spacing: 10) {
                            ForEach(audioTracks) { track in
                                audioTrackRow(track)
                            }
                        }
                    }
                }

                // Source credit.
                Text(practice.source)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.mist)
                    .padding(.top, 4)
            }
            .padding()
            .adaptiveContentWidth()
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle(practice.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    /// A playable track row (reuses the app-wide audio player, like Relax).
    private func audioTrackRow(_ track: MeditationTrack) -> some View {
        let isCurrent = player.currentTrack?.id == track.id
        return Button {
            if player.currentTrack?.id != track.id {
                context.insert(CalmLog(kind: .relax))
                try? context.save()
            }
            player.play(track)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isCurrent ? AppTheme.sage : AppTheme.sage.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: isCurrent && player.isPlaying ? "pause.fill" : "play.fill")
                        .foregroundStyle(isCurrent ? AppTheme.ink : AppTheme.sage)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(track.title)
                        .font(.subheadline).fontWeight(.medium)
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(track.subtitle)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(track.durationLabel)
                    .font(AppTheme.mono(11))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(14)
            .background(AppTheme.twilight2)
            .cornerRadius(AppTheme.cardRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                    .stroke(isCurrent ? AppTheme.sage.opacity(0.6) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    /// Placeholder for practices with no linked audio yet.
    private var audioPlaceholder: some View {
        HStack(spacing: 14) {
            Image(systemName: "headphones")
                .font(.title3)
                .foregroundStyle(AppTheme.mist)
            VStack(alignment: .leading, spacing: 2) {
                Text("Guided audio coming soon")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textPrimary)
                Text("A spoken walkthrough of this practice")
                    .font(.caption)
                    .foregroundStyle(AppTheme.mist)
            }
            Spacer()
            Image(systemName: "play.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(AppTheme.mist.opacity(0.35))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.twilight2)
        .cornerRadius(AppTheme.cardRadius)
        .opacity(0.85)
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppTheme.mono(11))
                .textCase(.uppercase)
                .foregroundStyle(AppTheme.mist)
            content()
        }
    }
}

/// A simple wrapping row of tag chips.
private struct FlowChips: View {
    let items: [String]

    var body: some View {
        // A lightweight wrap using a lazy grid of adaptive width.
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8, alignment: .leading)], alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.caption)
                    .foregroundStyle(AppTheme.cream)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppTheme.twilight2)
                    .clipShape(Capsule())
            }
        }
    }
}

#Preview {
    NavigationStack {
        PracticeDetailView(practice: KnowledgeBase.shared.practices.first!)
    }
    .environmentObject(AudioPlayerService())
    .preferredColorScheme(.dark)
}
