import SwiftUI
import LidlessCore

/// The menu bar panel — Lidless's primary UI and its stage. A drifting
/// aurora carries the mood; the eye core carries the state; the numbers
/// glow when the machine is being kept awake. Clarity rules still win:
/// the headline always says exactly what sleep is doing.
struct MenuPanelView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        ZStack {
            AuroraBackground(mood: state.mood)

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, Theme.s4)
                    .padding(.top, Theme.s4)

                banners
                    .padding(.horizontal, Theme.s4)

                powerSection
                    .padding(.top, Theme.s2)
                    .padding(.bottom, Theme.s4)

                Group {
                    if let pending = state.pendingArm {
                        ArmConfirmCard(pending: pending)
                            .transition(.scale(scale: 0.94).combined(with: .opacity))
                    } else if !state.isArmed {
                        presetRow
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, Theme.s4)
                .padding(.bottom, Theme.s2)

                statsGrid
                    .padding(.horizontal, Theme.s4)
                    .padding(.top, Theme.s2)
                    .padding(.bottom, Theme.s4)

                Divider()
                    .overlay(.white.opacity(0.08))

                footer
                    .padding(.horizontal, Theme.s4)
                    .padding(.vertical, Theme.s3)
            }
        }
        .frame(width: Theme.panelWidth)
        .fontDesign(.rounded)
        .preferredColorScheme(.dark)
        .animation(Theme.springGentle, value: state.pendingArm)
        .animation(Theme.springGentle, value: state.phase)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: Theme.s2) {
            Image(systemName: state.isArmed ? "eye" : "eye.slash")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(state.isArmed ? AnyShapeStyle(Theme.armedGradient) : AnyShapeStyle(.white.opacity(0.4)))
                .glow(state.isArmed ? Theme.cyan : .clear, radius: 6, opacity: 0.6)
            Text("Lidless")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.9))
            if state.isSimulation {
                Text("SIM")
                    .font(.caption2.weight(.bold))
                    .kerning(0.6)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.violet.opacity(0.25), in: Capsule())
                    .foregroundStyle(Theme.violet)
            }
            Spacer()
            StatusPill(phase: state.phase)
        }
    }

    @ViewBuilder
    private var banners: some View {
        if state.overrideLeaked {
            Banner(
                kind: .warning,
                message: "Sleep is disabled system-wide, outside of Lidless."
            ) {
                Button("Fix") {
                    Task { await state.repairOverride() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.top, Theme.s2)
        }
        if let error = state.lastError {
            Banner(kind: .error, message: error) {
                Button {
                    state.lastError = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.top, Theme.s2)
        }
        if !state.helperState.isUsable, state.helperState != .unknown, !state.isArmed {
            Banner(
                kind: .info,
                message: helperBannerMessage
            ) {
                Button(state.helperState == .requiresApproval ? "Approve…" : "Set Up…") {
                    if state.helperState == .requiresApproval {
                        state.openApprovalSettings()
                    } else {
                        state.requestMainWindow(pane: .setup)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.top, Theme.s2)
        }
    }

    private var helperBannerMessage: String {
        switch state.helperState {
        case .notInstalled: "One-time setup: install the privileged helper to enable keep-awake."
        case .requiresApproval: "Almost there — approve Lidless in Login Items & Extensions."
        case .notResponding: "The helper isn't responding."
        default: "Helper setup needed."
        }
    }

    // MARK: - Power

    private var powerSection: some View {
        VStack(spacing: Theme.s2) {
            PowerButton(
                armed: state.isArmed,
                busy: state.phase == .arming || state.phase == .disarming,
                mood: state.mood
            ) {
                if state.isArmed {
                    Task { await state.disarm() }
                } else if state.pendingArm != nil {
                    state.cancelArmFlow()
                } else {
                    state.beginArmFlow()
                }
            }

            VStack(spacing: Theme.s1) {
                if state.isArmed {
                    GlowText(
                        text: state.statusHeadline,
                        font: .title3.weight(.semibold),
                        gradient: Theme.armedGradient,
                        glowColor: Theme.cyan,
                        glowRadius: 10
                    )
                } else {
                    Text(state.statusHeadline)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(state.overrideLeaked ? AnyShapeStyle(Theme.ember) : AnyShapeStyle(.white.opacity(0.92)))
                }

                if state.isArmed, let projected = state.projectedCutoff {
                    VStack(spacing: 0) {
                        GlowText(
                            text: Format.duration(projected.date.timeIntervalSince(state.now)),
                            font: .system(size: 34, weight: .bold, design: .rounded),
                            gradient: Theme.armedGradient,
                            glowColor: Theme.cyan,
                            glowRadius: 14
                        )
                        Text(projected.label)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .padding(.top, Theme.s1)
                } else if let detail = state.statusDetail {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                }

                if state.isArmed, state.lidClosed {
                    Label("Lid closed — keeping watch", systemImage: "laptopcomputer")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.35))
                        .padding(.top, 2)
                }
            }
            .padding(.horizontal, Theme.s4)
        }
    }

    // MARK: - Presets

    private var presetRow: some View {
        HStack(spacing: Theme.s2) {
            PresetChip(title: "Until 7 AM", systemImage: "sunrise") {
                state.beginArmFlow(preset: .untilMorning)
            }
            PresetChip(title: "4 hours", systemImage: "timer") {
                state.beginArmFlow(preset: .nextFourHours)
            }
            PresetChip(title: "To 20%", systemImage: "battery.25percent") {
                state.beginArmFlow(preset: .untilTwentyPercent)
            }
        }
        .frame(maxWidth: .infinity)
        .disabled(!state.helperState.isUsable)
        .opacity(state.helperState.isUsable ? 1 : 0.4)
    }

    // MARK: - Stats

    private var statsGrid: some View {
        Grid(horizontalSpacing: Theme.s2, verticalSpacing: Theme.s2) {
            GridRow {
                StatCell(
                    title: "Battery",
                    systemImage: Symbols.battery(percent: state.battery.percent, charging: state.battery.isCharging),
                    value: Format.percent(state.battery.percent),
                    detail: state.battery.isCharging
                        ? "Charging"
                        : (state.battery.state == .ac ? "On power" : "On battery"),
                    lit: state.isArmed
                )
                StatCell(
                    title: "Drain",
                    systemImage: "chart.line.downtrend.xyaxis",
                    value: Format.drain(state.drainPerHour),
                    detail: state.battery.isDischarging ? "Current rate" : "Not discharging",
                    lit: state.isArmed
                )
            }
            GridRow {
                StatCell(
                    title: "Cutoff",
                    systemImage: "moon.zzz",
                    value: cutoffValue,
                    detail: cutoffDetail,
                    lit: state.isArmed
                )
                StatCell(
                    title: "Thermals",
                    systemImage: "thermometer.medium",
                    value: state.thermalStatusText,
                    detail: state.thermalIsElevated ? "Elevated" : nil,
                    tint: state.thermalIsElevated ? Theme.ember : .secondary
                )
            }
        }
    }

    private var cutoffValue: String {
        guard state.isArmed else { return "—" }
        if let projected = state.projectedCutoff {
            return Format.duration(projected.date.timeIntervalSince(state.now))
        }
        if state.effectiveConfig.batteryFloorEnabled {
            return "At \(state.effectiveConfig.batteryFloorPercent)%"
        }
        return "None"
    }

    private var cutoffDetail: String? {
        guard state.isArmed else { return "—" }
        if let projected = state.projectedCutoff {
            return projected.label
        }
        if state.effectiveConfig.batteryFloorEnabled {
            return "Battery floor armed"
        }
        return "Disarm manually"
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: Theme.s4) {
            FooterButton(title: "History", systemImage: "clock.arrow.circlepath") {
                state.requestMainWindow(pane: .history)
            }
            FooterButton(title: "Settings", systemImage: "gearshape") {
                state.requestMainWindow(pane: .cutoffs)
            }
            Spacer()
            FooterButton(title: "Quit", systemImage: "xmark.circle") {
                NSApp.terminate(nil)
            }
        }
    }
}

// MARK: - Arm confirmation card

/// Safety UX in one card: what will keep the Mac awake, what will stop it,
/// projected runtime at the current drain rate, and explicit low-battery
/// warning / floor refusal states.
struct ArmConfirmCard: View {
    let pending: AppState.PendingArm

    @Environment(AppState.self) private var state

    private var refused: Bool {
        if case .refusedBelowFloor = pending.assessment { return true }
        return false
    }

    private var warningTint: Bool {
        if case .lowBatteryWarning = pending.assessment { return true }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s3) {
            assessmentHeader

            VStack(alignment: .leading, spacing: Theme.s2) {
                if let rate = pending.projection.ratePerHour, let empty = pending.projection.timeToEmpty {
                    row(
                        symbol: "gauge.with.needle",
                        text: "≈ \(Format.duration(empty)) of battery at \(Format.drain(rate))"
                    )
                } else if let empty = pending.projection.timeToEmpty {
                    row(
                        symbol: "gauge.with.needle",
                        text: "≈ \(Format.duration(empty)) of battery (system estimate)"
                    )
                } else if state.battery.isDischarging {
                    row(symbol: "gauge.with.needle", text: "Measuring drain rate…")
                } else if state.battery.state == .ac {
                    row(symbol: "powerplug", text: "On power — battery cutoffs apply if unplugged")
                }

                if pending.projection.floorEnabled {
                    if let floorDate = pending.projection.floorDate {
                        row(
                            symbol: "battery.25percent",
                            text: "Stops at \(pending.projection.floorPercent)% · ~\(Format.clock(floorDate))"
                        )
                    } else {
                        row(
                            symbol: "battery.25percent",
                            text: "Stops if battery hits \(pending.projection.floorPercent)%"
                        )
                    }
                }

                if let timeCutoff = pending.projection.firstTimeCutoff {
                    row(
                        symbol: "clock",
                        text: "Sleeps \(Format.dayAndTime(timeCutoff.date))"
                    )
                }

                row(symbol: "checkmark.shield", text: pending.projection.summary)
            }

            HStack {
                Button("Cancel") {
                    state.cancelArmFlow()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(refused ? "Can't Arm" : "Keep Awake") {
                    Task { await state.confirmArm() }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(warningTint || refused ? Theme.ember : Theme.armedDeep)
                .disabled(refused)
            }
        }
        .padding(Theme.s4)
        .card(tint: warningTint || refused ? Theme.ember : .white)
        .glow(warningTint || refused ? Theme.ember : Theme.armedDeep, radius: 18, opacity: 0.18)
    }

    @ViewBuilder
    private var assessmentHeader: some View {
        switch pending.assessment {
        case .refusedBelowFloor(let percent, let floor):
            Label(
                percent <= floor
                    ? "Battery at \(percent)% — already at the \(floor)% cutoff floor. Charge first, or lower the floor in Settings."
                    : "Battery at \(percent)% — within the safety margin of the \(floor)% floor. Charge first, or lower the floor in Settings.",
                systemImage: "battery.0percent"
            )
            .font(.callout.weight(.medium))
            .foregroundStyle(Color(red: 1.0, green: 0.42, blue: 0.38))
        case .lowBatteryWarning(let percent):
            Label(
                "Battery at \(percent)%. Keeping the Mac awake will drain it further — check the projection below.",
                systemImage: "exclamationmark.triangle.fill"
            )
            .font(.callout.weight(.medium))
            .foregroundStyle(Theme.ember)
        case .ok:
            Text(titleForSource)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white.opacity(0.92))
        }
    }

    private var titleForSource: String {
        switch pending.source {
        case .preset(.untilMorning): "Keep awake until 7:00 AM?"
        case .preset(.nextFourHours): "Keep awake for 4 hours?"
        case .preset(.untilTwentyPercent): "Keep awake until 20% battery?"
        default: "Keep your Mac awake with the lid closed?"
        }
    }

    private func row(symbol: String, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.s2) {
            Image(systemName: symbol)
                .frame(width: 18)
                .foregroundStyle(.white.opacity(0.45))
            Text(text)
                .font(.callout)
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
