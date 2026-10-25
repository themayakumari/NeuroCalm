//
//  PracticeAnimationView.swift
//  NeuroCalm
//
//  Demonstrative, teen-friendly animations that actually show *how* to do each
//  practice: a face with a finger switching nostrils (Nadi Shodhana), ears
//  covered with humming waves (Bhramari), an ocean-breath at the throat
//  (Ujjayi), a belly rising and falling (abdominal breathing), a figure lying
//  down with a body-scan glow (Yoga Nidra / Shavasana), a seated figure with
//  So–Ham (Ajapa Japa) or thoughts drifting away (Antar Mouna).
//
//  Driven by TimelineView so it loops smoothly. Renders a single static frame
//  under UI testing so it doesn't keep the app from going idle.
//

import SwiftUI

struct PracticeAnimationView: View {
    let style: String
    var size: CGFloat = 170

    private var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("UI-TESTING")
    }

    var body: some View {
        Group {
            if isUITesting {
                frame(at: 0.9)
            } else {
                TimelineView(.animation) { timeline in
                    frame(at: timeline.date.timeIntervalSinceReferenceDate)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }

    private func frame(at t: TimeInterval) -> some View {
        ZStack { content(at: t) }
            .frame(width: size, height: size)
    }

    @ViewBuilder
    private func content(at t: TimeInterval) -> some View {
        switch style {
        case "nostral", "nostril": nostril(t)
        case "hum":      hum(t)
        case "throat":   throat(t)
        case "scan":     scan(t)
        case "soham":    soham(t)
        case "thoughts": thoughts(t)
        default:         belly(t)
        }
    }

    // MARK: - Belly breathing — a figure with the belly rising and falling.

    private func belly(_ t: TimeInterval) -> some View {
        let breath = CGFloat(0.5 + 0.5 * sin(t * .pi * 2 / 5))   // 0…1, 5s cycle
        return ZStack {
            Image(systemName: "figure.mind.and.body")
                .resizable().scaledToFit()
                .frame(height: 118)
                .foregroundStyle(AppTheme.sage.opacity(0.9))
            // Belly expanding on the inhale.
            Circle()
                .fill(AppTheme.sage.opacity(0.35))
                .frame(width: 26 + 22 * breath, height: 26 + 22 * breath)
                .offset(y: 14)
                .blur(radius: 1)
            Image(systemName: breath > 0.6 ? "arrow.up" : "arrow.down")
                .font(.caption2.bold())
                .foregroundStyle(AppTheme.sage)
                .offset(y: 14)
        }
    }

    // MARK: - Nadi Shodhana — a face with a finger switching nostrils.

    private func nostril(_ t: TimeInterval) -> some View {
        let cycle = (t / 6).truncatingRemainder(dividingBy: 1)   // 0…1 over 6s
        let leftOpen = cycle < 0.5                               // breathe through the open side
        let half = leftOpen ? cycle / 0.5 : (cycle - 0.5) / 0.5  // 0…1 within this side
        let inhaling = half < 0.5
        let flow = CGFloat(inhaling ? half / 0.5 : 1 - (half - 0.5) / 0.5)  // 0…1 air amount
        let openX: CGFloat = leftOpen ? -11 : 11
        let closedX: CGFloat = leftOpen ? 11 : -11

        return ZStack {
            // Face.
            Circle().fill(AppTheme.sage.opacity(0.10)).frame(width: 104, height: 104)
            Circle().stroke(AppTheme.sage.opacity(0.7), lineWidth: 3).frame(width: 104, height: 104)
            // Closed eyes.
            HStack(spacing: 26) {
                Capsule().fill(AppTheme.sage.opacity(0.7)).frame(width: 14, height: 3)
                Capsule().fill(AppTheme.sage.opacity(0.7)).frame(width: 14, height: 3)
            }
            .offset(y: -14)
            // Nostrils.
            HStack(spacing: 12) {
                nostrilDot(open: leftOpen)
                nostrilDot(open: !leftOpen)
            }
            .offset(y: 12)
            // Air flowing in/out of the OPEN nostril.
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(AppTheme.sage.opacity(0.9 - Double(i) * 0.25))
                    .frame(width: 6, height: 6)
                    .offset(x: openX, y: 6 - flow * (18 + CGFloat(i) * 9))
                    .opacity(flow > 0.05 ? 1 : 0)
            }
            // Finger covering the CLOSED nostril.
            Capsule()
                .fill(AppTheme.ember.opacity(0.85))
                .frame(width: 11, height: 34)
                .offset(x: closedX, y: 30)
        }
    }

    private func nostrilDot(open: Bool) -> some View {
        Circle()
            .fill(open ? AppTheme.sage.opacity(0.9) : AppTheme.sage.opacity(0.25))
            .frame(width: 9, height: 9)
    }

    // MARK: - Bhramari — a face with ears covered and humming waves.

    private func hum(_ t: TimeInterval) -> some View {
        ZStack {
            // Humming vibration.
            ForEach(0..<3, id: \.self) { i in
                let p = ((t / 1.5) + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                Circle()
                    .stroke(AppTheme.sage.opacity(1 - p), lineWidth: 2)
                    .frame(width: 70 + CGFloat(p) * 90, height: 70 + CGFloat(p) * 90)
            }
            // Head.
            Circle().fill(AppTheme.sage.opacity(0.10)).frame(width: 84, height: 84)
            Circle().stroke(AppTheme.sage.opacity(0.7), lineWidth: 3).frame(width: 84, height: 84)
            // Closed eyes + gentle smile.
            HStack(spacing: 22) {
                Capsule().fill(AppTheme.sage.opacity(0.7)).frame(width: 12, height: 3)
                Capsule().fill(AppTheme.sage.opacity(0.7)).frame(width: 12, height: 3)
            }
            .offset(y: -10)
            // Thumbs over the ears.
            ForEach([-1, 1], id: \.self) { s in
                Circle().fill(AppTheme.ember.opacity(0.85)).frame(width: 16, height: 16)
                    .offset(x: CGFloat(s) * 44)
            }
        }
    }

    // MARK: - Ujjayi — a calm face over an undulating ocean breath.

    private func throat(_ t: TimeInterval) -> some View {
        ZStack {
            // Face.
            Circle().fill(AppTheme.sage.opacity(0.10)).frame(width: 64, height: 64)
            Circle().stroke(AppTheme.sage.opacity(0.7), lineWidth: 3).frame(width: 64, height: 64)
            HStack(spacing: 16) {
                Capsule().fill(AppTheme.sage.opacity(0.7)).frame(width: 10, height: 3)
                Capsule().fill(AppTheme.sage.opacity(0.7)).frame(width: 10, height: 3)
            }
            .offset(y: -34)
            // Ocean breath at the throat.
            let amp = CGFloat(6 + 5 * (0.5 + 0.5 * sin(t * 2)))
            WaveShape(phase: t * 1.6, amplitude: amp)
                .stroke(AppTheme.sage, lineWidth: 3)
                .frame(width: 130, height: 44)
                .offset(y: 34)
        }
    }

    // MARK: - Yoga Nidra / Shavasana — a figure lying down, scanned by a glow.

    private func scan(_ t: TimeInterval) -> some View {
        let p = CGFloat((t / 4).truncatingRemainder(dividingBy: 1))
        return ZStack(alignment: .leading) {
            // Body.
            Capsule().fill(AppTheme.mist.opacity(0.22)).frame(width: 132, height: 30)
            // Head.
            Circle().fill(AppTheme.mist.opacity(0.30)).frame(width: 34, height: 34)
                .offset(x: -10)
            // Body-scan glow travelling head → toe.
            Circle().fill(AppTheme.sage).frame(width: 15, height: 15)
                .shadow(color: AppTheme.sage.opacity(0.9), radius: 8)
                .offset(x: 6 + p * 120)
        }
        .frame(width: 150, height: 44)
    }

    // MARK: - Ajapa Japa — seated figure breathing with So / Ham.

    private func soham(_ t: TimeInterval) -> some View {
        let breath = sin(t * .pi * 2 / 6)         // + inhale, − exhale
        let inhaling = breath >= 0
        return ZStack {
            Image(systemName: "figure.mind.and.body")
                .resizable().scaledToFit()
                .frame(height: 110)
                .foregroundStyle(AppTheme.sage.opacity(0.9))
                .scaleEffect(1 + 0.04 * CGFloat(breath))
            Text(inhaling ? "So" : "Ham")
                .font(AppTheme.display(20))
                .foregroundStyle(AppTheme.sage)
                .opacity(0.4 + 0.6 * abs(breath))
                .offset(y: -74)
        }
    }

    // MARK: - Antar Mouna — seated figure, thoughts drifting away.

    private func thoughts(_ t: TimeInterval) -> some View {
        let xs: [CGFloat] = [-34, 30, 6]
        return ZStack {
            Image(systemName: "figure.mind.and.body")
                .resizable().scaledToFit()
                .frame(height: 110)
                .foregroundStyle(AppTheme.sage.opacity(0.9))
            ForEach(0..<3, id: \.self) { i in
                let p = ((t / 3) + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                Circle()
                    .fill(AppTheme.mist.opacity((1 - p) * 0.6))
                    .frame(width: 12 + CGFloat(i) * 4, height: 12 + CGFloat(i) * 4)
                    .offset(x: xs[i], y: -24 - CGFloat(p) * 52)
            }
        }
    }
}

/// A simple sine wave, used for the Ujjayi ocean breath.
struct WaveShape: Shape {
    var phase: Double
    var amplitude: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let mid = rect.height / 2
        let steps = 48
        path.move(to: CGPoint(x: 0, y: mid))
        for i in 0...steps {
            let x = rect.width * CGFloat(i) / CGFloat(steps)
            let y = mid + amplitude * CGFloat(sin(Double(i) / Double(steps) * 4 * .pi + phase))
            path.addLine(to: CGPoint(x: x, y: y))
        }
        return path
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            ForEach(["belly", "nostril", "hum", "throat", "scan", "soham", "thoughts"], id: \.self) {
                PracticeAnimationView(style: $0, size: 150)
            }
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
