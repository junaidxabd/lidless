import SwiftUI
import LidlessCore

/// Lidless's compact control center. The ordering is deliberate: current
/// proof, the one truthful mutation, safety choices, then supporting metrics.
struct MenuPanelView: View {
    var renderScenario: InstrumentRenderScenario? = nil

    var body: some View {
        Group {
            if renderScenario != nil {
                MenuPanelContent(renderScenario: renderScenario)
            } else {
                ViewThatFits(in: .vertical) {
                    MenuPanelContent(renderScenario: renderScenario)

                    ScrollView {
                        MenuPanelContent(renderScenario: renderScenario)
                    }
                    .scrollIndicators(.automatic)
                    .frame(maxHeight: 720)
                }
            }
        }
        .background(Theme.canvas)
        .frame(width: Theme.panelWidth)
        .frame(maxHeight: 720)
        .preferredColorScheme(.dark)
    }
}

/// Scroll-free content is kept separate so deterministic screenshots can use
/// ImageRenderer without depending on an AppKit scroll view.
struct MenuPanelContent: View {
    @Environment(AppState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var renderScenario: InstrumentRenderScenario? = nil

    /// Rechecks the live state at dispatch time so a control drawn from one
    /// proof state cannot perform the action for a newer state.
    private struct LiveActionTruth {
        var armed: Bool
        var actionAvailable: Bool
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if hasContextualBanner {
                contextualBanner
                    .padding(.top, Theme.s3)
            }

            statusSummary
                .padding(.top, Theme.s5)

            Divider()
                .overlay(Theme.separator)
                .padding(.vertical, Theme.s4)

            if hasConfirmation {
                confirmationRegion
            } else {
                primaryAction

                if presentation == .verifiedNormal {
                    presetRow
                        .padding(.top, Theme.s3)
                }
            }

            statStrip
                .padding(.top, Theme.s4)
        }
        .padding(Theme.s4)
        .frame(width: Theme.panelWidth)
        .animation(
            reduceMotion ? nil : Theme.gentleTransition,
            value: hasConfirmation
        )
        .animation(
            reduceMotion ? nil : Theme.quickTransition,
            value: presentation
        )
    }

    // MARK: Header toolbar

    private var header: some View {
        HStack(spacing: Theme.s2) {
            Text("Lidless")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            if state.isSimulation {
                Text("SIM")
                    .font(.caption2.weight(.semibold))
                    .kerning(0.5)
                    .padding(.horizontal, Theme.s2)
                    .padding(.vertical, Theme.s1)
                    .background(Theme.surfaceElevated, in: Capsule())
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()

            if renderScenario != nil {
                Image(systemName: "ellipsis.circle")
                    .font(.body)
                    .foregroundStyle(Theme.textSecondary)
                    .accessibilityHidden(true)
            } else {
                Menu {
                    Button("Open Overview", systemImage: "gauge.with.needle") {
                        state.requestMainWindow(pane: .overview)
                    }
                    Button("History", systemImage: "clock.arrow.circlepath") {
                        state.requestMainWindow(pane: .history)
                    }
                    Button("Settings", systemImage: "gearshape") {
                        state.requestMainWindow(pane: .cutoffs)
                    }
                    Divider()
                    Button("Quit Lidless", systemImage: "power") {
                        NSApp.terminate(nil)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.body)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .accessibilityLabel("Lidless menu")
            }
        }
    }

    // MARK: Context

    private var hasContextualBanner: Bool {
        if renderScenario?.banner != nil { return true }
        if state.lastError != nil || state.overrideLeaked { return true }
        return !state.helperState.isUsable
            && state.helperState != .checking
            && !state.helperLifecycleWorkInProgress
            && !state.isArmed
    }

    @ViewBuilder
    private var contextualBanner: some View {
        if let banner = renderScenario?.banner {
            Banner(kind: banner.kind, message: banner.message) {
                if let actionTitle = banner.actionTitle {
                    Button(actionTitle) {}
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
        } else if let error = state.lastError {
            Banner(kind: .error, message: error) {
                Button {
                    state.lastError = nil
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Dismiss error")
            }
        } else if state.overrideLeaked {
            Banner(
                kind: .warning,
                message: "A system-wide sleep override is active without a verified Lidless session."
            ) {
                EmptyView()
            }
        } else if !state.helperState.isUsable,
                  state.helperState != .checking,
                  !state.helperLifecycleWorkInProgress,
                  !state.isArmed {
            Banner(
                kind: helperBannerIsTerminal ? .warning : .info,
                message: helperBannerMessage
            ) {
                Button(helperBannerActionLabel) {
                    if state.helperState == .requiresApproval {
                        state.openApprovalSettings()
                    } else {
                        state.requestMainWindow(pane: .setup)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private var helperBannerIsTerminal: Bool {
        switch state.helperState {
        case .unknown, .notResponding, .stale:
            true
        default:
            false
        }
    }

    private var helperBannerActionLabel: String {
        if state.helperState == .requiresApproval { return "Approve…" }
        return helperBannerIsTerminal ? "Open Setup…" : "Set Up…"
    }

    private var helperBannerMessage: String {
        switch state.helperState {
        case .notInstalled:
            "Install the privileged helper once to enable verified keep-awake requests."
        case .requiresApproval:
            "Approve Lidless in Login Items & Extensions to finish setup."
        case .notResponding:
            "The helper is not responding, so the system sleep state is unverified."
        case .unknown:
            "The helper could not be classified, so its status is unverified."
        case .stale:
            "This helper requires a separately reviewed removal procedure. Public replacement is disabled."
        default:
            "Helper setup is required."
        }
    }

    // MARK: Proof summary

    private var statusSummary: some View {
        VStack(alignment: .leading, spacing: Theme.s2) {
            StatusPill(presentation: presentation)

            Text(headline)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if let detail {
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Label(proofText, systemImage: proofSymbol)
                .font(.caption)
                .foregroundStyle(proofTint)
                .fixedSize(horizontal: false, vertical: true)

            if presentation == .verifiedArmed,
               let cutoffText {
                Label(cutoffText, systemImage: "clock")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(Theme.textPrimary)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        if let scenario = renderScenario { return scenario.cutoffText }
        guard let projected = state.projectedCutoff else { return nil }
        return "\(Format.duration(projected.date.timeIntervalSince(state.now))) · \(projected.label)"
    }

    private var proofText: String {
        if let renderScenario { return renderScenario.proof }
        return switch presentation {
        case .verifiedNormal:
            "Registry proof confirms the system override is off"
        case .verifyingArm:
            "Waiting for helper ownership and registry proof"
        case .verifiedArmed:
            "Helper ownership and the registry override are verified"
        case .restoring:
            "Normal sleep has not been re-verified yet"
        case .outsideOverride:
            "The registry override has no verified Lidless owner"
        case .unknown:
            "No current registry proof is available"
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

    // MARK: One action or confirmation

    private var hasConfirmation: Bool {
        renderScenario?.confirmation != nil || state.pendingArm != nil
    }

    @ViewBuilder
    private var confirmationRegion: some View {
        if let confirmation = renderScenario?.confirmation {
            RenderArmConfirmationCard(confirmation: confirmation)
        } else if let pending = state.pendingArm {
            ArmConfirmCard(pending: pending)
        }
    }

    @ViewBuilder
    private var primaryAction: some View {
        if renderScenario != nil,
           presentation == .verifyingArm || presentation == .restoring {
            Button(action: {}) {
                Label(
                    presentation == .verifyingArm ? "Verifying…" : "Restoring…",
                    systemImage: "hourglass"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(Theme.surfaceElevated)
            .disabled(true)
        } else {
            PrimaryActionButton(
                presentation: presentation,
                actionAvailable: primaryActionAvailable,
                keepAwake: beginKeepAwake,
                restoreNormalSleep: restoreNormalSleep,
                checkAgain: checkAgain
            )
        }
    }

    private var primaryActionAvailable: Bool {
        if let renderScenario { return renderScenario.primaryActionAvailable }
        return switch presentation {
        case .verifiedNormal:
            liveActionTruth.actionAvailable
                && state.helperState.isUsable
                && !state.sessionEvidenceRequiresReconciliation
                && state.pendingArm == nil
        case .verifiedArmed:
            liveActionTruth.armed && liveActionTruth.actionAvailable
        case .outsideOverride:
            state.phase == .disarmed && state.pendingArm == nil
        case .unknown:
            true
        case .verifyingArm, .restoring:
            false
        }
    }

    private var liveActionTruth: LiveActionTruth {
        LiveActionTruth(
            armed: state.sleepPresentation == .verifiedArmed,
            actionAvailable: state.phase == .armed
                || state.sleepPresentation == .verifiedNormal
        )
    }

    private func beginKeepAwake() {
        guard renderScenario == nil else { return }
        performLivePrimaryAction(expected: .keepAwake)
    }

    private func restoreNormalSleep() {
        guard renderScenario == nil else { return }
        performLivePrimaryAction(expected: .restoreNormalSleep)
    }

    private func checkAgain() {
        guard renderScenario == nil else { return }
        performLivePrimaryAction(expected: .checkAgain)
    }

    private func performLivePrimaryAction(expected: PrimaryActionSemantic) {
        guard state.sleepPresentation.primaryActionSemantic == expected else { return }
        if state.sleepPresentation == .outsideOverride {
            Task { await state.repairOverride() }
        } else if state.sleepPresentation == .verifiedNormal {
            state.beginArmFlow()
        } else if state.sleepPresentation == .verifiedArmed {
            Task { await state.disarm() }
        } else if state.sleepPresentation == .unknown {
            Task { await state.refreshHelperState() }
        } else {
            return
        }
    }

    // MARK: Presets and restrained metrics

    private var presetRow: some View {
        HStack(spacing: Theme.s2) {
            PresetChip(title: "Until 7 AM", systemImage: "sunrise") {
                guard renderScenario == nil else { return }
                state.beginArmFlow(preset: .untilMorning)
            }
            PresetChip(title: "4 hours", systemImage: "timer") {
                guard renderScenario == nil else { return }
                state.beginArmFlow(preset: .nextFourHours)
            }
            PresetChip(title: "To 20%", systemImage: "battery.25percent") {
                guard renderScenario == nil else { return }
                state.beginArmFlow(preset: .untilTwentyPercent)
            }
            .disabled(state.battery.state == .noBattery || renderScenario?.primaryActionAvailable == false)
            .help(state.battery.state == .noBattery
                ? "This Mac has no internal battery."
                : "Keep awake until the internal battery reaches 20%.")
        }
        .frame(maxWidth: .infinity)
        .disabled(
            renderScenario?.primaryActionAvailable == false
                || (renderScenario == nil && !state.helperState.isUsable)
                || (renderScenario == nil && state.sessionEvidenceRequiresReconciliation)
        )
    }

    private var statStrip: some View {
        StatStrip(items: [
            .init(
                icon: renderScenario?.batterySymbol ?? Symbols.battery(
                    percent: state.battery.percent,
                    charging: state.battery.isCharging,
                    state: state.battery.state
                ),
                value: renderScenario?.batteryValue ?? Format.percent(state.battery.percent),
                caption: renderScenario?.batteryCaption ?? liveBatteryCaption,
                lit: false
            ),
            .init(
                icon: "chart.line.downtrend.xyaxis",
                value: renderScenario?.drainValue ?? Format.drain(state.drainPerHour),
                caption: "Drain",
                lit: false
            ),
            .init(
                icon: "thermometer.medium",
                value: renderScenario?.thermalValue ?? state.thermalStatusText,
                caption: renderScenario?.thermalCaption
                    ?? (state.thermalIsElevated ? "Elevated" : "Thermals"),
                tint: renderScenario?.thermalIsElevated == true || state.thermalIsElevated
                    ? Theme.caution
                    : nil
            ),
        ])
    }

    private var liveBatteryCaption: String {
        if state.battery.state == .noBattery { return "No battery" }
        if state.battery.isCharging { return "Charging" }
        return state.battery.state == .ac ? "On power" : "Battery"
    }
}

// MARK: - Deterministic confirmation surface

struct RenderArmConfirmationCard: View {
    let confirmation: InstrumentRenderConfirmation

    private var tint: Color {
        switch confirmation.tone {
        case .normal: Theme.verifiedActive
        case .caution: Theme.caution
        case .critical: Theme.critical
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s3) {
            Label(confirmation.title, systemImage: confirmation.symbol)
                .font(.headline)
                .foregroundStyle(tint)
                .fixedSize(horizontal: false, vertical: true)

            if let message = confirmation.message {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(Array(confirmation.evidence.enumerated()), id: \.offset) { _, row in
                Label(row.text, systemImage: row.symbol)
                    .font(.callout)
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            confirmationButtons
        }
        .padding(Theme.s4)
        .background(
            Theme.surfaceElevated,
            in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .strokeBorder(tint.opacity(0.42), lineWidth: 1)
        )
    }

    private var confirmationButtons: some View {
        HStack {
            Button("Cancel") {}
                .keyboardShortcut(.cancelAction)

            Spacer()

            Button(confirmation.confirmTitle) {}
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(tint)
                .disabled(!confirmation.allowsArm)
        }
    }
}

// MARK: - Live confirmation surface

struct ArmConfirmCard: View {
    let pending: AppState.PendingArm

    @Environment(AppState.self) private var state

    private var refused: Bool { !pending.assessment.allowsArm }

    private var cautionary: Bool {
        if case .lowBatteryWarning = pending.assessment { return true }
        return false
    }

    private var tint: Color {
        if refused { return Theme.critical }
        return cautionary ? Theme.caution : Theme.verifiedActive
    }

    private var safetyEvidenceUnavailable: Bool {
        switch pending.assessment {
        case .refusedBatteryTelemetryUnavailable,
             .refusedThermalTelemetryUnavailable:
            true
        default:
            false
        }
    }

    private var showsBatteryFloor: Bool {
        pending.projection.floorEnabled
            && state.battery.state != .noBattery
            && pending.assessment != .refusedBatteryTelemetryUnavailable
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s3) {
            assessmentHeader

            VStack(alignment: .leading, spacing: Theme.s2) {
                projectionRows
                if !safetyEvidenceUnavailable {
                    row(symbol: "checkmark.shield", text: pending.projection.summary)
                }
            }

            HStack {
                Button("Cancel") {
                    state.cancelArmFlow()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(refused ? "Can't Continue" : "Keep Awake") {
                    Task {
                        await state.confirmArm(expectedIntentID: pending.id)
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(tint)
                .disabled(refused)
            }
        }
        .padding(Theme.s4)
        .background(
            Theme.surfaceElevated,
            in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .strokeBorder(tint.opacity(0.42), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var projectionRows: some View {
        if state.battery.state == .noBattery {
            row(
                symbol: "powerplug",
                text: pending.projection.floorEnabled
                    ? "No internal battery — configured floor is inactive"
                    : "No internal battery"
            )
        } else if let rate = pending.projection.ratePerHour,
                  let empty = pending.projection.timeToEmpty {
            row(
                symbol: "gauge.with.needle",
                text: "About \(Format.duration(empty)) of battery at \(Format.drain(rate))"
            )
        } else if let empty = pending.projection.timeToEmpty {
            row(
                symbol: "gauge.with.needle",
                text: "About \(Format.duration(empty)) of battery from the system estimate"
            )
        } else if state.battery.isDischarging {
            row(symbol: "gauge.with.needle", text: "Measuring drain rate…")
        } else if state.battery.state == .ac {
            row(symbol: "powerplug", text: "On power — battery cutoffs apply if unplugged")
        }

        if showsBatteryFloor {
            if let floorDate = pending.projection.floorDate {
                row(
                    symbol: "battery.25percent",
                    text: "Stops at \(pending.projection.floorPercent)% · about \(Format.clock(floorDate))"
                )
            } else {
                row(
                    symbol: "battery.25percent",
                    text: "Stops if battery reaches \(pending.projection.floorPercent)%"
                )
            }
        }

        if let timeCutoff = pending.projection.firstTimeCutoff {
            row(
                symbol: "clock",
                text: "Normal sleep returns \(Format.dayAndTime(timeCutoff.date))"
            )
        }
    }

    @ViewBuilder
    private var assessmentHeader: some View {
        switch pending.assessment {
        case .refusedThermalPressure(let detail):
            assessmentLabel(
                "Thermal protection is active (\(detail)). Let the Mac cool before continuing.",
                symbol: "thermometer.high"
            )
        case .refusedThermalTelemetryUnavailable:
            assessmentLabel(
                "Thermal state is unavailable, so the configured guard cannot be enforced.",
                symbol: "exclamationmark.triangle.fill"
            )
        case .refusedBatteryTelemetryUnavailable:
            assessmentLabel(
                "Battery state is unavailable, so the configured floor cannot be enforced.",
                symbol: "exclamationmark.triangle.fill"
            )
        case .refusedBelowFloor(let percent, let floor):
            assessmentLabel(
                "Battery is \(percent)% and too close to the \(floor)% safety floor. Charge first or revise the floor in Settings.",
                symbol: "battery.0percent"
            )
        case .lowBatteryWarning(let percent):
            assessmentLabel(
                "Battery is \(percent)%. Review the projection before continuing.",
                symbol: "exclamationmark.triangle.fill"
            )
        case .ok:
            Text(titleForSource)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
        }
    }

    private func assessmentLabel(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.callout.weight(.semibold))
            .foregroundStyle(tint)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var titleForSource: String {
        switch pending.source {
        case .preset(.untilMorning): "Keep awake until 7:00 AM?"
        case .preset(.nextFourHours): "Keep awake for 4 hours?"
        case .preset(.untilTwentyPercent): "Keep awake until 20% battery?"
        default: "Keep this Mac awake with the lid closed?"
        }
    }

    private func row(symbol: String, text: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.callout)
            .foregroundStyle(Theme.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
