import Charts
import SwiftUI
import WidgetKit
import LidlessCore

@main
struct LidlessWidgetBundle: WidgetBundle {
    var body: some Widget {
        LidlessStatusWidget()
    }
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
                    if entry.showsArmed {
                        LinearGradient(
                            colors: [Color(red: 0.10, green: 0.12, blue: 0.30), Color(red: 0.04, green: 0.05, blue: 0.13)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    } else {
                        Color.clear
                    }
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
}

// MARK: - Views

struct LidlessWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    var body: some View {
        Group {
            if entry.snapshot != nil {
                switch family {
                case .systemMedium:
                    MediumView(entry: entry)
                default:
                    SmallView(entry: entry)
                }
            } else {
                EmptyStateView()
            }
        }
        .fontDesign(.rounded)
        .widgetURL(URL(string: "lidless://open"))
    }
}

private struct SmallView: View {
    let entry: SnapshotEntry

    var body: some View {
        let snapshot = entry.snapshot!
        let armed = entry.showsArmed
        VStack(alignment: .leading, spacing: 4) {
            StatusHeader(entry: entry)
            Spacer(minLength: 0)
            BatteryLine(snapshot: snapshot, armed: armed)
            Text(statusLine(entry: entry))
                .font(.caption)
                .foregroundStyle(armed ? AnyShapeStyle(.white.opacity(0.75)) : AnyShapeStyle(.secondary))
                .lineLimit(2)
            if armed, let cutoff = snapshot.projectedCutoff, cutoff > entry.date {
                Text(timerInterval: entry.date...cutoff, countsDown: true)
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct MediumView: View {
    let entry: SnapshotEntry

    var body: some View {
        let snapshot = entry.snapshot!
        let armed = entry.showsArmed
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                StatusHeader(entry: entry)
                Spacer(minLength: 0)
                BatteryLine(snapshot: snapshot, armed: armed)
                Text(statusLine(entry: entry))
                    .font(.caption)
                    .foregroundStyle(armed ? AnyShapeStyle(.white.opacity(0.75)) : AnyShapeStyle(.secondary))
                if armed, let cutoff = snapshot.projectedCutoff, cutoff > entry.date {
                    Text(timerInterval: entry.date...cutoff, countsDown: true)
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
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
                        .foregroundStyle(armed ? Color(red: 0.30, green: 0.78, blue: 0.98) : Color.accentColor)
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
                        .foregroundStyle(armed ? AnyShapeStyle(.white.opacity(0.6)) : AnyShapeStyle(.tertiary))
                }
                if armed {
                    Link(destination: URL(string: "lidless://disarm")!) {
                        Text("Disarm")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.white.opacity(0.16), in: Capsule())
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
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
        return "Restoring normal sleep…"
    case .outsideOverride:
        return "Sleep override active — not Lidless"
    case .unknown:
        return entry.isStale
            ? "Lidless isn't running — state unknown"
            : "Sleep state unknown"
    }
}

private struct StatusHeader: View {
    let entry: SnapshotEntry

    var body: some View {
        let armed = entry.showsArmed
        let presentation = entry.presentation
        HStack(spacing: 4) {
            Image(systemName: symbol(for: presentation))
                .font(.caption.weight(.semibold))
            Text(label(for: presentation))
                .font(.caption2.weight(.bold))
                .kerning(0.8)
        }
        .foregroundStyle(
            armed
                ? AnyShapeStyle(Color(red: 0.45, green: 0.85, blue: 1.0))
                : (presentation == .outsideOverride || presentation == .unknown)
                    ? AnyShapeStyle(.orange)
                    : AnyShapeStyle(.secondary)
        )
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
        case .verifiedNormal: "OFF"
        case .verifyingArm: "CHECKING"
        case .verifiedArmed: "AWAKE"
        case .restoring: "RESTORING"
        case .outsideOverride: "WARNING"
        case .unknown: "CHECK"
        }
    }
}

private struct BatteryLine: View {
    let snapshot: WidgetSnapshot
    let armed: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: batterySymbol(percent: snapshot.batteryPercent, charging: snapshot.isCharging))
                .font(.caption)
            Text(snapshot.batteryPercent.map { "\($0)%" } ?? "—")
                .font(.title2.weight(.bold))
                .monospacedDigit()
        }
        .foregroundStyle(armed ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
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
        VStack(spacing: 6) {
            Image(systemName: "moon.zzz.fill")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Open Lidless once to connect")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
