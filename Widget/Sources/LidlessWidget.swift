import Charts
import SwiftUI
import WidgetKit
import LidlessCore

#if !LIDLESS_WIDGET_RENDER_HARNESS
@main
struct LidlessWidgetBundle: WidgetBundle {
    var body: some Widget {
        LidlessStatusWidget()
    }
}
#endif

private enum WidgetPalette {
    static let canvas = Color(red: 0.055, green: 0.059, blue: 0.071)
    static let surface = Color(red: 0.086, green: 0.094, blue: 0.110)
    static let textPrimary = Color.white.opacity(0.94)
    static let textSecondary = Color.white.opacity(0.70)
    static let verifiedNormal = Color(red: 0.34, green: 0.78, blue: 0.50)
    static let verifiedActive = Color(red: 0.31, green: 0.60, blue: 1.00)
    static let caution = Color(red: 1.00, green: 0.64, blue: 0.26)
    static let critical = Color(red: 1.00, green: 0.35, blue: 0.36)
    static let transition = Color.white.opacity(0.66)
}

/// Pure mirror of the app's published snapshot: armed state, battery
/// projection, and (medium) the recent battery curve.
struct LidlessStatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: LidlessWidgetKind.status,
            provider: SnapshotProvider()
        ) { entry in
            LidlessWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetPalette.canvas
                }
        }
        .configurationDisplayName("Lidless")
        .description("Keep-awake state and battery projection.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// Widget target has no dependency on the app target, so the kind string
// lives here; the app's WidgetPublisher.widgetKind mirrors it.
enum LidlessWidgetKind {
    static let status = "LidlessStatus"
}

// MARK: - Provider

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?

    /// The app republishes at least every ~60s while running; a snapshot much
    /// older than that is no longer evidence of either normal sleep or an
    /// active session.
    var isStale: Bool {
        guard let snapshot else { return false }
        return !snapshot.isFresh(at: date)
    }

    var presentation: SleepPresentationState {
        snapshot?.effectiveSleepPresentation(at: date) ?? .unknown
    }

    var showsArmed: Bool {
        presentation == .verifiedArmed
    }
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: Date(), snapshot: .previewArmed)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(
            date: Date(),
            snapshot: context.isPreview ? .previewArmed : WidgetStore.load()
        ))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let snapshot = WidgetStore.load()
        let now = Date()
        var entries = [SnapshotEntry(date: now, snapshot: snapshot)]
        var refresh = now.addingTimeInterval(15 * 60)
        if let cutoff = snapshot?.projectedCutoff, cutoff > now {
            refresh = min(refresh, cutoff.addingTimeInterval(30))
        }
        // If the app dies, no reload ever comes. Every state claim, including
        // OFF, expires; pre-schedule the fail-closed entry client-side.
        if let snapshot {
            switch snapshot.evidenceFreshness(at: now) {
            case .fresh:
                let freshnessBoundary = snapshot.updatedAt.addingTimeInterval(WidgetSnapshot.freshnessLifetime)
                let staleAt = freshnessBoundary.addingTimeInterval(1)
                entries.append(SnapshotEntry(date: staleAt, snapshot: snapshot))
                refresh = min(refresh, staleAt.addingTimeInterval(60))
            case .expired:
                refresh = min(refresh, now.addingTimeInterval(5 * 60))
            case .rejectedFuture:
                // Re-evaluating the same future-dated bytes later could make
                // rejected evidence look fresh without a publication. A save
                // calls reloadTimelines, so only new bytes may revive it.
                completion(Timeline(entries: entries, policy: .never))
                return
            }
        }
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }
}

extension WidgetSnapshot {
    static let previewArmed = WidgetSnapshot(
        armed: true,
        statusLine: "Until 7:00 AM",
        batteryPercent: 64,
        isCharging: false,
        drainPerHour: 8.5,
        projectedCutoff: Date().addingTimeInterval(6.4 * 3600),
        projectedCutoffLabel: "Until 7:00 AM",
        overrideActive: true,
        overrideStateVerified: true,
        sleepPresentation: .verifiedArmed,
        recentSamples: (0..<12).map { index in
            BatterySample(
                time: Date().addingTimeInterval(TimeInterval(index - 12) * 900),
                percent: 88 - Double(index) * 2,
                isDischarging: true
            )
        },
        updatedAt: Date()
    )

    static func evidenceNormal(at now: Date) -> WidgetSnapshot {
        WidgetSnapshot(
            armed: false,
            statusLine: "Sleeping normally",
            batteryPercent: 82,
            isCharging: false,
            drainPerHour: 3.2,
            projectedCutoff: nil,
            projectedCutoffLabel: nil,
            overrideActive: false,
            overrideStateVerified: true,
            sleepPresentation: .verifiedNormal,
            recentSamples: evidenceSamples(at: now),
            updatedAt: now
        )
    }

    static func evidenceArmed(at now: Date) -> WidgetSnapshot {
        WidgetSnapshot(
            armed: true,
            statusLine: "Until 7:00 AM",
            batteryPercent: 64,
            isCharging: false,
            drainPerHour: 8.5,
            projectedCutoff: now.addingTimeInterval(6.4 * 3600),
            projectedCutoffLabel: "Until 7:00 AM",
            overrideActive: true,
            overrideStateVerified: true,
            sleepPresentation: .verifiedArmed,
            recentSamples: evidenceSamples(at: now),
            updatedAt: now
        )
    }

    private static func evidenceSamples(at now: Date) -> [BatterySample] {
        (0..<12).map { index in
            BatterySample(
                time: now.addingTimeInterval(TimeInterval(index - 12) * 900),
                percent: 88 - Double(index) * 2,
                isDischarging: true
            )
        }
    }
}

enum WidgetRenderScenario: String, CaseIterable {
    case smallVerifiedNormal
    case mediumVerifiedArmed
    case smallStaleUnknown
    case mediumEmpty

    private static let evidenceNow = Date(timeIntervalSince1970: 1_786_117_600)

    var family: WidgetFamily {
        switch self {
        case .smallVerifiedNormal, .smallStaleUnknown: .systemSmall
        case .mediumVerifiedArmed, .mediumEmpty: .systemMedium
        }
    }

    var size: CGSize {
        switch family {
        case .systemSmall: CGSize(width: 170, height: 170)
        default: CGSize(width: 360, height: 170)
        }
    }

    var filename: String {
        switch self {
        case .smallVerifiedNormal: "widget-small-verified-normal.png"
        case .mediumVerifiedArmed: "widget-medium-verified-armed.png"
        case .smallStaleUnknown: "widget-small-stale-unknown.png"
        case .mediumEmpty: "widget-medium-empty.png"
        }
    }

    var entry: SnapshotEntry {
        switch self {
        case .smallVerifiedNormal:
            SnapshotEntry(
                date: Self.evidenceNow,
                snapshot: .evidenceNormal(at: Self.evidenceNow)
            )
        case .mediumVerifiedArmed:
            SnapshotEntry(
                date: Self.evidenceNow,
                snapshot: .evidenceArmed(at: Self.evidenceNow)
            )
        case .smallStaleUnknown:
            SnapshotEntry(
                date: Self.evidenceNow,
                snapshot: .evidenceNormal(at: Self.evidenceNow.addingTimeInterval(-3_600))
            )
        case .mediumEmpty:
            SnapshotEntry(date: Self.evidenceNow, snapshot: nil)
        }
    }
}

// MARK: - Views

struct LidlessWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry
    let renderFamily: WidgetFamily?

    init(entry: SnapshotEntry, renderFamily: WidgetFamily? = nil) {
        self.entry = entry
        self.renderFamily = renderFamily
    }

    var body: some View {
        Group {
            if entry.isStale {
                StaleEvidenceView()
            } else if entry.snapshot != nil {
                switch renderFamily ?? family {
                case .systemMedium:
                    MediumView(
                        entry: entry,
                        rendersStaticActions: renderFamily != nil
                    )
                default:
                    SmallView(entry: entry)
                }
            } else {
                EmptyStateView()
            }
        }
        .padding(2)
        .background(WidgetPalette.canvas)
        .widgetURL(URL(string: "lidless://open"))
        .accessibilityElement(children: .contain)
    }
}

private struct SmallView: View {
    let entry: SnapshotEntry

    var body: some View {
        let snapshot = entry.snapshot!
        VStack(alignment: .leading, spacing: 4) {
            StatusHeader(entry: entry)
            Spacer(minLength: 0)
            BatteryLine(snapshot: snapshot)
            Text(statusLine(entry: entry))
                .font(.caption)
                .foregroundStyle(color(for: entry.presentation))
                .lineLimit(2)
            if entry.showsArmed,
               let cutoff = snapshot.projectedCutoff,
               cutoff > entry.date {
                Text(timerInterval: entry.date...cutoff, countsDown: true)
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(WidgetPalette.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct MediumView: View {
    let entry: SnapshotEntry
    let rendersStaticActions: Bool

    var body: some View {
        let snapshot = entry.snapshot!
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                StatusHeader(entry: entry)
                Spacer(minLength: 0)
                BatteryLine(snapshot: snapshot)
                Text(statusLine(entry: entry))
                    .font(.caption)
                    .foregroundStyle(color(for: entry.presentation))
                if entry.showsArmed,
                   let cutoff = snapshot.projectedCutoff,
                   cutoff > entry.date {
                    Group {
                        if rendersStaticActions {
                            Text(staticCountdown(from: entry.date, to: cutoff))
                        } else {
                            Text(timerInterval: entry.date...cutoff, countsDown: true)
                        }
                    }
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(WidgetPalette.textPrimary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 4) {
                if snapshot.recentSamples.count >= 2 {
                    Chart(Array(snapshot.recentSamples.enumerated()), id: \.offset) { _, sample in
                        LineMark(
                            x: .value("t", sample.time),
                            y: .value("%", sample.percent)
                        )
                        .foregroundStyle(WidgetPalette.verifiedActive)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    }
                    .chartYScale(domain: 0...100)
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .frame(width: 120, height: 56)
                }
                if let drain = snapshot.drainPerHour {
                    Text(String(format: "%.1f%%/hr", drain))
                        .font(.caption2)
                        .foregroundStyle(WidgetPalette.textSecondary)
                }
                if entry.showsArmed {
                    if rendersStaticActions {
                        restoreNormalSleepLabel
                    } else {
                        Link(destination: URL(string: "lidless://disarm")!) {
                            restoreNormalSleepLabel
                        }
                        .accessibilityHint("Requests and verifies normal sleep in Lidless")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var restoreNormalSleepLabel: some View {
        Text("Restore Normal Sleep")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(WidgetPalette.surface, in: Capsule())
            .foregroundStyle(WidgetPalette.textPrimary)
    }
}

private func staticCountdown(from start: Date, to end: Date) -> String {
    let totalSeconds = max(0, Int(end.timeIntervalSince(start).rounded(.down)))
    let hours = totalSeconds / 3_600
    let minutes = (totalSeconds % 3_600) / 60
    let seconds = totalSeconds % 60
    return String(format: "%d:%02d:%02d", hours, minutes, seconds)
}

private func statusLine(entry: SnapshotEntry) -> String {
    guard entry.snapshot != nil else { return "" }
    switch entry.presentation {
    case .verifiedNormal:
        return "Sleeping normally"
    case .verifyingArm:
        return "Verifying sleep override…"
    case .verifiedArmed:
        return "Keep-awake active"
    case .restoring:
        return "Normal sleep not verified yet"
    case .outsideOverride:
        return "Sleep override active — not Lidless"
    case .unknown:
        return entry.isStale
            ? "No fresh Lidless evidence — state unknown"
            : "Sleep state unknown"
    }
}

private struct StatusHeader: View {
    let entry: SnapshotEntry

    var body: some View {
        let presentation = entry.presentation
        HStack(spacing: 4) {
            Image(systemName: symbol(for: presentation))
                .font(.caption.weight(.semibold))
            Text(label(for: presentation))
                .font(.caption2.weight(.bold))
        }
        .foregroundStyle(color(for: presentation))
        .accessibilityLabel(accessibilityLabel(for: presentation))
    }

    private func symbol(for presentation: SleepPresentationState) -> String {
        switch presentation {
        case .verifiedNormal: "moon.zzz.fill"
        case .verifyingArm: "hourglass"
        case .verifiedArmed: "bolt.fill"
        case .restoring: "arrow.triangle.2.circlepath"
        case .outsideOverride: "exclamationmark.triangle.fill"
        case .unknown: "questionmark.circle.fill"
        }
    }

    private func label(for presentation: SleepPresentationState) -> String {
        switch presentation {
        case .verifiedNormal: "VERIFIED NORMAL"
        case .verifyingArm: "VERIFYING"
        case .verifiedArmed: "KEEP-AWAKE ON"
        case .restoring: "RESTORING"
        case .outsideOverride: "OUTSIDE OVERRIDE"
        case .unknown: "UNVERIFIED"
        }
    }

    private func accessibilityLabel(
        for presentation: SleepPresentationState
    ) -> String {
        switch presentation {
        case .verifiedNormal: "Normal sleep verified"
        case .verifyingArm: "Verifying keep-awake"
        case .verifiedArmed: "Keep-awake verified"
        case .restoring: "Normal sleep restoration is not verified yet"
        case .outsideOverride: "Outside sleep override detected"
        case .unknown: "System sleep state unverified"
        }
    }
}

private struct BatteryLine: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: batterySymbol(percent: snapshot.batteryPercent, charging: snapshot.isCharging))
                .font(.caption)
            Text(snapshot.batteryPercent.map { "\($0)%" } ?? "—")
                .font(.title2.weight(.bold))
                .monospacedDigit()
        }
        .foregroundStyle(WidgetPalette.textPrimary)
    }

    private func batterySymbol(percent: Int?, charging: Bool) -> String {
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

private struct EmptyStateView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("NO FRESH EVIDENCE", systemImage: "questionmark.circle.fill")
                .font(.caption2.weight(.bold))
                .foregroundStyle(WidgetPalette.critical)
            Spacer(minLength: 0)
            Text("Open Lidless to publish current sleep evidence.")
                .font(.callout)
                .foregroundStyle(WidgetPalette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel("No fresh Lidless sleep evidence")
    }
}

private struct StaleEvidenceView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(
                "NO FRESH LIDLESS EVIDENCE",
                systemImage: "questionmark.circle.fill"
            )
            .font(.caption2.weight(.bold))
            .foregroundStyle(WidgetPalette.critical)
            .lineLimit(2)
            Spacer(minLength: 0)
            Text("Current sleep and battery state are unknown.")
                .font(.callout)
                .foregroundStyle(WidgetPalette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel(
            "No fresh Lidless evidence. Current sleep and battery state are unknown."
        )
    }
}

private func color(for presentation: SleepPresentationState) -> Color {
    switch presentation {
    case .verifiedNormal: WidgetPalette.verifiedNormal
    case .verifiedArmed: WidgetPalette.verifiedActive
    case .outsideOverride: WidgetPalette.caution
    case .unknown: WidgetPalette.critical
    case .verifyingArm, .restoring: WidgetPalette.transition
    }
}
