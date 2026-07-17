import SwiftUI

/// The arming control — a living eye. Dormant, it's drowsy: lids mostly
/// closed, blinking sleepily every few seconds. Hover and it perks up.
/// Armed, it snaps wide open and — true to the name — never blinks: a
/// glowing iris inside a slow-rotating gradient ring, with an ignition
/// ripple + spark burst on the transition. All motion stills under Reduce
/// Motion; the glow stays.
struct PowerButton: View {
    var armed: Bool
    var busy: Bool
    var mood: Mood
    var action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var ignition = 0
    @State private var hovering = false

    private let core: CGFloat = 104
    private let field: CGFloat = 168

    var body: some View {
        Button(action: action) {
            TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
                let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
                ZStack {
                    bloom(t: t)
                    ring(t: t)
                    coreDisc
                    eye(t: t)
                    if busy {
                        ProgressView()
                            .controlSize(.regular)
                            .tint(.white)
                            .offset(y: 34)
                    }
                    IgnitionBurst(trigger: ignition, diameter: core)
                }
            }
            .frame(width: field, height: field)
            .compositingGroup()
        }
        .buttonStyle(PowerPressStyle())
        .onHover { hovering = $0 }
        .animation(Theme.springGentle, value: armed)
        .animation(Theme.springQuick, value: busy)
        .onChange(of: armed) { _, isOn in
            if isOn { ignition += 1 }
        }
        .accessibilityLabel(armed ? "Disarm" : "Keep awake while lid closed")
        .accessibilityHint(armed ? "Restores normal sleep behavior" : "Shows arming options")
    }

    // MARK: Layers

    private func bloom(t: TimeInterval) -> some View {
        let breathe = (reduceMotion || !armed) ? 1.0 : 1.0 + 0.05 * sin(t * 1.1)
        return Circle()
            .fill(
                RadialGradient(
                    colors: [mood.accent.opacity(armed ? 0.55 : 0.0), .clear],
                    center: .center,
                    startRadius: 6,
                    endRadius: field * 0.52
                )
            )
            .frame(width: field, height: field)
            .scaleEffect(armed ? breathe : 0.7)
            .blur(radius: 6)
    }

    private func ring(t: TimeInterval) -> some View {
        ZStack {
            Circle()
                .strokeBorder(Color.white.opacity(armed ? 0.10 : 0.14), lineWidth: 2)
            Circle()
                .strokeBorder(
                    mood == .alert ? AnyShapeStyle(Theme.emberGradient) : AnyShapeStyle(Theme.ringGradient),
                    lineWidth: 3
                )
                .rotationEffect(.degrees(armed ? t.truncatingRemainder(dividingBy: 360) * 18 : 0))
                .opacity(armed ? 1 : 0)
                .glow(mood.accent, radius: 8, opacity: 0.7)
        }
        .frame(width: core + 22, height: core + 22)
    }

    private var coreDisc: some View {
        ZStack {
            Circle()
                .fill(
                    armed
                        ? AnyShapeStyle(mood.accentGradient)
                        : AnyShapeStyle(
                            LinearGradient(
                                colors: [Color(white: 0.15), Color(white: 0.08)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .shadow(color: armed ? mood.accent.opacity(0.6) : .black.opacity(0.6), radius: armed ? 18 : 10, y: 4)

            // Glass: top light catch + hairline rim.
            Circle()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(armed ? 0.30 : 0.08), location: 0),
                            .init(color: .clear, location: 0.45),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            Circle()
                .strokeBorder(Color.white.opacity(armed ? 0.5 : 0.12), lineWidth: 1)
        }
        .frame(width: core, height: core)
    }

    private func eye(t: TimeInterval) -> some View {
        EyeCore(
            aperture: aperture(t: t),
            armed: armed,
            alert: mood == .alert
        )
        .frame(width: 62, height: 44)
        .opacity(busy ? 0.55 : 1)
        .animation(Theme.springQuick, value: hovering)
    }

    /// How open the eye is. Armed: wide open, unblinking. Dormant: drowsy,
    /// with a sleepy blink every ~4.8s (skipped under Reduce Motion), and a
    /// perk-up on hover — anticipation before commitment.
    private func aperture(t: TimeInterval) -> CGFloat {
        if armed { return 1.0 }
        if busy { return 0.55 }
        if mood == .focus { return 0.72 }

        var base: CGFloat = hovering ? 0.62 : 0.40
        if !reduceMotion, !hovering {
            let cycle = t.truncatingRemainder(dividingBy: 4.8)
            if cycle < 0.32 {
                let blink = sin(cycle / 0.32 * .pi)
                base *= 1 - 0.88 * blink
            }
        }
        return base
    }
}

// MARK: - The eye

/// Almond lens holding a core of light — deliberately abstract: no pupil,
/// no catchlight, nothing anatomical. Armed it's a beacon; dormant it's a
/// sleepy slit of dim light behind the lids.
struct EyeCore: View {
    var aperture: CGFloat
    var armed: Bool
    var alert: Bool

    var body: some View {
        ZStack {
            // The light inside, revealed by the lids.
            Circle()
                .fill(coreGradient)
                .frame(width: 34, height: 34)
                .blur(radius: 3)
                .glow(armed ? (alert ? Theme.ember : Theme.cyan) : .clear, radius: 10, opacity: 0.9)
                .mask(LensShape(aperture: aperture))

            // Lids.
            LensShape(aperture: aperture)
                .stroke(
                    armed ? AnyShapeStyle(.white) : AnyShapeStyle(.white.opacity(0.55)),
                    style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round)
                )
                .glow(armed ? .white : .clear, radius: 6, opacity: 0.5)
        }
        .animation(Theme.springQuick, value: armed)
    }

    private var coreGradient: RadialGradient {
        if armed {
            RadialGradient(
                colors: alert
                    ? [Color.white, Theme.ember.opacity(0.9), Theme.emberDeep.opacity(0)]
                    : [Color.white, Theme.cyan.opacity(0.9), Theme.armedDeep.opacity(0)],
                center: .center,
                startRadius: 1,
                endRadius: 19
            )
        } else {
            RadialGradient(
                colors: [Color(white: 0.5, opacity: 0.8), Color(white: 0.3, opacity: 0)],
                center: .center,
                startRadius: 1,
                endRadius: 17
            )
        }
    }
}

/// Two symmetric quad curves; `aperture` 0…1 opens the lids.
struct LensShape: Shape {
    var aperture: CGFloat

    var animatableData: CGFloat {
        get { aperture }
        set { aperture = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let mid = rect.midY
        let reach = rect.height * aperture
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: mid))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: mid),
            control: CGPoint(x: rect.midX, y: mid - reach)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: mid),
            control: CGPoint(x: rect.midX, y: mid + reach)
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - Press feel

private struct PowerPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .animation(Theme.springQuick, value: configuration.isPressed)
    }
}

// MARK: - Ignition

private struct RippleState {
    var scale: CGFloat = 1
    var opacity: Double = 0
}

/// One expanding gradient ring plus a burst of sparks, fired on each arm.
private struct IgnitionBurst: View {
    let trigger: Int
    let diameter: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.ringGradient, lineWidth: 3)
                .frame(width: diameter + 22, height: diameter + 22)
                .keyframeAnimator(initialValue: RippleState(), trigger: trigger) { view, value in
                    view
                        .scaleEffect(value.scale)
                        .opacity(value.opacity)
                } keyframes: { _ in
                    KeyframeTrack(\.scale) {
                        CubicKeyframe(1.0, duration: 0.02)
                        CubicKeyframe(1.75, duration: 0.85)
                    }
                    KeyframeTrack(\.opacity) {
                        CubicKeyframe(0.9, duration: 0.02)
                        CubicKeyframe(0.0, duration: 0.85)
                    }
                }

            ForEach(0..<10, id: \.self) { index in
                Spark(trigger: trigger, index: index, diameter: diameter)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct SparkState {
    var distance: CGFloat = 0
    var opacity: Double = 0
}

private struct Spark: View {
    let trigger: Int
    let index: Int
    let diameter: CGFloat

    var body: some View {
        // Deterministic pseudo-random flavor per spark.
        let angle = Double(index) * 36.0 + Double((index * 37) % 11)
        let reach = diameter * (0.72 + CGFloat((index * 13) % 7) * 0.03)

        Circle()
            .fill(index.isMultiple(of: 2) ? Theme.cyan : Theme.violet)
            .frame(width: 4, height: 4)
            .keyframeAnimator(initialValue: SparkState(), trigger: trigger) { view, value in
                view
                    .opacity(value.opacity)
                    .offset(
                        x: cos(angle * .pi / 180) * value.distance,
                        y: sin(angle * .pi / 180) * value.distance
                    )
            } keyframes: { _ in
                KeyframeTrack(\.distance) {
                    CubicKeyframe(diameter * 0.42, duration: 0.02)
                    CubicKeyframe(reach, duration: 0.7)
                }
                KeyframeTrack(\.opacity) {
                    CubicKeyframe(1.0, duration: 0.02)
                    CubicKeyframe(0.0, duration: 0.7)
                }
            }
    }
}
