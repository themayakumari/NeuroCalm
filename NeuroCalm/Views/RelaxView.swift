//
//  RelaxView.swift
//  NeuroCalm
//
//  A library of guided relaxation audio (Shavasana, Yoga Nap, plus any
//  tracks added in Firebase — see ContentService). Tapping a track plays it; the app-wide NowPlayingBar controls
//  playback as the user moves around the app.
//

import SwiftUI
import SwiftData

struct RelaxView: View {
    @EnvironmentObject private var player: AudioPlayerService
    @ObservedObject private var library = ContentService.shared
    @Environment(\.modelContext) private var context
    @Query private var bookmarks: [Bookmark]

    /// Tracks the user has starred, in the library's order.
    private var savedTracks: [MeditationTrack] {
        let savedIds = Set(bookmarks.filter { $0.kind == Bookmark.meditationKind }.map(\.referenceId))
        return library.tracks.filter { savedIds.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    if let error = player.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(AppTheme.ember)
                    }

                    if !savedTracks.isEmpty {
                        section(title: "Saved", tracks: savedTracks)
                    }
                    section(title: savedTracks.isEmpty && library.breathingTracks.isEmpty ? nil : "All practices",
                            tracks: library.relaxationTracks)
                    if !library.breathingTracks.isEmpty {
                        section(title: "Guided breathing", tracks: library.breathingTracks)
                    }
                }
                .padding()
                .adaptiveContentWidth()
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Relax")
            .refreshable { await library.refresh() }
            .task { await library.refresh() }
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
                    if player.downloadingTrackId == track.id {
                        ProgressView().tint(AppTheme.sage)
                    } else {
                        Image(systemName: isCurrent && player.isPlaying ? "pause.fill" : "play.fill")
                            .foregroundStyle(isCurrent ? AppTheme.ink : AppTheme.sage)
                    }
                }
            }
            .accessibilityLabel(player.downloadingTrackId == track.id ? "Downloading" : "Play \(track.title)")

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
}

#Preview {
    RelaxView()
        .environmentObject(AudioPlayerService())
        .modelContainer(for: [Bookmark.self], inMemory: true)
}
