//
//  BreathingVoiceService.swift
//  NeuroCalm
//
//  Speaks breathing phase cues ("Breathe in", "Hold", "Breathe out")
//  aloud for guided sessions, using on-device text-to-speech so it needs
//  no bundled audio. Pre-recorded narration could be swapped in later
//  behind the same simple `speak`/`stop` interface.
//

import AVFoundation

final class BreathingVoiceService {
    private let synthesizer = AVSpeechSynthesizer()

    /// The nicest-sounding voice available for the user's language, chosen once.
    private lazy var voice: AVSpeechSynthesisVoice? = Self.preferredVoice()

    init() {
        // Let the synthesizer own its audio session rather than sharing the
        // app's. This avoids the empty-buffer / IPCAUClient errors that show up
        // when the speech session fights another audio session (e.g. the Relax
        // player) and makes cues play reliably on device.
        synthesizer.usesApplicationAudioSession = false
    }

    /// Kept for the call sites; the synthesizer now owns its audio session,
    /// so there's nothing to set up here.
    func activate() {}

    /// Stop any in-progress speech when the session ends.
    func deactivate() {
        stop()
    }

    /// Speak a short cue slowly and gently.
    /// Pass `interrupt: true` at the start of a phase so the countdown re-syncs
    /// and never drifts behind the timer; leave it false to queue the next count.
    func speak(_ text: String, interrupt: Bool = false) {
        if interrupt, synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        // AVSpeech rate runs 0.0 (slowest) … 0.5 (default) … 1.0 (fastest).
        // Keep this well below default so cues feel calm and drawn-out.
        utterance.rate = 0.18                 // very slow, unhurried
        utterance.pitchMultiplier = 0.9       // lower, warmer tone
        utterance.volume = 0.8                // soft, not startling
        utterance.preUtteranceDelay = 0.0     // start promptly so counts stay on the beat
        utterance.postUtteranceDelay = 0.05
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    /// Prefer an **enhanced** voice — it sounds natural *and* respects a slow
    /// rate. We deliberately skip **premium** (Siri "neural") voices: they
    /// sound nice but largely ignore the rate setting, so cues can't be slowed.
    private static func preferredVoice() -> AVSpeechSynthesisVoice? {
        let language = AVSpeechSynthesisVoice.currentLanguageCode()
        let matching = AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language == language && $0.quality != .premium
        }
        return matching.first { $0.quality == .enhanced }
            ?? matching.first { $0.quality == .default }
            ?? AVSpeechSynthesisVoice(language: language)
    }
}
