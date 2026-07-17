import Charts
import SwiftUI
import LidlessCore

/// Every past session with its battery curve — the audit trail that builds
/// trust in the cutoffs actually firing.
struct HistoryPane: View {
    @Environment(AppState.self) private var state
    @State private var selectedID: UUID?
    @State private var confirmingClear = false

    var body: some View {
        Group {
            if state.sessionStore.sessions.isEmpty {
                ContentUnavailableView {
                    Label("No sessions yet", systemImage: "moon.stars")
                } description: {
                    Text("After your first keep-awake session, its duration, cutoff, and battery curve appear here.")
                }
            } else {
                HSplitView {
                    list
                        .frame(minWidth: 300, idealWidth: 340, maxWidth: 420)
                    detail
                        .frame(minWidth: 380, maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .navigationTitle("History")
        .toolbar {
            if !state.sessionStore.sessions.isEmpty {
                Button {
                    confirmingClear = true
                } label: {
                    Label("Clear History", systemImage: "trash")
                }
                .confirmationDialog(
                    "Clear all session history?",
                    isPresented: $confirmingClear
                ) {
                    Button("Clear History", role: .destructive) {
                        state.sessionStore.clearHistory()
                        selectedID = nil
                    }
                }
            }
        }
    }

    private var list: some View {
        List(state.sessionStore.sessions, selection: $selectedID) { session in
            SessionRow(session: session)
                .tag(session.id)
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private var detail: some View {
        let session = state.sessionStore.sessions.first { $0.id == selectedID }
            ?? state.sessionStore.sessions.first
        if let session {
            SessionDetailView(session: session)
        } else {
            Color.clear
        }
    }

    static func endReasonText(_ reason: SessionEndReason) -> String {
        switch reason {
        case .cutoff(let cutoff):
            switch cutoff {
            case .batteryFloor(let percent, _): "Battery floor (\(percent)%)"
            case .thermal: "Thermal protection"
            case .offTime: "Off-time"
            case .durationElapsed: "Duration limit"
            case .scheduleEnded: "Schedule ended"
            }
        case .manual: "Disarmed manually"
        case .appQuit: "App quit"
        case .helperWatchdog: "Watchdog restore"
        case .helperRestored: "Helper restarted"
        case .systemSlept: "Mac was put to sleep"
        case .uninstalled: "Uninstalled"
        }
    }

    static func endReasonIsCutoff(_ reason: SessionEndReason?) -> Bool {
        reason?.isCutoff ?? false
    }
}

// MARK: - Row

private struct SessionRow: View {
    let session: KeepAwakeSession

    var body: some View {
        HStack(spacing: Theme.s3) {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.startedAt.formatted(.dateTime.weekday(.abbreviated).month().day().hour().minute()))
                    .font(.body.weight(.medium))
                HStack(spacing: Theme.s1) {
                    Text(session.duration.map(Format.duration) ?? "—")
                    if let reason = session.endReason {
                        Text("·")
                        Text(HistoryPane.endReasonText(reason))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            if session.samples.count >= 2 {
                Sparkline(samples: session.samples)
                    .frame(width: 72, height: 26)
            }
        }
        .padding(.vertical, Theme.s1)
    }
}

/// Miniature battery curve, no axes — just the shape of the night.
struct Sparkline: View {
    let samples: [BatterySample]

    var body: some View {
        Chart(Array(samples.enumerated()), id: \.offset) { _, sample in
            LineMark(
                x: .value("t", sample.time),
                y: .value("%", sample.percent)
            )
            .foregroundStyle(Theme.armed)
            .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round))
        }
        .chartYScale(domain: 0...100)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
    }
}

// MARK: - Detail

struct SessionDetailView: View {
    let session: KeepAwakeSession

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.s4) {
                VStack(alignment: .leading, spacing: Theme.s1) {
                    Text(session.startedAt.formatted(date: .complete, time: .shortened))
                        .font(.title3.weight(.semibold))
                    if let reason = session.endReason {
                        Label(
                            HistoryPane.endReasonText(reason),
                            systemImage: HistoryPane.endReasonIsCutoff(reason) ? "moon.zzz.fill" : "hand.raised"
                        )
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    }
                }

                Grid(horizontalSpacing: Theme.s2, verticalSpacing: Theme.s2) {
                    GridRow {
                        StatCell(
                            title: "Duration",
                            systemImage: "hourglass",
                            value: session.duration.map(Format.duration) ?? "—"
                        )
                        StatCell(
                            title: "Battery",
                            systemImage: "battery.50percent",
                            value: batterySpan,
                            detail: session.totalDrain.map { "\(Int($0))% drained" }
                        )
                        StatCell(
                            title: "Avg drain",
                            systemImage: "chart.line.downtrend.xyaxis",
                            value: Format.drain(session.averageDrainPerHour)
                        )
                    }
                }

                if session.samples.count >= 2 {
                    VStack(alignment: .leading, spacing: Theme.s2) {
                        Text("Battery curve")
                            .font(.headline)
                        BatteryChart(samples: session.samples, floor: nil)
                            .frame(height: 220)
                    }
                    .padding(Theme.s4)
                    .card()
                }

                LabeledContent("Cutoffs in force", value: session.cutoffSummary)
                    .font(.callout)
                if session.lowPowerModeUsed || session.tcpKeepAliveUsed {
                    LabeledContent(
                        "While armed",
                        value: [
                            session.lowPowerModeUsed ? "Low Power Mode" : nil,
                            session.tcpKeepAliveUsed ? "Network keep-alive" : nil,
                        ].compactMap(\.self).joined(separator: " · ")
                    )
                    .font(.callout)
                }
            }
            .padding(Theme.s5)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var batterySpan: String {
        let start = session.startPercent.map { "\($0)%" } ?? "—"
        let end = session.endPercent.map { "\($0)%" } ?? "—"
        return "\(start) → \(end)"
    }
}
