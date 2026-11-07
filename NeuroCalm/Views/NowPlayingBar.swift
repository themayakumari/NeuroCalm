//
//  NowPlayingBar.swift
//  NeuroCalm
//
//  The mini player for guided audio. Attached once by MainTabView and
//  MainSplitView so whatever is playing can be paused or stopped from
//  any section, not just Relax. Hidden when nothing is playing.
//

import SwiftUI

struct NowPlayingBar: View {
    @EnvironmentObject private var player: AudioPlayerService

    /// Called when the title area is tapped (e.g. to show Relax).
    var onOpen: (() -> Void)? = nil

    var body: some View {
        if let track = player.currentTrack {
            bar(title: track.title)
        } else if let id = player.downloadingTrackId {
            downloadingBar(title: ContentService.shared.tracks.first { $0.id == id }?.title)
        }
    }

    private func bar(title: String) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 14) {
                Button { onOpen?() } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(AppTheme.cream)
                            .lineLimit(1)
                        Text("\(player.formatted(player.elapsed)) / \(player.formatted(player.duration))")
                            .font(AppTheme.mono(10))
                            .foregroundStyle(AppTheme.mist)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(onOpen == nil)
                .accessibilityHint(onOpen == nil ? "" : "Opens Relax")

                Button { player.togglePlayPause() } label: {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(AppTheme.sage)
                }
                .accessibilityLabel(player.isPlaying ? "Pause" : "Play")

                Button { player.stop() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(AppTheme.mist)
                }
                .accessibilityLabel("Stop")
            }

            ProgressView(value: player.progress)
                .tint(AppTheme.sage)
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .adaptiveContentWidth()
    }

    /// Shown while a track is fetched before its first play.
    private func downloadingBar(title: String?) -> some View {
        HStack(spacing: 14) {
            ProgressView()
                .tint(AppTheme.sage)
            Text(title.map { "Downloading \($0)…" } ?? "Downloading…")
                .font(.subheadline)
                .foregroundStyle(AppTheme.cream)
                .lineLimit(1)
            Spacer()
            Button { player.stop() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(AppTheme.mist)
            }
            .accessibilityLabel("Cancel download")
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .adaptiveContentWidth()
    }
}

#Preview {
    NowPlayingBar()
        .environmentObject(AudioPlayerService())
}
