import AppKit
import Foundation
import LidlessCore
import ServiceManagement

/// Single source of truth. Owns the arm/disarm state machine, evaluates the
/// cutoff engine against live telemetry, records sessions, runs schedule
/// automation, and keeps helper, widget, and notifications in sync.
///
/// Policy lives here; the pure decisions live in LidlessCore; the privileged
/// actuation lives in the helper.
@MainActor
@Observable
final class AppState {

    // MARK: - Dependencies

    let config: ConfigStore
    let sessionStore: SessionStore
    let notifications: NotificationService
    let simulation: SimulationController?

    private let helper: any HelperControlling
    private let batteryMonitor: any BatteryMonitoring
    private let thermalMonitor: any ThermalMonitoring
    private let systemMonitor: SystemStateMonitor?
    private let widgetPublisher = WidgetPublisher()

    var isSimulation: Bool { simulation != nil }

    // MARK: - Live telemetry

    private(set) var battery: BatterySnapshot = .unknown(at: Date())
    private(set) var thermal: ThermalReading?
    private(set) var processThermal: ProcessThermalLevel = .nominal
    private(set) var lidClosed = false
    private(set) var hasLid = true
    /// Actual system-wide `disablesleep` state (verified, not believed).
    private(set) var overrideActive = false
    private(set) var drainPerHour: Double?
    private(set) var rollingSamples: [BatterySample] = []

    /// Ticked by the 15s loop so time-derived computed properties refresh.
    private(set) var now = Date()

    var helperState: HelperInstallState { helper.installState }

    // MARK: - Session state machine

    enum Phase: Equatable {
        case disarmed, arming, armed, disarming
    }

    private(set) var phase: Phase = .disarmed
    private(set) var currentSession: KeepAwakeSession?
    private(set) var sessionOverrides: SessionOverrides?
    private(set) var nextTimeCutoff: PlannedCutoff?
    private(set) var lastEndedSession: KeepAwakeSession?
    var lastError: String?

    private var scheduleOccurrence: ScheduleEngine.Occurrence?
    private var suppressedOccurrence: ScheduleEngine.Occurrence?
    private var thermalStrikes = 0
    private var lastThermalStrikeStamp: Date?
    private var nextStrikeAllowedAt = Date.distantPast
    private var warnedKinds: Set<String> = []
    private var lastSessionSampleAt = Date.distantPast
    /// Three-state reconciliation cache for the helper's RTC wake:
    /// .none = helper state unknown (always reconcile), .some(nil) = known
    /// cancelled, .some(date) = known set. Starts unknown so launch always
    /// reconciles against whatever a previous run left registered.
    private var lastScheduledWakeSent: Date??
    /// Most recent sleep/wake transition signal, used to distinguish "helper
    /// lost the session because the system slept" from "helper crashed".
    private var lastSleepSignal = Date.distantPast

    private var tickTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?

    /// Incremented to ask the menu-bar bridge to open the main window.
    private(set) var mainWindowRequestToken = 0

    enum MainPane: String, CaseIterable, Identifiable {
        case overview, cutoffs, schedules, history, setup, simulator
        var id: String { rawValue }
    }

    var mainPane: MainPane = .overview

    // MARK: - Arm flow

    struct ArmProjection: Equatable {
        var ratePerHour: Double?
        var floorEnabled: Bool
        var floorPercent: Int
        var floorDate: Date?
        var timeToEmpty: TimeInterval?
        var firstTimeCutoff: PlannedCutoff?
        var summary: String
    }

    struct PendingArm: Equatable {
        var overrides: SessionOverrides?
        var source: SessionSource
        var assessment: ArmAssessment
        var projection: ArmProjection
        var createdAt: Date
    }

    private(set) var pendingArm: PendingArm?

    // MARK: - Init

    static func bootstrap() -> AppState {
        let arguments = CommandLine.arguments
        let simulate = arguments.contains("--simulate")
            || arguments.contains("--render-screenshots")
            || ProcessInfo.processInfo.environment["LIDLESS_SIMULATE"] == "1"
        return AppState(simulated: simulate)
    }

    init(simulated: Bool) {
        let config = ConfigStore(ephemeral: simulated)
        self.config = config
        self.sessionStore = SessionStore(ephemeral: simulated)
        self.notifications = NotificationService()

        if simulated {
            let controller = SimulationController()
            self.simulation = controller
            self.helper = SimulatedHelper(controller: controller)
            self.batteryMonitor = SimulatedBatteryMonitor(controller: controller)
            self.thermalMonitor = SimulatedThermalMonitor(controller: controller)
            self.systemMonitor = nil
        } else {
            self.simulation = nil
            self.helper = HelperClient()
            self.batteryMonitor = IOPSBatteryMonitor()
            self.thermalMonitor = PMSetThermalMonitor()
            self.systemMonitor = SystemStateMonitor()
        }

        wire()
    }

    private func wire() {
        batteryMonitor.onChange = { [weak self] snapshot in
            self?.batteryDidChange(snapshot)
        }
        thermalMonitor.onChange = { [weak self] in
            self?.thermalDidChange()
        }
        helper.onInterruption = { [weak self] in
            self?.helperInterrupted()
        }
        systemMonitor?.onWake = { [weak self] in
            self?.lastSleepSignal = Date()
            self?.resyncAfterWake()
        }
        systemMonitor?.onWillSleep = { [weak self] in
            self?.lastSleepSignal = Date()
        }
        systemMonitor?.onChange = { [weak self] in
            self?.systemStateDidChange()
        }
    }

    func start() {
        notifications.activate()
        batteryMonitor.start()
        thermalMonitor.start()
        systemMonitor?.start()
        battery = batteryMonitor.current
        refreshSystemFlags()

        Task {
            await helper.refreshInstallState()
            await reconcileWithHelper()
        }

        startTickLoop()
    }

    // MARK: - Derived state for UI

    var isArmed: Bool { phase == .armed || phase == .disarming }

    var effectiveConfig: CutoffConfig { config.cutoffs.applying(sessionOverrides) }

    /// The override is on but no Lidless session explains it — either another
    /// tool set it, or a restore failed. Never let this be invisible.
    var overrideLeaked: Bool { overrideActive && phase == .disarmed }

    var statusHeadline: String {
        switch phase {
        case .disarmed: overrideLeaked ? "Sleep is disabled" : "Sleeping normally"
        case .arming: "Arming…"
        case .armed: "Staying awake"
        case .disarming: "Restoring sleep…"
        }
    }

    var statusDetail: String? {
        switch phase {
        case .armed:
            if let projected = projectedCutoff {
                return "\(projected.label) · \(Format.countdown(to: projected.date, from: now))"
            }
            // No projected end date yet, but safety guards may still be
            // armed (floor/thermal) — never imply they aren't.
            if let summary = currentSession?.cutoffSummary, summary != "No cutoffs" {
                return summary
            }
            return "No automatic cutoff — disarm manually"
        case .arming, .disarming:
            return nil
        case .disarmed:
            if overrideLeaked {
                return "Sleep override is active outside Lidless"
            }
            if !helperState.isUsable, helperState != .unknown {
                return "Helper setup needed"
            }
            return nextScheduleDescription
        }
    }

    /// Earliest projected end of the current session: a planned time cutoff
    /// or the battery-floor projection, whichever comes first.
    var projectedCutoff: (date: Date, label: String)? {
        guard isArmed else { return nil }
        var candidates: [(Date, String)] = []
        if let planned = nextTimeCutoff {
            switch planned.kind {
            case .offTime: candidates.append((planned.date, "Until \(Format.clock(planned.date))"))
            case .duration: candidates.append((planned.date, "Until \(Format.clock(planned.date))"))
            case .scheduleEnd: candidates.append((planned.date, "Scheduled until \(Format.clock(planned.date))"))
            }
        }
        if let occurrence = scheduleOccurrence {
            candidates.append((occurrence.end, "Scheduled until \(Format.clock(occurrence.end))"))
        }
        let cfg = effectiveConfig
        if cfg.batteryFloorEnabled,
           battery.isDischarging,
           let percent = battery.percent,
           let rate = drainPerHour,
           let date = DrainEstimator.projectedDate(
               targetPercent: Double(cfg.batteryFloorPercent),
               from: Double(percent),
               ratePerHour: rate,
               now: now
           ) {
            candidates.append((date, "Until battery hits \(cfg.batteryFloorPercent)%"))
        }
        guard let earliest = candidates.min(by: { $0.0 < $1.0 }) else { return nil }
        return (earliest.0, earliest.1)
    }

    var armedElapsed: TimeInterval? {
        guard let currentSession, isArmed else { return nil }
        return now.timeIntervalSince(currentSession.startedAt)
    }

    var menuBarSystemImage: String {
        if isArmed { return "eye.fill" }
        if overrideLeaked { return "eye.trianglebadge.exclamationmark" }
        return "eye.slash"
    }

    var menuBarText: String? {
        guard config.behavior.countdownInMenuBar,
              isArmed,
              let projected = projectedCutoff,
              projected.date.timeIntervalSince(now) < 24 * 3600
        else { return nil }
        return Format.duration(projected.date.timeIntervalSince(now))
    }

    var nextScheduleDescription: String? {
        guard config.scheduleAutomationEnabled,
              let next = ScheduleEngine.nextStart(windows: config.schedules, after: now, calendar: .current)
        else { return nil }
        return "Scheduled: \(Format.dayAndTime(next.start))"
    }

    func cutoffSummary(for cfg: CutoffConfig, armedAt: Date) -> String {
        var parts: [String] = []
        if cfg.batteryFloorEnabled { parts.append("Floor \(cfg.batteryFloorPercent)%") }
        if cfg.thermalEnabled { parts.append("Thermal guard") }
        for planned in CutoffEngine.plannedCutoffs(config: cfg, armedAt: armedAt, calendar: .current) {
            switch planned.kind {
            case .duration: parts.append("For \(Format.duration(cfg.durationSeconds))")
            case .offTime: parts.append("Until \(Format.clock(cfg.offTime))")
            case .scheduleEnd: break
            }
        }
        return parts.isEmpty ? "No cutoffs" : parts.joined(separator: " · ")
    }

    // MARK: - Arm flow intents

    func beginArmFlow(preset: ArmPreset? = nil) {
        guard phase == .disarmed else { return }
        lastError = nil

        guard helperState.isUsable else {
            requestMainWindow()
            return
        }

        let overrides = preset?.overrides()
        let source: SessionSource = preset.map { .preset($0) } ?? .manual
        let assessment = CutoffEngine.assessArm(
            config: config.cutoffs.applying(overrides),
            battery: battery
        )
        let pending = PendingArm(
            overrides: overrides,
            source: source,
            assessment: assessment,
            projection: projection(for: overrides),
            createdAt: Date()
        )
        pendingArm = pending

        // Presets are explicit intent — skip the confirm card when there's
        // nothing to warn about. The master control always shows the card.
        if preset != nil, assessment == .ok {
            Task { await confirmArm() }
        }
    }

    func cancelArmFlow() {
        pendingArm = nil
    }

    func refreshPendingProjection() {
        guard let pending = pendingArm else { return }
        pendingArm = PendingArm(
            overrides: pending.overrides,
            source: pending.source,
            assessment: CutoffEngine.assessArm(
                config: config.cutoffs.applying(pending.overrides),
                battery: battery
            ),
            projection: projection(for: pending.overrides),
            createdAt: pending.createdAt
        )
    }

    private func projection(for overrides: SessionOverrides?) -> ArmProjection {
        let cfg = config.cutoffs.applying(overrides)
        let reference = Date()
        var floorDate: Date?
        var timeToEmpty: TimeInterval?

        if let percent = battery.percent, battery.isDischarging, let rate = drainPerHour, rate > 0 {
            floorDate = DrainEstimator.projectedDate(
                targetPercent: Double(cfg.batteryFloorPercent),
                from: Double(percent),
                ratePerHour: rate,
                now: reference
            )
            timeToEmpty = DrainEstimator.timeToReach(
                targetPercent: 0,
                from: Double(percent),
                ratePerHour: rate
            )
        } else if let minutes = battery.timeToEmptyMinutes, battery.isDischarging {
            timeToEmpty = TimeInterval(minutes * 60)
        }

        return ArmProjection(
            // A clamped-to-zero rate must not label the OS estimate as a
            // measured "0.0%/hr" projection.
            ratePerHour: (drainPerHour ?? 0) > 0 ? drainPerHour : nil,
            floorEnabled: cfg.batteryFloorEnabled,
            floorPercent: cfg.batteryFloorPercent,
            floorDate: floorDate,
            timeToEmpty: timeToEmpty,
            firstTimeCutoff: CutoffEngine.plannedCutoffs(config: cfg, armedAt: reference, calendar: .current).first,
            summary: cutoffSummary(for: cfg, armedAt: reference)
        )
    }

    func confirmArm() async {
        guard let pending = pendingArm, phase == .disarmed else { return }
        if case .refusedBelowFloor = pending.assessment { return }

        phase = .arming
        await notifications.requestAuthorizationIfNeeded()

        let options = HelperArmOptions(
            lowPowerMode: config.behavior.lowPowerModeWhileArmed,
            tcpKeepAlive: config.behavior.tcpKeepAliveWhileArmed
        )

        do {
            let reply = try await helper.arm(options)
            guard reply.ok else {
                throw NSError(domain: "Lidless", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: reply.error ?? "The helper refused to arm.",
                ])
            }

            let startedAt = Date()
            let cfg = config.cutoffs.applying(pending.overrides)
            var session = KeepAwakeSession(
                startedAt: startedAt,
                source: pending.source,
                startPercent: battery.percent,
                cutoffSummary: cutoffSummary(for: cfg, armedAt: startedAt),
                lowPowerModeUsed: options.lowPowerMode,
                tcpKeepAliveUsed: options.tcpKeepAlive
            )
            if let percent = battery.percent {
                session.samples.append(BatterySample(
                    time: startedAt,
                    percent: Double(percent),
                    isDischarging: battery.isDischarging
                ))
            }

            currentSession = session
            sessionOverrides = pending.overrides
            pendingArm = nil
            phase = .armed
            thermalStrikes = 0
            lastThermalStrikeStamp = nil
            nextStrikeAllowedAt = .distantPast
            warnedKinds = []
            lastSessionSampleAt = startedAt
            lastError = nil

            if case .schedule = pending.source {
                // scheduleOccurrence set by the automation path before calling.
            } else {
                scheduleOccurrence = nil
            }

            sessionStore.checkpoint(session)
            startHeartbeat()
            refreshSystemFlags()
            evaluateCutoffs()

            if config.behavior.notifyOnStateChanges {
                notifications.post(
                    title: "Keeping your Mac awake",
                    body: session.cutoffSummary
                )
            }
            publishWidget()
        } catch {
            phase = .disarmed
            pendingArm = nil
            lastError = "Couldn't arm: \(error.localizedDescription)"
            await helper.refreshInstallState()
        }
    }

    /// The always-available "Disarm & restore normal sleep".
    func disarm() async {
        pendingArm = nil
        guard phase == .armed else { return }
        phase = .disarming

        do {
            let reply = try await helper.disarm(HelperDisarmOptions(forceSleep: false, reason: "manual disarm"))
            if !reply.ok { lastError = reply.error }
        } catch {
            lastError = "Disarm failed: \(error.localizedDescription) — the helper watchdog will restore sleep within \(Int(HelperArmOptions.defaultWatchdogTTL))s"
        }

        finalizeSession(endReason: .manual)
        if config.behavior.notifyOnStateChanges {
            notifications.post(title: "Normal sleep restored", body: "Lidless is disarmed.")
        }
        phase = .disarmed
        refreshSystemFlags()
        publishWidget()
    }

    func disarmForQuit() async {
        guard phase == .armed else { return }
        phase = .disarming
        _ = try? await helper.disarm(HelperDisarmOptions(forceSleep: false, reason: "app quit"))
        finalizeSession(endReason: .appQuit)
        phase = .disarmed
        publishWidget()
    }

    private func fireCutoff(reasons: [CutoffReason]) async {
        guard phase == .armed, let primary = reasons.first else { return }
        phase = .disarming

        let sleepAfter = config.behavior.sleepOnCutoff && lidClosed
        let label = cutoffLabel(primary)

        do {
            let reply = try await helper.disarm(HelperDisarmOptions(forceSleep: sleepAfter, reason: label))
            if !reply.ok { lastError = reply.error }
        } catch {
            lastError = "Cutoff restore failed: \(error.localizedDescription) — helper watchdog is the backstop"
        }

        finalizeSession(endReason: .cutoff(primary))

        if config.behavior.notifyOnStateChanges {
            notifications.post(
                title: sleepAfter ? "Going to sleep" : "Keep-awake ended",
                body: label,
                sound: config.behavior.playCutoffSound
            )
        }
        if config.behavior.playCutoffSound {
            notifications.playCutoffChime()
        }

        phase = .disarmed
        refreshSystemFlags()
        publishWidget()
    }

    private func finalizeSession(endReason: SessionEndReason) {
        stopHeartbeat()
        nextTimeCutoff = nil
        scheduleOccurrence = nil

        guard var session = currentSession else { return }
        let endedAt = Date()
        session.endedAt = endedAt
        session.endReason = endReason
        session.endPercent = battery.percent
        if let percent = battery.percent {
            session.samples.append(BatterySample(
                time: endedAt,
                percent: Double(percent),
                isDischarging: battery.isDischarging
            ))
        }
        sessionStore.append(session)
        lastEndedSession = session
        currentSession = nil
        sessionOverrides = nil

        // Any session end inside an active window suppresses that occurrence:
        // automation must never flap-rearm into the condition that just ended
        // a session (a hot machine would loop arm → thermal cutoff → chime)
        // or against explicit intent (manual disarm, forced sleep).
        if config.scheduleAutomationEnabled,
           let active = ScheduleEngine.activeOccurrence(windows: config.schedules, at: endedAt, calendar: .current) {
            suppressedOccurrence = active
        }

        // Recompute the RTC wake for the *next* window rather than blanket-
        // cancelling: ending tonight's session must not lose tomorrow's wake.
        lastScheduledWakeSent = .none
        maintainScheduledWake()
    }

    func cutoffLabel(_ reason: CutoffReason) -> String {
        switch reason {
        case .thermal(let detail): "Thermal protection: \(detail)"
        case .batteryFloor(let percent, let floor): "Battery reached \(percent)% (floor \(floor)%)"
        case .offTime: "Reached the scheduled off-time"
        case .durationElapsed: "Duration limit reached"
        case .scheduleEnded: "Scheduled window ended"
        }
    }

    // MARK: - Repair / uninstall

    func repairOverride() async {
        do {
            let reply = try await helper.repairOverride()
            if !reply.ok { lastError = reply.error }
        } catch {
            lastError = "Repair failed: \(error.localizedDescription)"
        }
        refreshSystemFlags()
        publishWidget()
    }

    func installHelper() async {
        do {
            try await helper.install()
        } catch {
            lastError = "Helper install failed: \(error.localizedDescription)"
        }
        await helper.refreshInstallState()
    }

    func refreshHelperState() async {
        await helper.refreshInstallState()
    }

    func openApprovalSettings() {
        helper.openApprovalSettings()
    }

    /// Full uninstall: restore pmset state, remove helper + its data,
    /// deregister the daemon, drop login item, delete app data.
    /// Returns an error message, or nil on success.
    func uninstall() async -> String? {
        if phase == .armed {
            await disarm()
        }
        do {
            try await helper.uninstall()
        } catch {
            return "Could not remove the helper: \(error.localizedDescription)"
        }
        setLaunchAtLogin(false)
        ConfigStore.deleteAllData()
        notifications.post(
            title: "Lidless uninstalled",
            body: "Normal sleep restored. Drag Lidless.app to the Trash to finish."
        )
        return nil
    }

    // MARK: - Login item

    var launchAtLogin: Bool {
        guard !isSimulation else { return false }
        return SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        guard !isSimulation else { return }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            lastError = "Login item change failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Event handlers

    private func batteryDidChange(_ snapshot: BatterySnapshot) {
        battery = snapshot
        appendRollingSample(snapshot)
        recomputeDrain()
        refreshSystemFlags()
        refreshPendingProjection()
        if phase == .armed {
            recordSessionSampleIfDue(force: true)
            evaluateCutoffs()
        }
        publishWidget()
    }

    private func thermalDidChange() {
        thermal = thermalMonitor.reading
        processThermal = thermalMonitor.processLevel
        if phase == .armed {
            evaluateCutoffs()
        }
    }

    private func systemStateDidChange() {
        refreshSystemFlags()
        publishWidget()
    }

    private func helperInterrupted() {
        guard phase == .armed else { return }
        // Helper crashed or was upgraded; its relaunch restored normal sleep
        // (fail-safe). Re-arm to continue the session with a logged blip.
        Task { await rearmAfterHelperRestart() }
    }

    private func rearmAfterHelperRestart() async {
        guard phase == .armed else { return }

        // If the system just slept or woke, the helper releasing the session
        // means FORCED SLEEP, not a crash — honor it. Re-arming here would
        // re-enable the override against the user's explicit intent (or arm
        // a helper whose supervising app is about to be frozen).
        if Date().timeIntervalSince(lastSleepSignal) < 60 {
            finalizeSession(endReason: .systemSlept)
            phase = .disarmed
            if config.behavior.notifyOnStateChanges {
                notifications.post(
                    title: "Keep-awake ended",
                    body: "Your Mac was put to sleep, so Lidless restored normal behavior."
                )
            }
            publishWidget()
            return
        }

        let options = HelperArmOptions(
            lowPowerMode: config.behavior.lowPowerModeWhileArmed,
            tcpKeepAlive: config.behavior.tcpKeepAliveWhileArmed
        )
        do {
            let reply = try await helper.arm(options)
            guard reply.ok else { throw NSError(domain: "Lidless", code: 2) }
            lastError = nil
        } catch {
            finalizeSession(endReason: .helperRestored)
            phase = .disarmed
            notifications.post(
                title: "Keep-awake ended",
                body: "The helper restarted and normal sleep was restored.",
                sound: config.behavior.playCutoffSound
            )
            publishWidget()
        }
    }

    private func resyncAfterWake() {
        refreshSystemFlags()
        Task {
            guard phase == .armed else { return }
            if let status = try? await helper.status(), !status.armed {
                // The system slept while we were armed (forced sleep); the
                // helper released the override on the way down. Re-check
                // after the await — the heartbeat path may have won the race.
                guard phase == .armed, currentSession != nil else { return }
                finalizeSession(endReason: .systemSlept)
                phase = .disarmed
                if config.behavior.notifyOnStateChanges {
                    notifications.post(
                        title: "Keep-awake ended",
                        body: "Your Mac was put to sleep, so Lidless restored normal behavior."
                    )
                }
                publishWidget()
            }
        }
    }

    /// Launch reconciliation: a live helper session with no app session means
    /// the app crashed while armed and relaunched before the safety nets
    /// fired. Restore normal sleep — the session record was already folded
    /// into history by SessionStore's crash journal.
    private func reconcileWithHelper() async {
        guard phase == .disarmed else { return }
        guard helperState.isUsable else { return }
        if let status = try? await helper.status(), status.armed {
            _ = try? await helper.disarm(HelperDisarmOptions(
                forceSleep: false,
                reason: "orphaned session found at app launch"
            ))
            notifications.post(
                title: "Normal sleep restored",
                body: "Lidless found a keep-awake session from a previous run and ended it."
            )
        }
        refreshSystemFlags()
        maintainScheduledWake()
        publishWidget()
    }

    // MARK: - Tick loop

    private func startTickLoop() {
        guard tickTask == nil else { return }
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.tick()
                try? await Task.sleep(for: .seconds(15))
            }
        }
    }

    private func tick() {
        now = Date()
        systemMonitor?.refresh()
        refreshSystemFlags()

        // Event sources are primary; this refresh is the freeze-proof
        // fallback (and, in simulation, the sampling clock).
        batteryMonitor.refresh()
        battery = batteryMonitor.current
        appendRollingSample(battery)
        if isSimulation {
            thermal = thermalMonitor.reading
            processThermal = thermalMonitor.processLevel
        }

        recomputeDrain()

        // A confirmation card nobody answered must not linger forever — it
        // silently blocks schedule automation while it exists.
        if let pending = pendingArm, now.timeIntervalSince(pending.createdAt) > 180 {
            pendingArm = nil
        }

        if phase == .armed {
            recordSessionSampleIfDue(force: false)
            evaluateCutoffs()
            emitPreCutoffWarnings()
        }

        scheduleAutomationTick()
        // Reconcile the RTC wake on every tick, independent of automation
        // gating — turning automation off (or deleting the last window) must
        // cancel a previously registered wake.
        maintainScheduledWake()
        publishWidget()
    }

    private func refreshSystemFlags() {
        if let simulation {
            lidClosed = simulation.lidClosed
            hasLid = true
            if let simulated = helper as? SimulatedHelper {
                overrideActive = simulated.sleepDisabled
            }
        } else if let systemMonitor {
            lidClosed = systemMonitor.lidClosed
            hasLid = systemMonitor.hasLid
            overrideActive = systemMonitor.overrideActive
        }
    }

    // MARK: - Cutoff evaluation

    private func evaluateCutoffs() {
        guard phase == .armed, let session = currentSession else { return }
        let reference = Date()

        // Debounce on distinct *evidence*, not UI ticks: a strike advances
        // only when a NEW pmset reading violates (sampledAt changed) — or,
        // for process-thermal-only violations, which carry no timestamp, at
        // most every 45s. The engine receives the count of strikes *before*
        // the current evidence, so with the default strikesRequired = 2 a
        // single anomalous poll can never force sleep; a second violating
        // reading (~90s later) does.
        let violatesNow = CutoffEngine.isThermalViolation(
            config: effectiveConfig,
            thermal: thermal,
            processThermal: processThermal
        )
        // Only a pmset reading that ITSELF violates counts as stamped
        // evidence; a healthy reading arriving while ProcessInfo pressure is
        // elevated must not double-count the same episode. Process-thermal-
        // only violations pace on time (45s) since they carry no timestamp.
        let pmsetViolates = CutoffEngine.isThermalViolation(
            config: effectiveConfig,
            thermal: thermal,
            processThermal: .nominal
        )
        if violatesNow {
            let isNewEvidence: Bool
            if pmsetViolates, let stamp = thermal?.sampledAt {
                isNewEvidence = stamp != lastThermalStrikeStamp
                if isNewEvidence { lastThermalStrikeStamp = stamp }
            } else {
                isNewEvidence = reference >= nextStrikeAllowedAt
            }
            if isNewEvidence {
                thermalStrikes += 1
                nextStrikeAllowedAt = reference.addingTimeInterval(45)
            }
        } else {
            thermalStrikes = 0
            lastThermalStrikeStamp = nil
            nextStrikeAllowedAt = .distantPast
        }

        let evaluation = CutoffEngine.evaluate(
            config: effectiveConfig,
            armedAt: session.startedAt,
            now: reference,
            battery: battery,
            thermal: thermal,
            processThermal: processThermal,
            thermalStrikes: max(0, thermalStrikes - 1),
            calendar: .current
        )

        nextTimeCutoff = evaluation.nextTimeCutoff

        var fired = evaluation.fired
        if case .schedule = session.source {
            if let live = ScheduleEngine.activeOccurrence(
                windows: config.schedules,
                at: reference,
                calendar: .current
            ) {
                // Overlapping or edited windows extend the session; track
                // the covering occurrence so projections stay truthful.
                scheduleOccurrence = live
            } else {
                fired.append(.scheduleEnded)
            }
        }

        if !fired.isEmpty {
            Task { await fireCutoff(reasons: fired) }
        }
    }

    private func emitPreCutoffWarnings() {
        guard phase == .armed else { return }

        if let projected = projectedCutoff {
            let remaining = projected.date.timeIntervalSince(now)
            if remaining > 0, remaining <= 5 * 60, !warnedKinds.contains("imminent") {
                warnedKinds.insert("imminent")
                notifications.post(
                    title: "Sleeping soon",
                    body: "\(projected.label) — about \(Format.duration(remaining)) left."
                )
            }
        }

        let cfg = effectiveConfig
        if cfg.batteryFloorEnabled,
           battery.isDischarging,
           let percent = battery.percent,
           percent <= cfg.batteryFloorPercent + 3,
           percent > cfg.batteryFloorPercent,
           !warnedKinds.contains("battery") {
            warnedKinds.insert("battery")
            notifications.post(
                title: "Battery near cutoff",
                body: "\(percent)% — Lidless restores normal sleep at \(cfg.batteryFloorPercent)%."
            )
        }
    }

    // MARK: - Schedule automation

    private func scheduleAutomationTick() {
        guard config.scheduleAutomationEnabled, !config.schedules.isEmpty else {
            suppressedOccurrence = nil
            return
        }
        let reference = Date()

        if let suppressed = suppressedOccurrence, reference >= suppressed.end {
            suppressedOccurrence = nil
        }

        guard phase == .disarmed, pendingArm == nil, helperState.isUsable else {
            return
        }

        if let active = ScheduleEngine.activeOccurrence(windows: config.schedules, at: reference, calendar: .current),
           active != suppressedOccurrence {
            let assessment = CutoffEngine.assessArm(config: config.cutoffs, battery: battery)
            if case .refusedBelowFloor = assessment {
                // Below the floor: arming would cut off immediately. Skip
                // this occurrence rather than flap.
                suppressedOccurrence = active
            } else {
                scheduleOccurrence = active
                pendingArm = PendingArm(
                    overrides: nil,
                    source: .schedule(windowID: active.windowID),
                    assessment: assessment,
                    projection: projection(for: nil),
                    createdAt: reference
                )
                Task { await confirmArm() }
            }
        }
    }

    /// Keep an RTC wake registered just before the next window so a closed,
    /// sleeping MacBook can wake up and arm itself (best effort — DarkWake
    /// still runs launchd + us long enough to arm). Desired-state
    /// reconciliation against the three-state cache; an unusable helper
    /// pauses (never blindly cancels) maintenance.
    private func maintainScheduledWake() {
        guard !isSimulation, helperState.isUsable else { return }

        let next = config.scheduleAutomationEnabled
            ? ScheduleEngine.nextStart(windows: config.schedules, after: Date(), calendar: .current)
            : nil
        let desired: Date? = next.map { $0.start.addingTimeInterval(-60) }

        if lastScheduledWakeSent != .some(desired) {
            lastScheduledWakeSent = .some(desired)
            Task { try? await helper.scheduleWake(desired) }
        }
    }

    // MARK: - Heartbeat

    private func startHeartbeat() {
        stopHeartbeat()
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(HelperArmOptions.heartbeatInterval))
                guard let self, self.phase == .armed else { continue }
                do {
                    let reply = try await self.helper.heartbeat()
                    if !reply.ok {
                        // Helper restarted and lost the session state.
                        await self.rearmAfterHelperRestart()
                    }
                } catch {
                    // Interruption handler drives the re-arm; next beat retries.
                }
            }
        }
    }

    private func stopHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
    }

    // MARK: - Samples & drain

    private func appendRollingSample(_ snapshot: BatterySnapshot) {
        guard let percent = snapshot.percent else { return }
        let sample = BatterySample(
            time: snapshot.sampledAt,
            percent: Double(percent),
            isDischarging: snapshot.isDischarging
        )
        if let last = rollingSamples.last {
            let dischargeFlip = last.isDischarging != sample.isDischarging
            guard dischargeFlip || sample.time.timeIntervalSince(last.time) >= 240 else { return }
        }
        rollingSamples.append(sample)
        if rollingSamples.count > 120 {
            rollingSamples.removeFirst(rollingSamples.count - 120)
        }
    }

    private func recordSessionSampleIfDue(force: Bool) {
        guard phase == .armed, var session = currentSession, let percent = battery.percent else { return }
        let reference = Date()
        guard force || reference.timeIntervalSince(lastSessionSampleAt) >= 5 * 60 else { return }
        lastSessionSampleAt = reference
        session.samples.append(BatterySample(
            time: reference,
            percent: Double(percent),
            isDischarging: battery.isDischarging
        ))
        currentSession = session
        sessionStore.checkpoint(session)
    }

    private func recomputeDrain() {
        drainPerHour = DrainEstimator.drainPerHour(samples: rollingSamples, now: Date())
    }

    /// Screenshot staging only: real sampling needs wall-clock time the
    /// renderer doesn't have. Never called outside ScreenshotRenderer.
    func seedRollingSamplesForRendering(_ samples: [BatterySample]) {
        rollingSamples = samples
        recomputeDrain()
    }

    // MARK: - Widget

    private func publishWidget() {
        let projected = projectedCutoff
        let widgetStatusLine: String
        if isArmed {
            widgetStatusLine = projected?.label ?? "Until disarmed"
        } else if overrideActive {
            widgetStatusLine = "Sleep override active — not Lidless"
        } else {
            widgetStatusLine = "Sleeping normally"
        }
        let snapshot = WidgetSnapshot(
            armed: isArmed,
            statusLine: widgetStatusLine,
            batteryPercent: battery.percent,
            isCharging: battery.isCharging,
            drainPerHour: drainPerHour,
            projectedCutoff: projected?.date,
            projectedCutoffLabel: projected?.label,
            overrideActive: overrideActive,
            recentSamples: Array(rollingSamples.suffix(WidgetStore.maxSamples)),
            updatedAt: Date()
        )
        widgetPublisher.publish(snapshot)
    }

    // MARK: - Window & URL plumbing

    func requestMainWindow(pane: MainPane? = nil) {
        if let pane {
            mainPane = pane
        }
        mainWindowRequestToken += 1
        NSApp.activate(ignoringOtherApps: true)
    }

    func handleURL(_ url: URL) {
        guard url.scheme == LidlessIDs.urlScheme else { return }
        switch url.host {
        case "disarm":
            Task { await disarm() }
        case "open", nil:
            requestMainWindow()
        default:
            requestMainWindow()
        }
    }

    func helperLogText() -> String {
        (try? String(contentsOfFile: HelperPaths.log, encoding: .utf8)) ?? ""
    }
}
