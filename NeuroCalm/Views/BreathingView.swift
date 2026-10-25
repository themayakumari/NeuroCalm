//
//  BreathingView.swift
//  NeuroCalm
//
//  Animated breathing session with selectable technique.
//

import SwiftUI
import SwiftData

struct BreathingView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    // Session settings, chosen before starting. Default is a balanced 1:1.
    @State private var ratio: BreathingRatio = .oneToOne
    @State private var duration: BreathingDuration = .two
    /// Guided mode speaks the phase cues aloud. Off by default.
    @State private var guided = false
    @State private var voice = BreathingVoiceService()
    /// Which on-screen animation to follow. Default is the circle.
    @State private var visualization: BreathVisualization = .circle
    /// 0 (empty) … 1 (full) — drives the lungs fill level, mirrors the breath.
    @State private var fillLevel: CGFloat = 0
    /// The air color — cool sage on the inhale, warm ember on the exhale.
    @State private var airColor: Color = AppTheme.sage

    @State private var phase: BreathPhase = .ready
    @State private var phaseRemaining: Int = 0
    @State private var totalElapsed: Int = 0
    @State private var isRunning = false
    @State private var showCompletion = false

    /// Tracks the breathing animation circle.
    @State private var circleScale: CGFloat = 0.6

    /// Per-phase seconds for the currently selected ratio.
    private var phases: (inhale: Int, hold1: Int, exhale: Int, hold2: Int) { ratio.phases }

    // Timer that ticks every second while running.
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    enum BreathPhase {
        case ready, inhale, hold1, exhale, hold2, done

        var label: String {
            switch self {
            case .ready: return "Ready"
            case .inhale: return "Breathe in"
            case .hold1, .hold2: return "Hold"
            case .exhale: return "Breathe out"
            case .done: return "Done"
            }
        }
    }

    var body: some View {
        ZStack {
            AppTheme.primaryGradient.ignoresSafeArea()

            VStack {
                // Top bar — just the close button now; pattern + length live
                // in the selector row below so they're easy to reach before starting.
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(AppTheme.mist)
                    }
                    Spacer()
                }
                .padding()

                Spacer()

                Text(phase.label)
                    .font(AppTheme.display(22))
                    .foregroundStyle(AppTheme.cream)
                    .padding(.bottom, 4)
                Text(isRunning ? "Follow along" : "Choose a pattern, then start")
                    .font(.caption)
                    .foregroundStyle(AppTheme.mist)
                    .padding(.bottom, isRunning ? 28 : 16)

                // Selectors — only before a session runs. Two rows so the chips
                // don't overflow on iPhone.
                if !isRunning {
                    VStack(spacing: 10) {
                        HStack(spacing: 12) {
                            Menu {
                                ForEach(BreathingRatio.allCases) { r in
                                    Button { ratio = r } label: {
                                        Text("\(r.title)  ·  \(r.ratioLabel)")
                                    }
                                }
                            } label: {
                                selectorChip(icon: "lungs.fill", text: "\(ratio.title) · \(ratio.ratioLabel)")
                            }

                            Menu {
                                ForEach(BreathingDuration.allCases) { d in
                                    Button { duration = d } label: { Text(d.label) }
                                }
                            } label: {
                                selectorChip(icon: "timer", text: duration.label)
                            }
                        }

                        HStack(spacing: 12) {
                            // Switch the on-screen animation (circle ↔ lungs).
                            Button { visualization.toggle() } label: {
                                selectorChip(icon: visualization.icon, text: visualization.title, showChevron: false)
                            }

                            // Toggle spoken guidance on/off.
                            Button { guided.toggle() } label: {
                                selectorChip(
                                    icon: guided ? "speaker.wave.2.fill" : "speaker.slash.fill",
                                    text: guided ? "Voice on" : "Voice off",
                                    showChevron: false,
                                    highlighted: guided
                                )
                            }
                        }
                    }
                    .padding(.bottom, 24)
                }

                // The chosen visualization.
                Group {
                    switch visualization {
                    case .circle: circleVisualization
                    case .lungs: lungsVisualization
                    case .heart: heartVisualization
                    }
                }
                .frame(width: 280, height: 280)

                Spacer()

                // Subtitle
                Text(ratio.description)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.mist)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .adaptiveContentWidth(420)
                    .padding(.bottom, 16)

                // Progress: elapsed out of the chosen length.
                Text("\(formatted(totalElapsed)) / \(formatted(duration.seconds))")
                    .font(AppTheme.mono(11))
                    .tracking(0.6)
                    .foregroundStyle(AppTheme.sage)
                    .padding(.bottom, 12)

                // Start / Stop / Finish
                HStack(spacing: 16) {
                    if isRunning {
                        Button { stop(saving: false) } label: {
                            Text("Stop")
                                .font(.headline)
                                .foregroundStyle(AppTheme.cream)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(AppTheme.twilight2)
                                .cornerRadius(AppTheme.buttonRadius)
                        }
                        Button { stop(saving: true) } label: {
                            Text("Finish")
                                .font(.headline)
                                .foregroundStyle(AppTheme.ink)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(AppTheme.sage)
                                .cornerRadius(AppTheme.buttonRadius)
                        }
                    } else {
                        Button { start() } label: {
                            Text("Start")
                                .font(.headline)
                                .foregroundStyle(AppTheme.ink)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(AppTheme.sage)
                                .cornerRadius(AppTheme.buttonRadius)
                        }
                    }
                }
                .padding(.horizontal, 32)
                .adaptiveContentWidth(420)
                .padding(.bottom, 32)
            }
        }
        .onReceive(timer) { _ in
            guard isRunning else { return }
            tick()
        }
        .alert("Session saved", isPresented: $showCompletion) {
            Button("OK") { dismiss() }
        } message: {
            Text("Nice work. Take a moment to notice how you feel.")
        }
    }

    // MARK: - Visualizations

    /// Concentric rings with a solid sage core that expands on the inhale.
    private var circleVisualization: some View {
        ZStack {
            Circle()
                .stroke(AppTheme.sageDim, lineWidth: 1)
                .frame(width: 280, height: 280)
            Circle()
                .stroke(AppTheme.sageDim, lineWidth: 1)
                .frame(width: 200, height: 200)
            Circle()
                .fill(AppTheme.sage)
                .frame(width: 130, height: 130)
                .scaleEffect(circleScale)
            countBadge(color: AppTheme.ink, scale: min(circleScale, 1.0))
        }
    }

    /// Lungs that both **inflate** as they fill (rising sage, bottom-up) and
    /// **deflate** as they empty — driven by `fillLevel` — with a soft glow
    /// that intensifies when full, so it reads like real breathing.
    private var lungsVisualization: some View {
        let dim: CGFloat = 210
        // Before a session the lungs rest partly full so they look alive;
        // during a session they follow the breath.
        let level = isRunning ? fillLevel : 0.7
        // Empty lungs sit smaller; they swell as air comes in.
        let inflate = 0.80 + 0.32 * level
        let lungShape = Image(systemName: "lungs.fill")
            .resizable()
            .scaledToFit()
            .frame(width: dim, height: dim)
        return ZStack {
            // A dim "empty" fill with air rising from the bottom, all clipped
            // to the lungs silhouette. The air color shifts with the breath —
            // cool sage in, warm ember out.
            ZStack(alignment: .bottom) {
                // The whole silhouette carries a strong tint of the air color, so
                // the lungs clearly change hue with the breath — vivid sage on the
                // way in, vivid ember on the way out — even as they empty.
                airColor.opacity(0.6)
                LinearGradient(
                    colors: [airColor, airColor.opacity(0.8)],
                    startPoint: .bottom,
                    endPoint: .top
                )
                .frame(height: dim * level)
            }
            .frame(width: dim, height: dim)
            .mask { lungShape }

            countBadge(color: .white, scale: 1.0, backing: AppTheme.ink.opacity(0.55))
        }
        .scaleEffect(inflate)
        .shadow(color: airColor.opacity(0.55 * level), radius: 26 * level)
    }

    /// A realistic pink/red anatomical heart that swells on the inhale and
    /// eases back on the exhale, with a warm glow — a living, beating feel.
    private var heartVisualization: some View {
        let dim: CGFloat = 200
        let level = isRunning ? fillLevel : 0.55
        let beat = 0.82 + 0.26 * level

        // Heart tissue colors — deep muscular red with warm highlights.
        let bodyGradient = LinearGradient(
            colors: [Color(red: 0.85, green: 0.26, blue: 0.30),
                     Color(red: 0.52, green: 0.07, blue: 0.12)],
            startPoint: .top, endPoint: .bottom
        )
        let vessel = Color(red: 0.80, green: 0.42, blue: 0.44)
        let coronary = Color(red: 0.42, green: 0.05, blue: 0.10)

        return ZStack {
            // Great vessels behind the body: an aortic arch + a pulmonary trunk,
            // curved (not straight tubes) so they read as real vessels.
            aorticArch(dim: dim).stroke(vessel, style: StrokeStyle(lineWidth: 22, lineCap: .round))
                .frame(width: dim, height: dim)
                .offset(y: -dim * 0.30)
            pulmonaryTrunk(dim: dim).stroke(vessel.opacity(0.85), style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .frame(width: dim, height: dim)
                .offset(y: -dim * 0.30)

            ZStack {
                AnatomicalHeartShape().fill(bodyGradient)
                // Soft highlight for volume (upper-left sheen).
                AnatomicalHeartShape().fill(
                    RadialGradient(colors: [Color.white.opacity(0.30), .clear],
                                   center: UnitPoint(x: 0.34, y: 0.34),
                                   startRadius: 2, endRadius: dim * 0.5)
                )
                // Coronary artery grooves (LAD + a branch), clipped to the heart.
                coronaryArteries(dim: dim)
                    .stroke(coronary, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                    .blur(radius: 0.6)
            }
            .frame(width: dim, height: dim)
            .clipShape(AnatomicalHeartShape())

            countBadge(color: .white, scale: 1.0)
        }
        .scaleEffect(beat)
        .shadow(color: Color(red: 0.9, green: 0.2, blue: 0.3).opacity(0.5 * level), radius: 28 * level)
    }

    // A candy-cane aortic arch rising from the top and curving right.
    private func aorticArch(dim: CGFloat) -> Path {
        Path { p in
            p.move(to: CGPoint(x: dim * 0.44, y: dim * 0.55))
            p.addCurve(to: CGPoint(x: dim * 0.74, y: dim * 0.42),
                       control1: CGPoint(x: dim * 0.44, y: dim * 0.14),
                       control2: CGPoint(x: dim * 0.78, y: dim * 0.16))
        }
    }

    // A shorter pulmonary trunk rising slightly left.
    private func pulmonaryTrunk(dim: CGFloat) -> Path {
        Path { p in
            p.move(to: CGPoint(x: dim * 0.36, y: dim * 0.55))
            p.addQuadCurve(to: CGPoint(x: dim * 0.30, y: dim * 0.22),
                           control: CGPoint(x: dim * 0.28, y: dim * 0.40))
        }
    }

    // The left anterior descending coronary artery and a diagonal branch.
    private func coronaryArteries(dim: CGFloat) -> Path {
        Path { p in
            p.move(to: CGPoint(x: dim * 0.52, y: dim * 0.30))
            p.addCurve(to: CGPoint(x: dim * 0.42, y: dim * 0.92),
                       control1: CGPoint(x: dim * 0.50, y: dim * 0.55),
                       control2: CGPoint(x: dim * 0.44, y: dim * 0.75))
            p.move(to: CGPoint(x: dim * 0.50, y: dim * 0.48))
            p.addQuadCurve(to: CGPoint(x: dim * 0.74, y: dim * 0.62),
                           control: CGPoint(x: dim * 0.64, y: dim * 0.50))
        }
    }

    @ViewBuilder
    private func countBadge(color: Color, scale: CGFloat, backing: Color? = nil) -> some View {
        Group {
            if isRunning && phaseRemaining > 0 {
                Text("\(phaseRemaining)")
                    .font(AppTheme.mono(30, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 62, height: 62)
                    .background {
                        // A soft chip keeps the number readable over busy fills
                        // (e.g. the lungs' bronchial branches).
                        if let backing {
                            Circle().fill(backing).blur(radius: 3)
                        }
                    }
                    .shadow(color: .black.opacity(0.45), radius: 3, y: 1)
                    .scaleEffect(scale)
            }
        }
    }

    // MARK: - Lifecycle

    private func start() {
        isRunning = true
        totalElapsed = 0
        if guided { voice.activate() }
        beginPhase(.inhale)
    }

    private func stop(saving: Bool) {
        isRunning = false
        voice.deactivate()
        if saving && totalElapsed > 0 {
            saveSession()
            // Optional: write the same duration to Apple Health.
            HealthKitService.shared.saveMindfulMinutes(seconds: totalElapsed) { _ in }
        }
        phase = .ready
        withAnimation { circleScale = 0.6; fillLevel = 0; airColor = AppTheme.sage }
        if saving && totalElapsed > 0 {
            showCompletion = true
        } else {
            dismiss()
        }
    }

    private func tick() {
        totalElapsed += 1

        // Auto-finish once the chosen length is reached.
        if totalElapsed >= duration.seconds {
            stop(saving: true)
            return
        }

        phaseRemaining -= 1
        if phaseRemaining <= 0 {
            advancePhase()
        } else if guided {
            voice.speak("\(phaseRemaining)")   // count down: … 3 … 2 … 1
        }
    }

    /// Move to the next phase of the breathing pattern.
    private func advancePhase() {
        switch phase {
        case .ready, .done:
            beginPhase(.inhale)
        case .inhale:
            if phases.hold1 > 0 { beginPhase(.hold1) }
            else { beginPhase(.exhale) }
        case .hold1:
            beginPhase(.exhale)
        case .exhale:
            if phases.hold2 > 0 { beginPhase(.hold2) }
            else { beginPhase(.inhale) }
        case .hold2:
            beginPhase(.inhale)
        }
    }

    private func beginPhase(_ newPhase: BreathPhase) {
        phase = newPhase
        switch newPhase {
        case .inhale:
            phaseRemaining = phases.inhale
            withAnimation(.easeInOut(duration: Double(phases.inhale))) {
                circleScale = 1.0
                fillLevel = 1.0
                airColor = AppTheme.sage        // fresh air coming in
            }
        case .hold1, .hold2:
            phaseRemaining = (newPhase == .hold1) ? phases.hold1 : phases.hold2
        case .exhale:
            phaseRemaining = phases.exhale
            withAnimation(.easeInOut(duration: Double(phases.exhale))) {
                circleScale = 0.6
                fillLevel = 0.0
                airColor = AppTheme.ember        // warm air going out
            }
        case .ready, .done:
            phaseRemaining = 0
        }
        speakCue(for: newPhase)
    }

    /// Announce the phase, then start the slow spoken countdown for it —
    /// e.g. "Breathe in. 4 … 3 … 2 … 1", "Hold. 4 … 3 … 2 … 1". Called after
    /// `phaseRemaining` is set so the first number is the full phase length.
    private func speakCue(for newPhase: BreathPhase) {
        guard guided, isRunning else { return }
        let word: String?
        switch newPhase {
        case .inhale: word = "Breathe in"
        case .exhale: word = "Breathe out"
        case .hold1, .hold2: word = "Hold"
        case .ready, .done: word = nil
        }
        // Interrupt so the new phase's count re-syncs to the timer.
        if let word { voice.speak("\(word). \(phaseRemaining)", interrupt: true) }
    }

    private func saveSession() {
        let session = BreathingSession(
            durationSeconds: totalElapsed,
            technique: ratio.rawValue
        )
        context.insert(session)
        context.insert(CalmLog(kind: .breathe))   // feeds the Calm Ring + badges
        try? context.save()
    }

    private func formatted(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    /// A compact chip used for the pattern, duration, and voice controls.
    private func selectorChip(icon: String, text: String, showChevron: Bool = true, highlighted: Bool = false) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
            if showChevron {
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
        }
        .font(.caption)
        .foregroundStyle(highlighted ? AppTheme.ink : AppTheme.cream)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(highlighted ? AppTheme.sage : AppTheme.twilight2)
        .clipShape(Capsule())
    }
}

/// The on-screen animation the user follows during a session.
enum BreathVisualization: CaseIterable {
    case circle, lungs, heart

    mutating func toggle() {
        let all = Self.allCases
        let next = (all.firstIndex(of: self)! + 1) % all.count
        self = all[next]
    }

    var title: String {
        switch self {
        case .circle: return "Circle"
        case .lungs: return "Lungs"
        case .heart: return "Heart"
        }
    }

    var icon: String {
        switch self {
        case .circle: return "circle.circle"
        case .lungs: return "lungs.fill"
        case .heart: return "heart.fill"
        }
    }
}

/// A stylised anatomical heart — asymmetric and tilted, apex down and to the
/// left, a broad chambered top (not a valentine's two even humps).
struct AnatomicalHeartShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * w, y: rect.minY + y * h)
        }
        var p = Path()
        p.move(to: pt(0.40, 0.99))                                              // apex (low, left)
        p.addCurve(to: pt(0.12, 0.52), control1: pt(0.22, 0.90), control2: pt(0.11, 0.70)) // front/left wall up
        p.addCurve(to: pt(0.30, 0.30), control1: pt(0.13, 0.40), control2: pt(0.18, 0.33)) // small left auricle
        p.addCurve(to: pt(0.54, 0.33), control1: pt(0.40, 0.28), control2: pt(0.47, 0.31)) // shallow dip
        p.addCurve(to: pt(0.78, 0.28), control1: pt(0.60, 0.22), control2: pt(0.70, 0.22)) // broad right chamber top
        p.addCurve(to: pt(0.93, 0.52), control1: pt(0.88, 0.32), control2: pt(0.94, 0.40)) // rounded right shoulder
        p.addCurve(to: pt(0.40, 0.99), control1: pt(0.91, 0.74), control2: pt(0.64, 0.92)) // right/back wall to apex
        p.closeSubpath()
        return p
    }
}

#Preview {
    BreathingView()
        .modelContainer(for: [BreathingSession.self], inMemory: true)
}
