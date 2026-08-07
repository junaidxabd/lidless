import Charts
import SwiftUI
import LidlessCore

/// Every past session with its battery curve — the audit trail that builds
/// trust in the cutoffs actually firing.
struct HistoryPane: View {
    @Environment(AppState.self) private var state
    @State private var selectedID: UUID?
    @State private var confirmingClear = false
    private let rendersEvidence: Bool

    init(initialSelection: UUID? = nil, rendersEvidence: Bool = false) {
        _selectedID = State(initialValue: initialSelection)
        self.rendersEvidence = rendersEvidence
    }

    var body: some View {
        Group {
            if state.sessionStore.sessions.isEmpty {
                ContentUnavailableView {
                    Label("No sessions yet", systemImage: "moon.stars")
                } description: {
                    Text("After your first keep-awake session, its duration, cutoff, and battery curve appear here.")
                }
            } else {
                if rendersEvidence {
                    HStack(spacing: 0) {
                        deterministicHistoryList
                            .frame(width: 340)
                        Divider()
                        detail
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    HSplitView {
                        list
                            .frame(minWidth: 220, idealWidth: 260, maxWidth: 300)
                        detail
                            .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .background(Theme.canvas)
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
                        if state.clearSessionHistory() {
                            selectedID = nil
                        }
                    }
                    Button("Cancel", role: .cancel) {}
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

    /// Native List selection remains the production surface. AppKit does not
    /// rasterize that backing view reliably offscreen, so evidence renders use
    /// this fixed mirror with the same row and explicit selected treatment.
    private var deterministicHistoryList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(state.sessionStore.sessions) { session in
                    SessionRow(session: session)
                        .padding(.horizontal, Theme.s3)
                        .padding(.vertical, Theme.s2)
                        .background(
                            session.id == selectedID
                                ? Theme.surfaceElevated
                                : Theme.canvas
                        )
                        .overlay(alignment: .leading) {
                            if session.id == selectedID {
                                Rectangle()
                                    .fill(Theme.verifiedActive)
                                    .frame(width: 3)
                            }
                        }
                        .accessibilityAddTraits(
                            session.id == selectedID ? .isSelected : []
                        )
                }
            }
        }
        .background(Theme.canvas)
    }

    @ViewBuilder
    private var detail: some View {
        if let session = state.sessionStore.sessions.first(where: { $0.id == selectedID }) {
            SessionDetailView(session: session)
        } else {
            ContentUnavailableView(
                "Select a session",
                systemImage: "clock.arrow.circlepath",
                description: Text("Choose a session in the history list to inspect its verified record.")
            )
        }
    }

    static func endReasonText(_ reason: SessionEndReason) -> String {
        switch reason {
        case .cutoff(let cutoff):
            switch cutoff {
            case .thermalTelemetryUnavailable: "Thermal state unavailable"
            case .batteryTelemetryUnavailable: "Battery state unavailable"
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
        case .helperProofLost: "Safety proof lost"
        case .persistenceFailure: "Session record failure"
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
            .foregroundStyle(Theme.verifiedActive)
            .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round))
        }
        .chartYScale(domain: 0...100)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .accessibilityHidden(true)
    }
}

// MARK: - Detail

struct SessionDetailView: View {
    let session: KeepAwakeSession

    var body: some View {
        GeometryReader { proxy in
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

                    if proxy.size.width >= 390 {
                        HStack(spacing: Theme.s2) {
                            durationStat
                                .frame(width: 110)
                            batteryStat
                                .frame(width: 110)
                            averageDrainStat
                                .frame(width: 110)
                        }
                    } else {
                        stackedStats
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
    }

    private var durationStat: some View {
        StatCell(
            title: "Duration",
            systemImage: "hourglass",
            value: session.duration.map(Format.duration) ?? "—"
        )
    }

    private var stackedStats: some View {
        VStack(spacing: Theme.s2) {
            durationStat
            batteryStat
            averageDrainStat
        }
    }

    private var batteryStat: some View {
        StatCell(
            title: "Battery",
            systemImage: "battery.50percent",
            value: batterySpan,
            detail: session.totalDrain.map { "\(Int($0))% drained" }
        )
    }

    private var averageDrainStat: some View {
        StatCell(
            title: "Avg drain",
            systemImage: "chart.line.downtrend.xyaxis",
            value: Format.drain(session.averageDrainPerHour)
        )
    }

    private var batterySpan: String {
        let start = session.startPercent.map { "\($0)%" } ?? "—"
        let end = session.endPercent.map { "\($0)%" } ?? "—"
        return "\(start) → \(end)"
    }
}
