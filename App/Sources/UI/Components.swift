import SwiftUI
import LidlessCore

// MARK: - Status pill

struct StatusPill: View {
    let phase: AppState.Phase

    var body: some View {
        Text(label)
            .font(.caption.weight(.bold))
            .kerning(0.4)
            .padding(.horizontal, Theme.s3)
            .padding(.vertical, Theme.s1)
            .background(background, in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(active ? 0.35 : 0.10), lineWidth: 1))
            .foregroundStyle(active ? AnyShapeStyle(.white) : AnyShapeStyle(.white.opacity(0.55)))
            .glow(active ? Theme.cyan : .clear, radius: 8, opacity: 0.6)
            .animation(Theme.springQuick, value: phase)
    }

    private var active: Bool { phase == .armed || phase == .arming }

    private var label: String {
        switch phase {
        case .disarmed: "OFF"
        case .arming: "ARMING"
        case .armed: "AWAKE"
        case .disarming: "RESTORING"
        }
    }

    private var background: AnyShapeStyle {
        active ? AnyShapeStyle(Theme.armedGradient) : AnyShapeStyle(.white.opacity(0.06))
    }
}

// MARK: - Inline banners

enum BannerKind {
    case warning, error, info

    var color: Color {
        switch self {
        case .warning: Theme.ember
        case .error: Color(red: 1.0, green: 0.36, blue: 0.36)
        case .info: Theme.cyan
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
                .glow(kind.color, radius: 6, opacity: 0.7)
            Text(message)
                .font(.callout)
                .foregroundStyle(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            actions
        }
        .padding(Theme.s3)
        .background(kind.color.opacity(0.10), in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .strokeBorder(kind.color.opacity(0.35), lineWidth: 1)
        )
    }
}

// MARK: - Preset chips

struct PresetChip: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.callout.weight(.medium))
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(hovering ? AnyShapeStyle(.white) : AnyShapeStyle(.white.opacity(0.75)))
                .padding(.horizontal, Theme.s3)
                .padding(.vertical, 7)
        }
        .buttonStyle(.plain)
        .background(.white.opacity(hovering ? 0.12 : 0.06), in: Capsule())
        .overlay(
            Capsule().strokeBorder(
                hovering ? Theme.cyan.opacity(0.6) : .white.opacity(0.10),
                lineWidth: 1
            )
        )
        .glow(hovering ? Theme.cyan : .clear, radius: 8, opacity: 0.35)
        .scaleEffect(hovering ? 1.04 : 1)
        .contentShape(Capsule())
        .onHover { hovering = $0 }
        .animation(Theme.springQuick, value: hovering)
    }
}

// MARK: - Stat cell

struct StatCell: View {
    let title: String
    let systemImage: String
    let value: String
    var detail: String? = nil
    var tint: Color = .secondary
    /// Armed state lights the numerals with the accent gradient.
    var lit: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s1) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.45))
                .labelStyle(.titleAndIcon)
            valueText
                .contentTransition(.numericText())
            if let detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.35))
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
                .glow(tint, radius: 6, opacity: 0.5)
        } else if lit {
            GlowText(
                text: value,
                font: font,
                gradient: Theme.armedGradient,
                glowColor: Theme.cyan,
                glowRadius: 6
            )
        } else {
            Text(value)
                .font(font)
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.92))
        }
    }
}

// MARK: - Stat strip

/// One quiet nested surface holding the live numbers, hairline-divided —
/// a single strip instead of a grid of competing cards.
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
                        .fill(.white.opacity(0.08))
                        .frame(width: 1, height: 40)
                }
            }
        }
        .padding(.vertical, Theme.s3)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func cell(_ item: Item) -> some View {
        VStack(spacing: Theme.s1) {
            valueText(item)
                .contentTransition(.numericText())
            Label(item.caption, systemImage: item.icon)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.4))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func valueText(_ item: Item) -> some View {
        let font = Font.system(.body, design: .rounded).weight(.semibold)
        if let tint = item.tint {
            Text(item.value)
                .font(font)
                .monospacedDigit()
                .foregroundStyle(tint)
                .glow(tint, radius: 6, opacity: 0.5)
        } else if item.lit {
            GlowText(text: item.value, font: font, gradient: Theme.armedGradient, glowColor: Theme.cyan, glowRadius: 5)
        } else {
            Text(item.value)
                .font(font)
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.92))
        }
    }
}

// MARK: - Footer buttons

struct FooterButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.callout)
                .foregroundStyle(.white.opacity(hovering ? 0.95 : 0.5))
        }
        .buttonStyle(.plain)
        .animation(Theme.springQuick, value: hovering)
        .onHover { hovering = $0 }
    }
}

// MARK: - Symbols

enum Symbols {
    static func battery(percent: Int?, charging: Bool) -> String {
        if charging { return "battery.100percent.bolt" }
        guard let percent else { return "battery.100percent" }
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
            processThermal: processThermal
        )
    }
}
