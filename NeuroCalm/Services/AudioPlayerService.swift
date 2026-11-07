//
//  AudioPlayerService.swift
//  NeuroCalm
//
//  Plays the guided audio tracks (bundled, or downloaded from Firebase on
//  first play — see MediaCatalog). Injected into the
//  environment so playback survives switching tabs/sections. Configured
//  for .playback so audio continues with the screen locked (background
//  audio mode must be enabled in the target for lock-screen playback).
//  Also feeds the lock screen / Control Center player and handles its
//  play, pause and scrub controls.
//

import AVFoundation
import Combine
import MediaPlayer

final class AudioPlayerService: NSObject, ObservableObject {
    @Published private(set) var currentTrack: MeditationTrack?
    @Published private(set) var isPlaying = false
    @Published private(set) var progress: Double = 0     // 0...1
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    /// The track being downloaded before it can play, if any.
    @Published private(set) var downloadingTrackId: String?
    /// A short message when a track couldn't be downloaded.
    @Published var errorMessage: String?

    private var player: AVAudioPlayer?
    private var ticker: Timer?

    override init() {
        super.init()
        registerRemoteCommands()
    }

    /// Start a track, or toggle play/pause if it's already the current one.
    func play(_ track: MeditationTrack) {
        if currentTrack?.id == track.id {
            togglePlayPause()
            return
        }
        if downloadingTrackId == track.id { return }   // already on its way
        errorMessage = nil
        if let url = track.url {
            start(track, url: url)
            // A newer hosted recording exists: fetch it now for next time.
            if track.needsDownload {
                Task { _ = try? await AudioCache.download(track) }
            }
            return
        }
        guard track.remoteURL != nil else {
            print("⚠️ Missing audio file for \(track.id)")
            return
        }

        // Not on the phone yet: download once, then play (and keep it offline).
        downloadingTrackId = track.id
        Task { @MainActor in
            do {
                let url = try await AudioCache.download(track)
                // Only play if the student is still waiting on this track.
                guard downloadingTrackId == track.id else { return }
                downloadingTrackId = nil
                start(track, url: url)
            } catch {
                guard downloadingTrackId == track.id else { return }
                downloadingTrackId = nil
                errorMessage = "Couldn't download \"\(track.title)\". Check your internet connection and try again."
            }
        }
    }

    private func start(_ track: MeditationTrack, url: URL) {
        downloadingTrackId = nil
        configureSession()
        do {
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.delegate = self
            newPlayer.prepareToPlay()
            player = newPlayer
            currentTrack = track
            duration = newPlayer.duration
            newPlayer.play()
            isPlaying = true
            startTicker()
            updateNowPlayingInfo()
        } catch {
            print("⚠️ Audio playback failed: \(error)")
        }
    }

    func togglePlayPause() {
        guard let player else { return }
        if player.isPlaying {
            player.pause()
            isPlaying = false
        } else {
            configureSession()
            player.play()
            isPlaying = true
        }
        updateNowPlayingInfo()
    }

    func stop() {
        downloadingTrackId = nil
        ticker?.invalidate()
        player?.stop()
        player = nil
        currentTrack = nil
        isPlaying = false
        progress = 0
        elapsed = 0
        duration = 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Seek to a fraction (0...1) of the track.
    func seek(toFraction fraction: Double) {
        guard let player else { return }
        player.currentTime = player.duration * min(max(fraction, 0), 1)
        updateProgress()
        updateNowPlayingInfo()
    }

    func formatted(_ time: TimeInterval) -> String {
        let total = Int(time.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    // MARK: - Internals

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio)
        try? session.setActive(true)
    }

    private func startTicker() {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateProgress()
        }
    }

    /// Lock screen controls. Registered once; they act on whatever is current.
    private func registerRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            guard let self, let player = self.player else { return .noActionableNowPlayingItem }
            if !player.isPlaying { self.togglePlayPause() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            guard let self, let player = self.player else { return .noActionableNowPlayingItem }
            if player.isPlaying { self.togglePlayPause() }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self, self.player != nil else { return .noActionableNowPlayingItem }
            self.togglePlayPause()
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self, let player = self.player,
                  let event = event as? MPChangePlaybackPositionCommandEvent,
                  player.duration > 0 else { return .commandFailed }
            self.seek(toFraction: event.positionTime / player.duration)
            return .success
        }
    }

    private func updateNowPlayingInfo() {
        guard let track = currentTrack, let player else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.subtitle,
            MPMediaItemPropertyPlaybackDuration: player.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: player.currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: player.isPlaying ? 1.0 : 0.0
        ]
    }

    private func updateProgress() {
        guard let player, player.duration > 0 else { return }
        elapsed = player.currentTime
        duration = player.duration
        progress = player.currentTime / player.duration
    }
}

extension AudioPlayerService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        ticker?.invalidate()
        isPlaying = false
        progress = 1
        elapsed = duration
        updateNowPlayingInfo()
    }
}
