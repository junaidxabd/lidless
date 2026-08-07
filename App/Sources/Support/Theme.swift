import SwiftUI
import LidlessCore

/// Fixed dark tokens for Lidless's quiet safety-instrument interface.
///
/// State color is deliberately sparse: green means normal sleep was verified,
/// blue means a Lidless keep-awake session was verified, orange is a
/// recoverable warning, and red means the system state is unsafe or unverified.
enum Theme {
    // MARK: Spacing

    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s5: CGFloat = 20
    static let s6: CGFloat = 24
    static let s8: CGFloat = 32

    static let cardRadius: CGFloat = 10
    static let controlRadius: CGFloat = 8
    static let panelWidth: CGFloat = 380

    // MARK: Fixed dark surfaces

    static let canvas = Color(red: 0.055, green: 0.059, blue: 0.071)
    static let surface = Color(red: 0.086, green: 0.094, blue: 0.110)
    static let surfaceElevated = Color(red: 0.118, green: 0.126, blue: 0.145)
    static let separator = Color.white.opacity(0.12)
    static let separatorStrong = Color.white.opacity(0.20)

    static let textPrimary = Color.white.opacity(0.94)
    static let textSecondary = Color.white.opacity(0.70)
    static let textTertiary = Color.white.opacity(0.56)
    static let textDisabled = Color.white.opacity(0.38)

    // MARK: Semantic state

    static let verifiedNormal = Color(red: 0.34, green: 0.78, blue: 0.50)
    static let verifiedActive = Color(red: 0.31, green: 0.60, blue: 1.00)
    static let caution = Color(red: 1.00, green: 0.64, blue: 0.26)
    static let critical = Color(red: 1.00, green: 0.35, blue: 0.36)
    static let transition = Color.white.opacity(0.66)

    static let quickTransition = Animation.easeOut(duration: 0.14)
    static let gentleTransition = Animation.easeInOut(duration: 0.20)
}

// MARK: - Semantic mood compatibility

/// Existing surfaces still ask AppState for a broad mood. The redesigned
/// components interpret it only as semantic state color; it never changes the
/// background or creates atmospheric decoration.
enum Mood: Equatable {
    case dormant
    case focus
    case vigil
    case alert

    var accent: Color {
        switch self {
        case .dormant: Theme.verifiedNormal
        case .focus: Theme.transition
        case .vigil: Theme.verifiedActive
        case .alert: Theme.caution
        }
    }
}

extension AppState {
    var mood: Mood {
        if overrideLeaked || overrideStateUnknown { return .alert }
        if case .lowBatteryWarning = pendingArm?.assessment { return .alert }
        if pendingArm?.assessment.allowsArm == false { return .alert }
        if pendingArm != nil { return .focus }
        if isArmed || phase == .arming { return .vigil }
        return .dormant
    }
}

// MARK: - Surfaces

struct GlassCard: ViewModifier {
    var tint: Color?

    init(tint: Color? = nil) {
        self.tint = tint
    }

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
        content
            .background(Theme.surface, in: shape)
            .overlay(
                shape.strokeBorder(tint?.opacity(0.28) ?? Theme.separator, lineWidth: 1)
            )
    }
}

/// Compatibility name for the former custom-glass treatment. The replacement
/// uses one native material and one hairline, with no simulated illumination.
struct GlassSheet: ViewModifier {
    var cornerRadius: CGFloat = 12

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background(.regularMaterial, in: shape)
            .overlay(shape.strokeBorder(Theme.separatorStrong, lineWidth: 1))
    }
}

extension View {
    func card() -> some View {
        modifier(GlassCard())
    }

    func card(tint: Color) -> some View {
        modifier(GlassCard(tint: tint))
    }

    func glassSheet(cornerRadius: CGFloat = 12) -> some View {
        modifier(GlassSheet(cornerRadius: cornerRadius))
    }
}

// MARK: - Formatting helpers shared by menu panel, window, and widget copy

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

    static func countdown(to date: Date, from now: Date = Date()) -> String {
        "in " + duration(date.timeIntervalSince(now))
    }

    static func dayAndTime(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).hour().minute())
    }
}
