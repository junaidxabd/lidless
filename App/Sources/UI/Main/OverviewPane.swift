import Charts
import SwiftUI
import LidlessCore

/// Leads with the one thing that must never be ambiguous: is this Mac going
/// to sleep normally, or not?
struct OverviewPane: View {
    var body: some View {
        ScrollView {
            OverviewContent()
                .padding(Theme.s6)
        }
        .navigationTitle("Overview")
    }
}

/// Extracted from the ScrollView so ImageRenderer (which can't rasterize
/// NSScrollView-backed views) can render it for README screenshots.
struct OverviewContent: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(spacing: Theme.s4) {
            heroCard

            // The arming flow must respond wherever it was started — the
            // same confirmation card the menu panel shows.
            if let pending = state.pendingArm {
                ArmConfirmCard(pending: pending)
            }

            if state.overrideLeaked {
                Banner(
                    kind: .warning,
                    message: "The system-wide sleep override is active, but no Lidless session explains it. Another tool may have set it, or a restore failed."
                ) {
                    Button("Restore Normal Sleep") {
                        Task { await state.repairOverride() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            if let last = state.lastEndedSession, !state.isArmed {
                recapCard(last)
            }

            batteryCard
        }
    }

    // MARK: - Hero

    private var heroCard: some View {
        HStack(spacing: Theme.s5) {
            ZStack {
                Circle()
                    .fill(state.isArmed ? AnyShapeStyle(Theme.armedGradient) : AnyShapeStyle(.quaternary.opacity(0.5)))
                    .frame(width: 64, height: 64)
                    .shadow(color: state.isArmed ? Theme.armed.opacity(0.4) : .clear, radius: 10)
                Image(systemName: state.isArmed ? "eye.fill" : "eye.slash")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(state.isArmed ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
            }

            VStack(alignment: .leading, spacing: Theme.s1) {
                if state.isArmed {
                    GlowText(
                        text: state.statusHeadline,
                        font: .largeTitle.weight(.semibold),
                        gradient: Theme.armedGradient,
                        glowColor: Theme.cyan,
                        glowRadius: 14
                    )
                } else {
                    Text(state.statusHeadline)
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(state.overrideLeaked ? AnyShapeStyle(Theme.ember) : AnyShapeStyle(.primary))
                }
                if let detail = state.statusDetail {
                    Text(detail)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                if state.isArmed, let elapsed = state.armedElapsed {
                    Text("Keeping watch for \(Format.duration(elapsed))")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            // Feature 10: the way out is always one click, always visible.
            if state.isArmed {
                Button {
                    Task { await state.disarm() }
                } label: {
                    Label("Disarm & Restore Sleep", systemImage: "moon.fill")
                        .padding(.horizontal, Theme.s1)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                Button {
                    state.beginArmFlow()
                    // The confirm card lives in the menu panel; surface it.
                } label: {
                    Label("Keep Awake…", systemImage: "eye")
                        .padding(.horizontal, Theme.s1)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.armedDeep)
                .controlSize(.large)
                .disabled(!state.helperState.isUsable)
            }
        }
        .padding(Theme.s5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .animation(Theme.springGentle, value: state.phase)
    }

    // MARK: - Recap

    private func recapCard(_ session: KeepAwakeSession) -> some View {
        HStack(spacing: Theme.s3) {
            Image(systemName: "checkmark.circle")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Last watch: \(session.duration.map(Format.duration) ?? "—")")
                    .font(.callout.weight(.medium))
                Text(recapDetail(session))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("View History") {
                state.mainPane = .history
            }
            .buttonStyle(.bordered)
        }
        .padding(Theme.s4)
        .card()
    }

    private func recapDetail(_ session: KeepAwakeSession) -> String {
        var parts: [String] = []
        if let reason = session.endReason {
            parts.append(HistoryPane.endReasonText(reason))
        }
        if let drain = session.totalDrain, drain > 0 {
            parts.append("drained \(Int(drain))%")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Battery

    private var batteryCard: some View {
        VStack(alignment: .leading, spacing: Theme.s3) {
            HStack {
                Label("Battery", systemImage: Symbols.battery(percent: state.battery.percent, charging: state.battery.isCharging))
                    .font(.headline)
                Spacer()
                Text(Format.percent(state.battery.percent))
                    .font(.headline)
                    .monospacedDigit()
                Text(state.battery.isCharging ? "Charging" : (state.battery.state == .ac ? "On power" : Format.drain(state.drainPerHour)))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if state.rollingSamples.count >= 2 {
                BatteryChart(samples: state.rollingSamples, floor: activeFloor)
                    .frame(height: 160)
            } else {
                HStack {
                    Spacer()
                    Text("Battery curve appears as data arrives")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(height: 80)
            }
        }
        .padding(Theme.s4)
        .card()
    }

    private var activeFloor: Int? {
        let cfg = state.effectiveConfig
        return cfg.batteryFloorEnabled ? cfg.batteryFloorPercent : nil
    }
}

// MARK: - Shared battery chart

struct BatteryChart: View {
    let samples: [BatterySample]
    var floor: Int?

    var body: some View {
        Chart {
            ForEach(Array(samples.enumerated()), id: \.offset) { _, sample in
                AreaMark(
                    x: .value("Time", sample.time),
                    y: .value("Battery", sample.percent)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.armed.opacity(0.25), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                LineMark(
                    x: .value("Time", sample.time),
                    y: .value("Battery", sample.percent)
                )
                .foregroundStyle(Theme.armedGradient)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
            }
            if let floor {
                RuleMark(y: .value("Floor", floor))
                    .foregroundStyle(.orange.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .annotation(position: .trailing, alignment: .leading) {
                        Text("\(floor)%")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
            }
        }
        .chartYScale(domain: 0...100)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour().minute())
            }
        }
        .chartYAxis {
            AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let v = value.as(Int.self) { Text("\(v)%") }
                }
            }
        }
    }
}
