import Charts
import SwiftUI
import LidlessCore

struct OverviewPane: View {
    var renderScenario: InstrumentRenderScenario? = nil

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                OverviewContent(renderScenario: renderScenario)
                    .padding(proxy.size.width < 720 ? Theme.s4 : Theme.s6)
            }
            .scrollIndicators(.automatic)
        }
        .navigationTitle("Overview")
        .background(Theme.canvas)
    }
}

/// Scroll-free overview content is also used by deterministic render checks.
struct OverviewContent: View {
    @Environment(AppState.self) private var state

    var renderScenario: InstrumentRenderScenario? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s4) {
            statusCard

            if let confirmation = renderScenario?.confirmation {
                RenderArmConfirmationCard(confirmation: confirmation)
            } else if let pending = state.pendingArm {
                ArmConfirmCard(pending: pending)
            }

            adaptiveSafetyLedger

            if presentation == .outsideOverride || presentation == .unknown {
                recoveryCard
            }

            if let last = state.lastEndedSession,
               presentation != .verifiedArmed,
               presentation != .restoring {
                recapCard(last)
            }
        }
        .frame(maxWidth: 1040, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .top)
    }

    // MARK: Proof and action

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: Theme.s3) {
            HStack(alignment: .center) {
                StatusPill(presentation: presentation)
                Spacer()
                Text("SYSTEM SLEEP")
                    .font(.caption2.weight(.semibold))
                    .kerning(0.7)
                    .foregroundStyle(Theme.textTertiary)
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .bottom, spacing: Theme.s6) {
                    statusCopy
                    Spacer(minLength: Theme.s4)
                    if !hasConfirmation {
                        primaryAction
                            .frame(width: 240)
                    }
                }

                VStack(alignment: .leading, spacing: Theme.s4) {
                    statusCopy
                    if !hasConfirmation {
                        primaryAction
                    }
                }
            }

            Divider()
                .overlay(Theme.separator)

            Label(proofText, systemImage: proofSymbol)
                .font(.callout)
                .foregroundStyle(proofTint)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.s5)
        .card(tint: proofTint)
    }

    private var statusCopy: some View {
        VStack(alignment: .leading, spacing: Theme.s2) {
            Text(headline)
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if let detail {
                Text(detail)
                    .font(.body)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if presentation == .verifiedArmed,
               let cutoffText {
                Label(cutoffText, systemImage: "clock")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(Theme.textPrimary)
                    .monospacedDigit()
            }
        }
    }

    private var primaryAction: some View {
        PrimaryActionButton(
            presentation: presentation,
            actionAvailable: primaryActionAvailable,
            keepAwake: beginKeepAwake,
            restoreNormalSleep: restoreNormalSleep,
            checkAgain: checkAgain
        )
    }

    private var presentation: SleepPresentationState {
        renderScenario?.presentation ?? state.sleepPresentation
    }

    private var headline: String {
        renderScenario?.headline ?? state.statusHeadline
    }

    private var detail: String? {
        renderScenario?.detail ?? state.statusDetail
    }

    private var cutoffText: String? {
        if let renderScenario { return renderScenario.cutoffText }
        guard let projected = state.projectedCutoff else { return nil }
        return "\(Format.duration(projected.date.timeIntervalSince(state.now))) · \(projected.label)"
    }

    private var proofText: String {
        if let renderScenario { return renderScenario.proof }
        return switch presentation {
        case .verifiedNormal:
            "Current registry evidence verifies that normal sleep is enabled."
        case .verifyingArm:
            "Lidless is waiting for helper ownership and registry evidence."
        case .verifiedArmed:
            "Current helper ownership and the system override both verify keep-awake."
        case .restoring:
            "The restore request is active; normal sleep is not verified yet."
        case .outsideOverride:
            "The system override is active without a verified Lidless session."
        case .unknown:
            "Lidless does not have fresh evidence of the system sleep state."
        }
    }

    private var proofSymbol: String {
        switch presentation {
        case .verifiedNormal: "checkmark.shield.fill"
        case .verifiedArmed: "lock.shield.fill"
        case .verifyingArm, .restoring: "hourglass"
        case .outsideOverride: "exclamationmark.triangle.fill"
        case .unknown: "questionmark.diamond.fill"
        }
    }

    private var proofTint: Color {
        switch presentation {
        case .verifiedNormal: Theme.verifiedNormal
        case .verifiedArmed: Theme.verifiedActive
        case .verifyingArm, .restoring: Theme.transition
        case .outsideOverride: Theme.caution
        case .unknown: Theme.critical
        }
    }

    private var hasConfirmation: Bool {
        renderScenario?.confirmation != nil || state.pendingArm != nil
    }

    private var primaryActionAvailable: Bool {
        if let renderScenario { return renderScenario.primaryActionAvailable }
        switch presentation {
        case .verifiedNormal:
            let stateHasDiverged = state.sleepPresentation != .verifiedNormal
            return state.helperState.isUsable
                && !stateHasDiverged
                && !state.sessionEvidenceRequiresReconciliation
                && state.pendingArm == nil
        case .verifiedArmed:
            return state.phase == .armed
        case .outsideOverride:
            return state.phase == .disarmed && state.pendingArm == nil
        case .unknown:
            return true
        case .verifyingArm, .restoring:
            return false
        }
    }

    private func beginKeepAwake() {
        guard renderScenario == nil else { return }
        state.beginArmFlow()
    }

    private func restoreNormalSleep() {
        guard renderScenario == nil else { return }
        if state.sleepPresentation == .outsideOverride {
            Task { await state.repairOverride() }
        } else {
            Task { await state.disarm() }
        }
    }

    private func checkAgain() {
        guard renderScenario == nil else { return }
        Task { await state.refreshHelperState() }
    }

    // MARK: Responsive ledger

    private var adaptiveSafetyLedger: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: Theme.s4) {
                batteryLedgerCard
                    .frame(minWidth: 300)
                currentSafeguardsCard
                    .frame(minWidth: 300)
            }

            VStack(alignment: .leading, spacing: Theme.s4) {
                batteryLedgerCard
                currentSafeguardsCard
            }
        }
    }

    private var batteryLedgerCard: some View {
        VStack(alignment: .leading, spacing: Theme.s3) {
            HStack(alignment: .firstTextBaseline) {
                Label(
                    state.battery.state == .noBattery ? "Power ledger" : "Battery ledger",
                    systemImage: renderScenario?.batterySymbol ?? Symbols.battery(
                        percent: state.battery.percent,
                        charging: state.battery.isCharging,
                        state: state.battery.state
                    )
                )
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

                Spacer()

                Text(renderScenario?.batteryValue ?? Format.percent(state.battery.percent))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .monospacedDigit()
            }

            HStack(spacing: Theme.s4) {
                metric(
                    title: "Power",
                    value: renderScenario?.batteryCaption ?? liveBatteryCaption
                )
                metric(
                    title: "Drain",
                    value: renderScenario?.drainValue ?? Format.drain(state.drainPerHour)
                )
                metric(
                    title: "Thermals",
                    value: renderScenario?.thermalValue ?? state.thermalStatusText,
                    tint: renderScenario?.thermalIsElevated == true || state.thermalIsElevated
                        ? Theme.caution
                        : Theme.textPrimary
                )
            }

            if state.rollingSamples.count >= 2,
               presentation != .unknown {
                BatteryChart(samples: state.rollingSamples, floor: activeFloor)
                    .frame(height: 148)
            } else {
                Text("Battery history appears after two verified samples.")
                    .font(.callout)
                    .foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity, minHeight: 72, alignment: .center)
            }
        }
        .padding(Theme.s4)
        .card()
    }

    private func metric(
        title: String,
        value: String,
        tint: Color = Theme.textPrimary
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.s1) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
            Text(value)
                .font(.callout.weight(.semibold))
                .foregroundStyle(tint)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var currentSafeguardsCard: some View {
        VStack(alignment: .leading, spacing: Theme.s3) {
            Label("Current safeguards", systemImage: "checkmark.shield")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            safeguardRow(
                title: "Battery floor",
                value: batteryFloorDescription,
                symbol: "battery.25percent"
            )
            safeguardRow(
                title: "Thermal guard",
                value: state.effectiveConfig.thermalEnabled ? "Enabled" : "Off",
                symbol: "thermometer.medium"
            )
            safeguardRow(
                title: "Time limit",
                value: timeLimitDescription,
                symbol: "clock"
            )
            safeguardRow(
                title: "Sleep proof",
                value: proofShortValue,
                symbol: proofSymbol,
                tint: proofTint
            )
        }
        .padding(Theme.s4)
        .card()
    }

    private func safeguardRow(
        title: String,
        value: String,
        symbol: String,
        tint: Color = Theme.textSecondary
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.s2) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
                .frame(width: 18)
                .accessibilityHidden(true)
            Text(title)
                .font(.callout)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(.callout.weight(.medium))
                .foregroundStyle(tint == Theme.textSecondary ? Theme.textPrimary : tint)
                .multilineTextAlignment(.trailing)
        }
    }

    private var batteryFloorDescription: String {
        if renderScenario != nil { return "Request at 20%" }
        let config = state.effectiveConfig
        guard config.batteryFloorEnabled, state.battery.state != .noBattery else {
            return "Inactive"
        }
        return "Request at \(config.batteryFloorPercent)%"
    }

    private var timeLimitDescription: String {
        if let cutoff = state.projectedCutoff { return cutoff.label }
        let config = state.effectiveConfig
        if config.durationEnabled { return Format.duration(config.durationSeconds) }
        if config.offTimeEnabled { return "Until \(Format.clock(config.offTime))" }
        return "No time limit"
    }

    private var proofShortValue: String {
        switch presentation {
        case .verifiedNormal: "Normal verified"
        case .verifiedArmed: "Session verified"
        case .verifyingArm: "Verifying"
        case .restoring: "Restoring"
        case .outsideOverride: "Outside override"
        case .unknown: "Unverified"
        }
    }

    private var liveBatteryCaption: String {
        if state.battery.state == .noBattery { return "No battery" }
        if state.battery.isCharging { return "Charging" }
        return state.battery.state == .ac ? "On power" : "On battery"
    }

    private var activeFloor: Int? {
        if renderScenario != nil {
            return presentation == .unknown ? nil : 20
        }
        let config = state.effectiveConfig
        return config.batteryFloorEnabled && state.battery.state != .noBattery
            ? config.batteryFloorPercent
            : nil
    }

    // MARK: Recap and recovery

    private var recoveryCard: some View {
        VStack(alignment: .leading, spacing: Theme.s2) {
            Label(
                presentation == .outsideOverride
                    ? "Recovery is available"
                    : "Fresh proof is required",
                systemImage: presentation == .outsideOverride
                    ? "wrench.and.screwdriver"
                    : "arrow.clockwise"
            )
            .font(.headline)
            .foregroundStyle(proofTint)

            Text(
                presentation == .outsideOverride
                    ? "Restore normal sleep from the primary action above. Lidless will keep showing recovery until the registry verifies the override is off."
                    : "Check again from the primary action above. If proof remains unavailable, Setup explains the safe recovery path."
            )
            .font(.callout)
            .foregroundStyle(Theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)

            Button("Open Setup") {
                guard renderScenario == nil else { return }
                state.mainPane = .setup
            }
            .buttonStyle(.bordered)
        }
        .padding(Theme.s4)
        .card(tint: proofTint)
    }

    private func recapCard(_ session: KeepAwakeSession) -> some View {
        HStack(spacing: Theme.s3) {
            Image(systemName: "checkmark.circle")
                .foregroundStyle(Theme.verifiedNormal)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Theme.s1) {
                Text("Previous session")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Text(recapDetail(session))
                    .font(.callout)
                    .foregroundStyle(Theme.textSecondary)
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
        var parts = [session.duration.map(Format.duration) ?? "Duration unavailable"]
        if let reason = session.endReason {
            parts.append(HistoryPane.endReasonText(reason))
        }
        if let drain = session.totalDrain, drain > 0 {
            parts.append("\(Int(drain))% battery used")
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: Battery chart

struct BatteryChart: View {
    let samples: [BatterySample]
    var floor: Int?

    var body: some View {
        Chart {
            ForEach(Array(samples.enumerated()), id: \.offset) { _, sample in
                LineMark(
                    x: .value("Time", sample.time),
                    y: .value("Battery", sample.percent)
                )
                .foregroundStyle(Theme.verifiedActive)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
            }

            if let floor {
                RuleMark(y: .value("Floor", floor))
                    .foregroundStyle(Theme.caution)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .annotation(position: .trailing, alignment: .leading) {
                        Text("\(floor)%")
                            .font(.caption2)
                            .foregroundStyle(Theme.caution)
                    }
            }
        }
        .chartXScale(domain: paddedTimeDomain)
        .chartYScale(domain: 0...100)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine()
                    .foregroundStyle(Theme.separator)
                AxisValueLabel(format: .dateTime.hour().minute())
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .chartYAxis {
            AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                AxisGridLine()
                    .foregroundStyle(Theme.separator)
                AxisValueLabel {
                    if let value = value.as(Int.self) {
                        Text("\(value)%")
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Battery trend")
        .accessibilityValue(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        guard let first = samples.first, let last = samples.last else {
            return "No verified battery samples"
        }
        let start = Int(first.percent.rounded())
        let end = Int(last.percent.rounded())
        let elapsed = max(0, last.time.timeIntervalSince(first.time))
        var parts = ["Battery changed from \(start)% to \(end)% over \(Format.duration(elapsed))"]
        if let floor {
            parts.append("Safety floor \(floor)%")
        }
        return parts.joined(separator: ". ")
    }

    private var paddedTimeDomain: ClosedRange<Date> {
        let first = samples.first?.time ?? Date(timeIntervalSince1970: 0)
        let last = samples.last?.time ?? first
        let padding = max(last.timeIntervalSince(first) * 0.04, 60)
        return first.addingTimeInterval(-padding)...last.addingTimeInterval(padding)
    }
}
