//
//  AssistantService.swift
//  NeuroCalm
//
//  A rule-based but conversational assistant for the MVP: short, warm,
//  varied replies that reflect what the student said and keep the
//  conversation going with a gentle follow-up.
//
//  On capable devices, replies come from Apple's on-device Foundation Models
//  (see AppleIntelligenceService); otherwise the built-in helper answers.
//

import Foundation

struct AssistantReply {
    let text: String
    let suggestBreathing: Bool
}

/// Which engine produced a reply — shown faintly in the chat while testing.
enum AssistantSource: String {
    case onDevice = "via Apple Intelligence"
    case local = "offline assistant"
}

enum AssistantService {

    /// The two-tier reply chain, tried in order until one succeeds:
    ///   1. Apple on-device Intelligence (free, private, capable devices only)
    ///   2. The built-in rule-based assistant (always works, offline)
    static func generateReply(
        history: [(role: String, text: String)]
    ) async -> (text: String, source: AssistantSource) {
        let lastUser = history.last(where: { $0.role == "user" })?.text ?? ""
        // Ground the answer in the traditional yoga practice source material.
        let grounding = KnowledgeBase.shared.grounding(for: lastUser)

        if let text = await AppleIntelligenceService.reply(history: history, grounding: grounding) {
            return (text, .onDevice)
        }
        return (reply(to: lastUser).text, .local)
    }

    /// Generate a supportive, conversational reply based on what was said.
    static func reply(to userMessage: String) -> AssistantReply {
        let msg = userMessage.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // ---- Small talk keeps it feeling like a real conversation ----

        if isExactly(msg, ["hi", "hello", "hey", "yo", "hiya", "heya"]) || matches(msg, any: ["hi ", "hey ", "hello "]) {
            return say([
                "Hey, I'm really glad you're here. What's on your mind?",
                "Hi there. How are you feeling right now?",
                "Hey! Want to tell me what's going on today?"
            ])
        }

        if matches(msg, any: ["thank", "thx", "appreciate"]) {
            return say([
                "Anytime — I'm here whenever you need a breather.",
                "Of course. Be gentle with yourself today.",
                "You're welcome. Proud of you for checking in."
            ])
        }

        if msg.contains("how are you") || msg.contains("how r u") || msg.contains("how's it going") {
            return say([
                "I'm here and ready to help you feel calmer. More to the point — how are you?",
                "Always steady, thanks for asking. What about you — how's your head today?"
            ])
        }

        if isExactly(msg, ["yes", "yeah", "yep", "ok", "okay", "sure", "yup", "k", "yea"]) {
            return say([
                "Great. Let's take one slow breath together — in for four, out for four. Ready when you are.",
                "Love that. Want to start a quick breathing round, or talk it through first?"
            ], suggestBreathing: true)
        }

        if isExactly(msg, ["no", "nope", "nah", "not really"]) {
            return say([
                "That's okay. We can just talk. What's weighing on you most right now?",
                "No pressure at all. I'm here to listen — what's going on?"
            ])
        }

        if matches(msg, any: ["bye", "goodbye", "see you", "gtg", "gotta go", "got to go", "good night", "goodnight"]) {
            return say([
                "Take care of yourself. Come back any time.",
                "Bye for now — one deep breath before you go. You've got this."
            ])
        }

        // ---- The things students actually bring up ----

        if matches(msg, any: ["test", "exam", "quiz", "midterm", "final"]) {
            return say([
                "Exams can feel huge — I get it. A minute of alternate-nostril breathing settles the nerves. How long until it?",
                "Okay, a test coming up. Let's shrink it: a minute of calm breathing, then just one topic. Want to start with the breath?",
                "That pressure is real. First a few slow, even breaths, then ONE topic — not everything at once. Sound doable?"
            ], suggestBreathing: true)
        }

        if matches(msg, any: ["overwhelm", "anxiou", "panic", "stress", "freak", "too much", "can't cope"]) {
            return say([
                "That sounds really heavy. Let's steady you with a little alternate-nostril breathing — it calms a racing mind. Want to try a minute?",
                "When it's all too much, we shrink it. A few rounds of alternate-nostril breathing first, then we pick the single biggest thing. Okay?",
                "I hear you. Before we solve anything, let's slow the breath — even a minute of alternate-nostril breathing helps. Shall we?"
            ], suggestBreathing: true)
        }

        if matches(msg, any: ["focus", "concentrat", "distract", "can't study", "cant study", "procrastinat"]) {
            return say([
                "Focus is hard when the mind's buzzing. A few rounds of humming-bee breath can settle it — then a 25-minute block with your phone away. Start with the breath?",
                "Totally normal. Try the calm ocean breath for a minute to steady attention, then one task, one timer. Want a breath first?",
                "Drifting is human. What's the one thing you'd most like to get done — and shall we do a minute of humming-bee breath to clear your head first?"
            ], suggestBreathing: true)
        }

        if matches(msg, any: ["sleep", "tired", "exhaust", "can't sleep", "cant sleep", "insomnia", "awake"]) {
            return say([
                "Rest matters so much. The Relax tab's Yoga Nap is made for this — lie down and let it guide you into deep rest. Want to try it tonight?",
                "Being tired makes everything harder. Humming-bee breath before bed quietens the mind — or put on a Yoga Nap session. Which sounds better?",
                "Your mind needs to wind down. A little Yoga Nap, or slow humming breaths in the dark. Shall we start one?"
            ], suggestBreathing: true)
        }

        if matches(msg, any: ["homework", "assignment", "essay", "project", "deadline", "due"]) {
            return say([
                "Big tasks shrink when you slice them. What's the very first small step?",
                "Let's not carry the whole thing at once. Want to break it into steps in the Planner together?",
                "Deadlines are stressful. Pick just the first 20 minutes' worth — what would that be?"
            ])
        }

        if matches(msg, any: ["sad", "down", "lonely", "depress", "hopeless", "cry", "crying"]) {
            return say([
                "I'm really sorry you're feeling that way. You're not alone in this. Do you have someone you trust you could talk to?",
                "That's a lot to carry. Hard days don't last forever. If it feels like more than a passing mood, please reach out to a parent, teacher, or counselor. I'm here too.",
                "Thank you for telling me. Let's be gentle right now — some water, a little fresh air, one slow breath. Want to breathe together?"
            ], suggestBreathing: true)
        }

        // ---- Anything else: reflect + invite more ----
        return say([
            "I hear you. Tell me a little more about what's going on?",
            "Thanks for sharing that. What would feel most helpful right now — talking it through, or a quick calming breath?",
            "That makes sense. Want to unpack it a bit, or take a minute to breathe first?"
        ])
    }

    // MARK: - Helpers

    private static func say(_ options: [String], suggestBreathing: Bool = false) -> AssistantReply {
        AssistantReply(text: options.randomElement() ?? options[0], suggestBreathing: suggestBreathing)
    }

    private static func matches(_ text: String, any keywords: [String]) -> Bool {
        keywords.contains { text.contains($0) }
    }

    private static func isExactly(_ text: String, _ options: [String]) -> Bool {
        options.contains(text)
    }
}
