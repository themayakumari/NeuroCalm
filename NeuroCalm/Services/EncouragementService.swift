//
//  EncouragementService.swift
//  NeuroCalm
//
//  A small pool of supportive, non-toxic-positivity messages.
//  Used by HomeView and StatsView.
//

import Foundation

enum EncouragementService {

    private static let messages = [
        "One difficult day does not ruin your progress.",
        "Small steps still move you forward.",
        "Your brain is doing its best. Be kind to it.",
        "Resting is part of working.",
        "You don't have to do everything today.",
        "A clear breath leads to a clear thought.",
        "Progress hides in the small, repeated choices.",
        "You're allowed to slow down and still succeed.",
        "It is okay to begin again, as many times as you need.",
        "Your effort matters even when the result is delayed."
    ]

    static func randomMessage() -> String {
        messages.randomElement() ?? messages[0]
    }
}
