import LidlessCore
import SwiftUI

/// The arming control — the panel's one true liquid-glass object. A wide
/// glass track with a bright puck you tap or drag from Sleep to Awake.
/// Armed, the track floods with the aurora gradient and blooms; the puck's
/// icon flips from moon to bolt. Slide-to-unlock lineage: deliberate,
/// physical, satisfying — and nothing is watching you.
struct GlassSwitch: View {
    var armed: Bool
    var busy: Bool
    var presentation: SleepPresentationState
    var restoresOnAction: Bool
    var actionAvailable: Bool
    var mood: Mood
    var action: () -> Void

    @State private var dragX: CGFloat?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let trackWidth: CGFloat = 296
    private let trackHeight: CGFloat = 72
    private let puckDiameter: CGFloat = 62
    private let inset: CGFloat = 5

    private var travel: CGFloat { trackWidth - puckDiameter - inset * 2 }

    private var needsAttention: Bool {
        presentation == .outsideOverride || presentation == .unknown
    }

    private var puckPosition: CGFloat {
        if let dragX { return dragX }
        return armed ? travel : 0
    }

    var body: some View {
        ZStack {
            track
            labels
            puck
        }
        .frame(width: trackWidth, height: trackHeight)
        .glow(armed ? mood.accent : .clear, radius: 26, opacity: 0.35)
        .contentShape(Capsule())
        .onTapGesture {
            guard !busy, actionAvailable else { return }
            action()
        }
        .gesture(dragGesture)
        .disabled(!actionAvailable || busy)
        .animation(Theme.springGentle, value: armed)
        .animation(Theme.springQuick, value: busy)
        .animation(Theme.springQuick, value: presentation)
        .accessibilityElement()
        .accessibilityLabel(
            restoresOnAction ? "Restore normal sleep" : "Keep awake while lid closed"
        )
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(
            restoresOnAction
                ? "Restores normal sleep behavior"
                : needsAttention
                ? "Lidless must verify normal sleep before arming"
                : "Shows arming options"
        )
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            guard !busy, actionAvailable else { return }
            action()
        }
    }

    // MARK: Track

    private var track: some View {
        ZStack {
            Capsule()
                .fill(.ultraThinMaterial)
            Capsule()
                .fill(mood.accentGradient)
                .opacity(armed ? 0.85 : 0)
            // Depth: soft inner shadow at the top of the well.
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: .black.opacity(0.35), location: 0),
                            .init(color: .clear, location: 0.4),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 2
                )
                .blur(radius: 1)
                .opacity(armed ? 0.3 : 1)
            // Specular boundary.
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(armed ? 0.7 : 0.4), location: 0),
                            .init(color: .white.opacity(0.08), location: 0.5),
                            .init(color: .white.opacity(armed ? 0.25 : 0.06), location: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        }
    }

    private var labels: some View {
        HStack {
            Label("Sleep", systemImage: "moon.zzz.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(armed ? 0.45 : 0.0))
            Spacer()
            Label("Awake", systemImage: "bolt.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(armed ? 0.0 : 0.45))
        }
        .padding(.horizontal, Theme.s5)
        .allowsHitTesting(false)
    }

    // MARK: Puck

    private var puck: some View {
        ZStack {
            // A bright solid bead — deliberately not glass-on-glass.
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.99), Color(white: 0.82)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            Circle()
                .strokeBorder(.white.opacity(0.9), lineWidth: 0.5)
            if busy {
                ProgressView()
                    .controlSize(.small)
                    .tint(Color(white: 0.3))
            } else {
                Image(systemName: puckSymbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(
                        needsAttention
                            ? AnyShapeStyle(Theme.ember)
                            : armed
                                ? AnyShapeStyle(Theme.armedGradient)
                                : AnyShapeStyle(Color(white: 0.45))
                    )
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .frame(width: puckDiameter, height: puckDiameter)
        .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
        .offset(x: -trackWidth / 2 + inset + puckDiameter / 2 + puckPosition)
    }

    // MARK: Drag

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                guard !busy, actionAvailable else { return }
                let base: CGFloat = armed ? travel : 0
                dragX = min(max(base + value.translation.width, 0), travel)
            }
            .onEnded { _ in
                guard !busy, actionAvailable else {
                    dragX = nil
                    return
                }
                guard let position = dragX else { return }
                let crossed = (position > travel / 2) != armed
                withAnimation(Theme.springGentle) {
                    dragX = nil
                }
                if crossed {
                    action()
                }
            }
    }

    private var puckSymbol: String {
        switch presentation {
        case .outsideOverride: "exclamationmark.triangle.fill"
        case .unknown: "questionmark"
        default: armed ? "bolt.fill" : "moon.zzz.fill"
        }
    }

    private var accessibilityValue: String {
        switch presentation {
        case .verifiedNormal: "Off"
        case .verifyingArm: "Verifying system sleep state"
        case .verifiedArmed: "On"
        case .restoring: "Restoring normal sleep"
        case .outsideOverride: "System sleep is disabled outside Lidless"
        case .unknown: "System sleep state unknown"
        }
    }
}
