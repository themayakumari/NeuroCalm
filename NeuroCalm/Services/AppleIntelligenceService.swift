//
//  AppleIntelligenceService.swift
//  NeuroCalm
//
//  On-device replies via Apple's Foundation Models framework (Apple Intelligence).
//  Free, private, runs entirely on the phone — no API key, no network, no cost.
//
//  Only available on Apple-Intelligence-capable devices (iPhone 15 Pro / 16+)
//  running a new enough OS. Everywhere else — older devices and the Simulator —
//  `reply` returns nil and the caller falls back to the next tier. The whole
//  file is compiled out when the SDK doesn't ship the framework.
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

enum AppleIntelligenceService {

    /// True only when the device actually has an on-device model ready to use.
    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if case .available = SystemLanguageModel.default.availability { return true }
        }
        #endif
        return false
    }

    /// A human-readable status for the Settings screen — explains *why* it's
    /// unavailable so setup problems are obvious.
    static var statusDescription: String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return "Ready"
            case .unavailable(.deviceNotEligible):
                return "This iPhone doesn't support Apple Intelligence"
            case .unavailable(.appleIntelligenceNotEnabled):
                return "Turn on Apple Intelligence in Settings"
            case .unavailable(.modelNotReady):
                return "Model downloading — check back shortly"
            case .unavailable:
                return "Unavailable on this device"
            }
        } else {
            return "Needs iOS 26 or later"
        }
        #else
        return "Not included in this build"
        #endif
    }

    /// Generate a reply on-device, or nil if unavailable / it fails.
    /// `grounding` is the practice source material to answer from, when relevant.
    static func reply(history: [(role: String, text: String)], grounding: String? = nil) async -> String? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            guard case .available = SystemLanguageModel.default.availability else { return nil }

            let session = LanguageModelSession(instructions: YogaTradition.systemPrompt)
            var prompt = buildPrompt(from: history)
            guard !prompt.isEmpty else { return nil }
            if let grounding, !grounding.isEmpty {
                prompt = """
                SOURCE MATERIAL (traditional yoga practice descriptions — base any \
                practice guidance on this and stay faithful to it):
                \(grounding)

                \(prompt)
                """
            }

            do {
                let response = try await session.respond(to: prompt)
                let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                return text.isEmpty ? nil : text
            } catch {
                return nil
            }
        }
        #endif
        return nil
    }

    /// Build a compact transcript so the model has recent context, ending with
    /// the latest student message it should answer.
    private static func buildPrompt(from history: [(role: String, text: String)]) -> String {
        let recent = history.suffix(8)
        guard recent.contains(where: { $0.role == "user" }) else { return "" }
        let lines = recent.map { turn -> String in
            let speaker = turn.role == "user" ? "Student" : "You"
            return "\(speaker): \(turn.text)"
        }
        return lines.joined(separator: "\n") + "\nYou:"
    }
}
