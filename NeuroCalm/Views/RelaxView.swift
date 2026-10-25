//
//  RelaxView.swift
//  NeuroCalm
//
//  A library of guided relaxation audio (Shavasana, Yoga Nap). Tapping a
//  track plays it; a now-playing bar at the bottom controls playback and
//  persists as the user moves around the app.
//

import SwiftUI
import SwiftData

struct RelaxView: View {
    @EnvironmentObject private var player: AudioPlayerService
    @Environment(\.modelContext) private var context
    @Query private var bookmarks: [Bookmark]

    /// Tracks the user has starred, in the library's order.
    private var savedTracks: [MeditationTrack] {
        let savedIds = Set(bookmarks.filter { $0.kind == Bookmark.meditationKind }.map(\.referenceId))
        return MeditationLibrary.all.filter { savedIds.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    if !savedTracks.isEmpty {
                        section(title: "Saved", tracks: savedTracks)
                    }
                    section(title: savedTracks.isEmpty ? nil : "All practices", tracks: MeditationLibrary.all)
                }
                .padding()
                .adaptiveContentWidth()
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Relax")
            .safeAreaInset(edge: .bottom) {
                if player.currentTrack != nil {
                    nowPlayingBar
                }
            }
        }
    }

    @ViewBuilder
    private func section(title: String?, tracks: [MeditationTrack]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(AppTheme.mono(11))
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            ForEach(tracks) { track in
                trackRow(track)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Guided relaxation")
                .font(AppTheme.display(22))
                .foregroundStyle(AppTheme.textPrimary)
            Text("Lie back, close your eyes, and let the voice guide you.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private func trackRow(_ track: MeditationTrack) -> some View {
        let isCurrent = player.currentTrack?.id == track.id
        let saved = isBookmarked(track)
        return HStack(spacing: 14) {
            Button { playTrack(track) } label: {
                ZStack {
                    Circle()
                        .fill(isCurrent ? AppTheme.sage : AppTheme.sage.opacity(0.15))
                        .frame(width: 46, height: 46)
                    Image(systemName: isCurrent && player.isPlaying ? "pause.fill" : "play.fill")
                        .foregroundStyle(isCurrent ? AppTheme.ink : AppTheme.sage)
                }
            }

            Button { playTrack(track) } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(track.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(track.subtitle)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text(track.durationLabel)
                .font(AppTheme.mono(11))
                .foregroundStyle(AppTheme.textSecondary)

            Button { toggleBookmark(track) } label: {
                Image(systemName: saved ? "star.fill" : "star")
                    .foregroundStyle(saved ? AppTheme.ember : AppTheme.textSecondary)
            }
            .accessibilityLabel(saved ? "Remove bookmark" : "Save")
        }
        .padding(14)
        .background(AppTheme.twilight2)
        .cornerRadius(AppTheme.cardRadius)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                .stroke(isCurrent ? AppTheme.sage.opacity(0.6) : .clear, lineWidth: 1)
        )
    }

    private func isBookmarked(_ track: MeditationTrack) -> Bool {
        bookmarks.contains { $0.kind == Bookmark.meditationKind && $0.referenceId == track.id }
    }

    /// Play a track, logging a calm moment the first time a new track starts.
    private func playTrack(_ track: MeditationTrack) {
        if player.currentTrack?.id != track.id {
            context.insert(CalmLog(kind: .relax))
            try? context.save()
        }
        player.play(track)
    }

    private func toggleBookmark(_ track: MeditationTrack) {
        if let existing = bookmarks.first(where: { $0.kind == Bookmark.meditationKind && $0.referenceId == track.id }) {
            context.delete(existing)
        } else {
            context.insert(Bookmark(
                kind: Bookmark.meditationKind,
                referenceId: track.id,
                title: track.title,
                subtitle: track.subtitle
            ))
        }
        try? context.save()
    }

    private var nowPlayingBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.currentTrack?.title ?? "")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(AppTheme.cream)
                        .lineLimit(1)
                    Text("\(player.formatted(player.elapsed)) / \(player.formatted(player.duration))")
                        .font(AppTheme.mono(10))
                        .foregroundStyle(AppTheme.mist)
                }
                Spacer()
                Button { player.togglePlayPause() } label: {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(AppTheme.sage)
                }
                Button { player.stop() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(AppTheme.mist)
                }
            }

            ProgressView(value: player.progress)
                .tint(AppTheme.sage)
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .adaptiveContentWidth()
    }
}

#Preview {
    RelaxView()
        .environmentObject(AudioPlayerService())
        .modelContainer(for: [Bookmark.self], inMemory: true)
}
