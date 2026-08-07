import SwiftUI
import LidlessCore

// MARK: - Proof-first state badge

struct StatusPill: View {
    let presentation: SleepPresentationState

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Label(label, systemImage: symbol)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, Theme.s2)
            .padding(.vertical, Theme.s1)
            .foregroundStyle(color)
            .background(color.opacity(0.12), in: Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.28), lineWidth: 1))
            .animation(reduceMotion ? nil : Theme.quickTransition, value: presentation)
            .accessibilityLabel(accessibilityLabel)
    }

    private var label: String {
        switch presentation {
        case .verifiedNormal: "VERIFIED NORMAL"
        case .verifyingArm: "VERIFYING"
        case .verifiedArmed: "KEEP-AWAKE ON"
        case .restoring: "RESTORING"
        case .outsideOverride: "OUTSIDE OVERRIDE"
        case .unknown: "UNVERIFIED"
        }
    }

    private var symbol: String {
        switch presentation {
        case .verifiedNormal: "checkmark.circle.fill"
        case .verifyingArm: "hourglass"
        case .verifiedArmed: "bolt.fill"
        case .restoring: "arrow.triangle.2.circlepath"
        case .outsideOverride: "exclamationmark.triangle.fill"
        case .unknown: "questionmark.circle.fill"
        }
    }

    private var color: Color {
        switch presentation {
        case .verifiedNormal: Theme.verifiedNormal
        case .verifyingArm, .restoring: Theme.transition
        case .verifiedArmed: Theme.verifiedActive
        case .outsideOverride: Theme.caution
        case .unknown: Theme.critical
        }
    }

    private var accessibilityLabel: String {
        switch presentation {
        case .verifiedNormal: "Sleep state: normal sleep verified"
        case .verifyingArm: "Sleep state: verifying keep-awake"
        case .verifiedArmed: "Sleep state: keep-awake verified"
        case .restoring: "Sleep state: restoring normal sleep"
        case .outsideOverride: "Sleep state: outside override detected"
        case .unknown: "Sleep state: unverified"
        }
    }
}

// MARK: - Canonical primary action

enum PrimaryActionSemantic: Equatable {
    case keepAwake
    case restoreNormalSleep
    case checkAgain
    case progress
}

extension SleepPresentationState {
    var primaryActionSemantic: PrimaryActionSemantic {
        switch self {
        case .verifiedNormal: .keepAwake
        case .verifiedArmed, .outsideOverride: .restoreNormalSleep
        case .unknown: .checkAgain
        case .verifyingArm, .restoring: .progress
        }
    }
}

/// The single prominent action shared by panel and overview. Its visible and
/// accessibility semantics come only from the canonical sleep presentation;
/// a pending confirmation cannot silently turn a Keep Awake control into
/// Cancel, and transitional states cannot dispatch a second mutation.
struct PrimaryActionButton: View {
    let presentation: SleepPresentationState
    var actionAvailable = true
    let keepAwake: () -> Void
    let restoreNormalSleep: () -> Void
    let checkAgain: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var semantic: PrimaryActionSemantic {
        presentation.primaryActionSemantic
    }

    var body: some View {
        Button(action: performAction) {
            HStack(spacing: Theme.s2) {
                if semantic == .progress {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: symbol)
                        .accessibilityHidden(true)
                }
                Text(title)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(tint)
        .disabled(!actionAvailable || semantic == .progress)
        .animation(reduceMotion ? nil : Theme.quickTransition, value: presentation)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }

    private var title: String {
        switch semantic {
        case .keepAwake: "Keep Awake…"
        case .restoreNormalSleep: "Restore Normal Sleep"
        case .checkAgain: "Check Again"
        case .progress:
            presentation == .verifyingArm ? "Verifying…" : "Restoring…"
        }
    }

    private var symbol: String {
        switch semantic {
        case .keepAwake: "bolt"
        case .restoreNormalSleep: "moon.zzz.fill"
        case .checkAgain: "arrow.clockwise"
        case .progress: "hourglass"
        }
    }

    private var tint: Color {
        switch presentation {
        case .verifiedNormal, .verifiedArmed: Theme.verifiedActive
        case .outsideOverride: Theme.caution
        case .unknown: Theme.critical
        case .verifyingArm, .restoring: Theme.surfaceElevated
        }
    }

    private var accessibilityLabel: String { title }

    private var accessibilityHint: String {
        switch semantic {
        case .keepAwake: "Reviews safety limits before changing system sleep behavior"
        case .restoreNormalSleep: "Requests and verifies normal system sleep behavior"
        case .checkAgain: "Checks the system sleep state again"
        case .progress: "Wait for verification to finish"
        }
    }

    private func performAction() {
        switch semantic {
        case .keepAwake: keepAwake()
        case .restoreNormalSleep: restoreNormalSleep()
        case .checkAgain: checkAgain()
        case .progress: break
        }
    }
}

// MARK: - Inline banners

enum BannerKind {
    case warning, error, info

    var color: Color {
        switch self {
        case .warning: Theme.caution
        case .error: Theme.critical
        case .info: Theme.verifiedActive
        }
    }

    var symbol: String {
        switch self {
        case .warning: "exclamationmark.triangle.fill"
        case .error: "xmark.octagon.fill"
        case .info: "info.circle.fill"
        }
    }
}

struct Banner<Actions: View>: View {
    let kind: BannerKind
    let message: String
    @ViewBuilder var actions: Actions

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.s2) {
            Image(systemName: kind.symbol)
                .foregroundStyle(kind.color)
                .accessibilityHidden(true)
            Text(message)
                .font(.callout)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            actions
        }
        .padding(Theme.s3)
        .background(Theme.surfaceElevated, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .strokeBorder(kind.color.opacity(0.36), lineWidth: 1)
        )
    }
}

// MARK: - Preset controls

struct PresetChip: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.callout.weight(.medium))
                .lineLimit(1)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .tint(Theme.verifiedActive)
    }
}

// MARK: - Stat cell

struct StatCell: View {
    let title: String
    let systemImage: String
    let value: String
    var detail: String? = nil
    var tint: Color = .secondary
    var lit: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s1) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
            valueText
                .contentTransition(.numericText())
            if let detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.s3)
        .card()
    }

    @ViewBuilder
    private var valueText: some View {
        let font = Font.title3.weight(.semibold)
        if tint != .secondary {
            Text(value)
                .font(font)
                .monospacedDigit()
                .foregroundStyle(tint)
        } else {
            Text(value)
                .font(font)
                .monospacedDigit()
                .foregroundStyle(lit ? Theme.verifiedActive : Theme.textPrimary)
        }
    }
}

// MARK: - Stat strip

struct StatStrip: View {
    struct Item {
        var icon: String
        var value: String
        var caption: String
        var tint: Color?
        var lit: Bool

        init(icon: String, value: String, caption: String, tint: Color? = nil, lit: Bool = false) {
            self.icon = icon
            self.value = value
            self.caption = caption
            self.tint = tint
            self.lit = lit
        }
    }

    let items: [Item]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                cell(item)
                if index < items.count - 1 {
                    Rectangle()
                        .fill(Theme.separator)
                        .frame(width: 1, height: 40)
                }
            }
        }
        .padding(.vertical, Theme.s3)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .strokeBorder(Theme.separator, lineWidth: 1)
        )
    }

    private func cell(_ item: Item) -> some View {
        VStack(spacing: Theme.s1) {
            Text(item.value)
                .font(.body.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(item.tint ?? (item.lit ? Theme.verifiedActive : Theme.textPrimary))
                .contentTransition(.numericText())
            Label(item.caption, systemImage: item.icon)
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Footer buttons

struct FooterButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.callout)
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .foregroundStyle(Theme.textSecondary)
    }
}

// MARK: - Symbols

enum Symbols {
    static func battery(
        percent: Int?,
        charging: Bool,
        state: PowerSourceState
    ) -> String {
        switch state {
        case .noBattery:
            return "powerplug"
        case .unknown:
            return "questionmark.circle"
        case .ac, .battery:
            break
        }
        if charging { return "battery.100percent.bolt" }
        guard let percent else { return "exclamationmark.triangle" }
        switch percent {
        case 88...: return "battery.100percent"
        case 63..<88: return "battery.75percent"
        case 38..<63: return "battery.50percent"
        case 13..<38: return "battery.25percent"
        default: return "battery.0percent"
        }
    }
}

// MARK: - Thermal descriptions

extension AppState {
    var thermalStatusText: String {
        guard ThermalEvidenceSafety.isUsable(thermal, at: now) else {
            return switch processThermal {
            case .critical: "Critical · pmset unavailable"
            case .serious: "Serious · pmset unavailable"
            case .fair: "Fair · pmset unavailable"
            case .nominal: "Unavailable"
            }
        }
        if let level = thermal?.warningLevel, level > 0 { return "Warning \(level)" }
        if let speed = thermal?.cpuSpeedLimit, speed < 100 { return "CPU \(speed)%" }
        switch processThermal {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        }
    }

    var thermalIsElevated: Bool {
        CutoffEngine.isThermalViolation(
            config: effectiveConfig,
            thermal: thermal,
            processThermal: processThermal,
            at: now
        )
    }
}
