import SwiftUI
import LidlessCore

/// Design tokens. Spacing is 4pt-grid only; anything not on the grid is a bug.
///
/// Lidless is locked to dark mode by design: the interface is a dark
/// instrument panel where glow carries state. Every mood re-tints the same
/// atmosphere — dormant (asleep, dim graphite), focus (deciding), vigil
/// (armed, cyan-indigo aurora), alert (amber warning).
enum Theme {
    // Spacing.
    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s5: CGFloat = 20
    static let s6: CGFloat = 24
    static let s8: CGFloat = 32

    static let cardRadius: CGFloat = 16
    static let panelWidth: CGFloat = 344

    // Palette.
    static let void = Color(red: 0.027, green: 0.031, blue: 0.058)      // panel base
    static let indigo = Color(red: 0.42, green: 0.42, blue: 0.98)
    static let cyan = Color(red: 0.20, green: 0.83, blue: 0.98)
    static let violet = Color(red: 0.66, green: 0.55, blue: 0.99)
    static let ember = Color(red: 1.00, green: 0.62, blue: 0.26)
    static let emberDeep = Color(red: 0.95, green: 0.35, blue: 0.25)

    static let armed = cyan
    static let armedDeep = indigo

    static var armedGradient: LinearGradient {
        LinearGradient(colors: [indigo, cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var emberGradient: LinearGradient {
        LinearGradient(colors: [emberDeep, ember], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var ringGradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(stops: [
                .init(color: indigo, location: 0.0),
                .init(color: cyan, location: 0.35),
                .init(color: violet, location: 0.65),
                .init(color: indigo, location: 1.0),
            ]),
            center: .center
        )
    }

    static let springQuick = Animation.spring(response: 0.32, dampingFraction: 0.72)
    static let springGentle = Animation.spring(response: 0.55, dampingFraction: 0.82)
}

// MARK: - Mood

/// The single knob the whole atmosphere hangs off.
enum Mood: Equatable {
    case dormant   // disarmed, quiet
    case focus     // arming decision in progress
    case vigil     // armed — the showpiece state
    case alert     // leaked override / low-battery warning

    var auroraColors: [Color] {
        switch self {
        case .dormant: [Theme.indigo.opacity(0.5), Theme.violet.opacity(0.35), Theme.cyan.opacity(0.3)]
        case .focus: [Theme.indigo, Theme.cyan.opacity(0.7), Theme.violet.opacity(0.6)]
        case .vigil: [Theme.indigo, Theme.cyan, Theme.violet]
        case .alert: [Theme.emberDeep, Theme.ember, Theme.violet.opacity(0.5)]
        }
    }

    var auroraStrength: Double {
        switch self {
        case .dormant: 0.16
        case .focus: 0.30
        case .vigil: 0.44
        case .alert: 0.36
        }
    }

    var accent: Color {
        switch self {
        case .alert: Theme.ember
        default: Theme.cyan
        }
    }

    var accentGradient: LinearGradient {
        self == .alert ? Theme.emberGradient : Theme.armedGradient
    }
}

extension AppState {
    var mood: Mood {
        if overrideLeaked { return .alert }
        if case .lowBatteryWarning = pendingArm?.assessment { return .alert }
        if case .refusedBelowFloor = pendingArm?.assessment { return .alert }
        if pendingArm != nil { return .focus }
        if isArmed || phase == .arming { return .vigil }
        return .dormant
    }
}

// MARK: - Aurora

/// The living background: three big blurred gradient orbs drifting on slow
/// sine paths. Motion pauses (a fixed, still composition) with Reduce Motion.
struct AuroraBackground: View {
    var mood: Mood

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 24, paused: reduceMotion)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            GeometryReader { proxy in
                let size = proxy.size
                ZStack {
                    Theme.void

                    orb(mood.auroraColors[0],
                        diameter: size.width * 1.1,
                        x: size.width * (0.15 + 0.22 * sin(t * 0.11)),
                        y: size.height * (0.12 + 0.10 * cos(t * 0.09)))
                    orb(mood.auroraColors[1],
                        diameter: size.width * 0.9,
                        x: size.width * (0.85 + 0.18 * sin(t * 0.07 + 2.1)),
                        y: size.height * (0.45 + 0.16 * cos(t * 0.13 + 0.7)))
                    orb(mood.auroraColors[2],
                        diameter: size.width * 1.0,
                        x: size.width * (0.40 + 0.24 * sin(t * 0.05 + 4.2)),
                        y: size.height * (0.95 + 0.08 * cos(t * 0.08 + 1.9)))

                    // Grain-free vignette keeps edges anchored in the void.
                    RadialGradient(
                        colors: [.clear, Theme.void.opacity(0.85)],
                        center: .center,
                        startRadius: size.width * 0.25,
                        endRadius: size.width * 0.85
                    )
                }
                .opacity(mood.auroraStrength)
                .background(Theme.void)
            }
        }
        .animation(Theme.springGentle, value: mood)
        .drawingGroup()
        .ignoresSafeArea()
    }

    private func orb(_ color: Color, diameter: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        Circle()
            .fill(color)
            .frame(width: diameter, height: diameter)
            .position(x: x, y: y)
            .blur(radius: diameter * 0.28)
    }
}

// MARK: - Glass & glow

/// Nested surface: a quiet solid tint with a hairline. Used for secondary
/// content so it never competes with the one true glass element per view
/// (liquid-glass layer economy: never stack translucent panes).
struct GlassCard: ViewModifier {
    var tint: Color = .white

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
        content
            .background(tint.opacity(0.05), in: shape)
            .overlay(
                shape.strokeBorder(
                    LinearGradient(
                        colors: [tint.opacity(0.16), tint.opacity(0.03)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
            )
    }
}

/// The primary liquid-glass sheet: real material blur over the aurora, a
/// specular top boundary, an interior light streak, and a floating shadow —
/// highlight, illumination, and depth in three layers.
struct GlassSheet: ViewModifier {
    var cornerRadius: CGFloat = 24

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background(.ultraThinMaterial, in: shape)
            .background(Theme.void.opacity(0.2), in: shape)
            .overlay(
                // Interior illumination: a soft diagonal streak of light.
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.10), location: 0.0),
                        .init(color: .clear, location: 0.35),
                        .init(color: .clear, location: 0.75),
                        .init(color: .white.opacity(0.04), location: 1.0),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(shape)
                .allowsHitTesting(false)
            )
            .overlay(
                // Specular boundary: bright top edge fading down the sides.
                shape.strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.50), location: 0.0),
                            .init(color: .white.opacity(0.10), location: 0.35),
                            .init(color: .white.opacity(0.05), location: 1.0),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
            )
            .shadow(color: .black.opacity(0.35), radius: 18, y: 10)
    }
}

extension View {
    func card() -> some View { modifier(GlassCard()) }

    func card(tint: Color) -> some View { modifier(GlassCard(tint: tint)) }

    func glassSheet(cornerRadius: CGFloat = 24) -> some View {
        modifier(GlassSheet(cornerRadius: cornerRadius))
    }

    /// Soft light bloom behind glowing foreground elements.
    func glow(_ color: Color, radius: CGFloat = 10, opacity: Double = 0.8) -> some View {
        shadow(color: color.opacity(opacity), radius: radius)
    }
}

/// Numerals and headlines that carry the accent light.
struct GlowText: View {
    var text: String
    var font: Font
    var gradient: LinearGradient
    var glowColor: Color
    var glowRadius: CGFloat = 8

    var body: some View {
        Text(text)
            .font(font)
            .monospacedDigit()
            .foregroundStyle(gradient)
            .glow(glowColor, radius: glowRadius, opacity: 0.55)
    }
}

// MARK: - Formatting helpers shared by menu panel, window, and widget copy.

enum Format {
    static func percent(_ value: Int?) -> String {
        value.map { "\($0)%" } ?? "—"
    }

    static func drain(_ perHour: Double?) -> String {
        guard let perHour else { return "—" }
        return String(format: "%.1f%%/hr", perHour)
    }

    static func clock(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    static func clock(_ time: HMTime) -> String {
        var components = DateComponents()
        components.hour = time.hour
        components.minute = time.minute
        let date = Calendar.current.date(from: components) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }

    static func duration(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = interval >= 3600 ? [.hour, .minute] : [.minute]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        return formatter.string(from: max(interval, 60)) ?? "—"
    }

    /// "in 6h 24m" / "in 3m"
    static func countdown(to date: Date, from now: Date = Date()) -> String {
        "in " + duration(date.timeIntervalSince(now))
    }

    static func dayAndTime(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).hour().minute())
    }
}
