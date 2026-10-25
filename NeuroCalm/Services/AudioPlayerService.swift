//
//  AudioPlayerService.swift
//  NeuroCalm
//
//  Plays the bundled guided-relaxation tracks. Injected into the
//  environment so playback survives switching tabs/sections. Configured
//  for .playback so audio continues with the screen locked (background
//  audio mode must be enabled in the target for lock-screen playback).
//

import AVFoundation
import Combine

final class AudioPlayerService: NSObject, ObservableObject {
    @Published private(set) var currentTrack: MeditationTrack?
    @Published private(set) var isPlaying = false
    @Published private(set) var progress: Double = 0     // 0...1
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0

    private var player: AVAudioPlayer?
    private var ticker: Timer?

    /// Start a track, or toggle play/pause if it's already the current one.
    func play(_ track: MeditationTrack) {
        if currentTrack?.id == track.id {
            togglePlayPause()
            return
        }
        guard let url = track.url else {
            print("⚠️ Missing audio file for \(track.id)")
            return
        }
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
    }

    func stop() {
        ticker?.invalidate()
        player?.stop()
        player = nil
        currentTrack = nil
        isPlaying = false
        progress = 0
        elapsed = 0
        duration = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Seek to a fraction (0...1) of the track.
    func seek(toFraction fraction: Double) {
        guard let player else { return }
        player.currentTime = player.duration * min(max(fraction, 0), 1)
        updateProgress()
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
    }
}
