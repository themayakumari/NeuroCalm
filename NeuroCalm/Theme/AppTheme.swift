//
//  AppTheme.swift
//  NeuroCalm
//
//  Central place for colors, fonts, and styles.
//  Change these to re-skin the whole app.
//
//  Palette follows the "Exhale" concept mockup: a dark, twilight
//  backdrop with sage (calm) and ember (urgency/warmth) accents.
//

import SwiftUI

enum AppTheme {

    // MARK: - Raw palette (from the Exhale mockup)

    /// Deepest background — near-black navy
    static let ink = Color(red: 0.086, green: 0.118, blue: 0.220)
    /// Card / surface background one step up from ink
    static let twilight = Color(red: 0.129, green: 0.173, blue: 0.322)
    /// Card / surface background two steps up from ink
    static let twilight2 = Color(red: 0.169, green: 0.220, blue: 0.408)
    /// Muted blue-lavender — secondary text
    static let mist = Color(red: 0.608, green: 0.651, blue: 0.800)
    /// Warm orange — urgency, streaks, energy
    static let ember = Color(red: 1.0, green: 0.561, blue: 0.369)
    /// Deep muted version of ember, for tinted surfaces
    static let emberDim = Color(red: 0.478, green: 0.267, blue: 0.188)
    /// Soft mint-green — calm, positive actions
    static let sage = Color(red: 0.561, green: 0.851, blue: 0.769)
    /// Deep muted version of sage, for tinted surfaces
    static let sageDim = Color(red: 0.184, green: 0.353, blue: 0.314)
    /// Warm off-white — used sparingly, mostly for high-contrast text on light fills
    static let cream = Color(red: 0.965, green: 0.953, blue: 0.925)

    // MARK: - Semantic colors
    // Kept under their original names so existing views don't need
    // to change every reference — only what each name *means* changed.

    /// Primary accent — buttons, links, selected states, tab tint
    static let primaryBlue = sage
    /// Secondary accent — completed states, calm highlights
    static let softTeal = sage
    /// Tertiary accent — chips, sparkles, gentle highlights
    static let lavender = mist
    /// Urgency accent — streak flame, due-soon tags
    static let warmCoral = ember

    /// App background
    static let background = ink
    /// Cards on top of the background
    static let cardBackground = twilight2
    /// Main text color
    static let textPrimary = cream
    /// Secondary text — descriptions, hints, timestamps
    static let textSecondary = mist

    // MARK: - Gradients

    /// Full-screen hero background (welcome, breathing)
    static let primaryGradient = LinearGradient(
        colors: [twilight, ink],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Soft accent gradient for encouragement / highlight cards
    static let cardGradient = LinearGradient(
        colors: [sageDim.opacity(0.9), twilight2.opacity(0.9)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Spacing & Radius
    static let cardRadius: CGFloat = 18
    static let buttonRadius: CGFloat = 20

    /// Widest a column of cards/text should ever get — keeps things readable
    /// and centered on iPad instead of stretching edge-to-edge.
    static let maxContentWidth: CGFloat = 680

    // MARK: - Typography
    // Fraunces/Inter/JetBrains Mono (from the mockup) aren't available on iOS,
    // so we approximate with system font designs: serif for display headlines,
    // monospaced for tags/labels/counters, and the default (San Francisco) for body text.

    /// Display headline font — stands in for Fraunces
    static func display(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    /// Mono label font — stands in for JetBrains Mono
    static func mono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - Reusable View Style Modifiers

/// A reusable rounded-card look. Use with `.modifier(CardStyle())`
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(AppTheme.cardBackground)
            .cornerRadius(AppTheme.cardRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                    .stroke(AppTheme.mist.opacity(0.08), lineWidth: 1)
            )
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}

/// Caps a column's width and centers it — a no-op on iPhone (the column is
/// already narrower than the cap), but keeps cards/text/buttons from
/// stretching edge-to-edge on iPad's much wider screen.
struct AdaptiveContentWidth: ViewModifier {
    var maxWidth: CGFloat
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
    }
}

extension View {
    func adaptiveContentWidth(_ maxWidth: CGFloat = AppTheme.maxContentWidth) -> some View {
        modifier(AdaptiveContentWidth(maxWidth: maxWidth))
    }
}
