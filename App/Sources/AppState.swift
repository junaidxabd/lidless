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
    private(set) var overrideStateVerified = false
    private var lastOverrideRevision: UInt64?
    /// A readable registry value proves only machine state. A verified armed
    /// claim additionally requires a current helper reply proving ownership.
    private var helperSessionProven = false
    private var helperProofEpoch: UInt64 = 0
    /// Invalidates launch-time status replies across helper install/removal
    /// operations even when their coarse install state returns to the same
    /// value before the suspended reply resumes.
    private var helperLifecycleEpoch: UInt64 = 0
    private var helperLifecycleOperationsInFlight = 0
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
    /// Reply-committed reconciliation state for the helper's RTC wake. It
    /// starts unknown and failed/rejected calls stay retryable.
    private var scheduledWakeReconciliation = ScheduledWakeReconciliation()
    /// Most recent sleep/wake transition signal, used to distinguish "helper
    /// lost the session because the system slept" from "helper crashed".
    private var lastSleepSignal = Date.distantPast
    /// A sleep/wake signal permanently fences every arm request dispatched by
    /// an older generation. The app remains restoring until all such requests
    /// settle and a later helper reply plus registry read prove normal sleep.
    private var sleepGeneration: UInt64 = 0
    private var sleepTerminationGeneration: UInt64?
    /// A sleep transition may replace the local worker but must preserve the
    /// privileged mutation needed by its interrupted restore generation.
    private var sleepTerminationActuation: NonSleepRestoreActuation?
    private var armRequestsInFlight = 0

    private var tickTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    /// Fences a heartbeat reply that resumes after its owning session or task
    /// has already been replaced. Cancellation alone cannot cancel an XPC
    /// continuation that has not replied yet.
    private var heartbeatGeneration = UUID()
    private var restoreMonitorTask: Task<Void, Never>?
    private var sleepTerminationTask: Task<Void, Never>?

    /// Deferred session completion while the helper is still retrying or the
    /// registry cannot yet prove that normal sleep was restored.
    private struct PendingRestore {
        /// Unforgeable identity fences late XPC results from an older restore.
        var id: NonSleepRestoreGeneration? = nil
        /// The helper mutation that must remain retryable for this generation.
        /// Outside-override repair cannot degrade to a plain disarm: if the
        /// first XPC delivery was lost, only another repair attempt can create
        /// the helper recovery sentinel and restore the external override.
        var actuation: NonSleepRestoreActuation = .disarm
        var options: HelperDisarmOptions
        /// A cutoff may ask for sleep only after ordinary sleep has been
        /// restored. This follow-up is dispatched at most once because a lost
        /// XPC reply does not prove that `sleepnow` was not already scheduled.
        var forceSleepFollowUp: HelperDisarmOptions? = nil
        /// Manual and quit callers remain suspended until this generation is
        /// actually complete; unattended cutoff/recovery callers do not.
        var waitsForCompletion = false
        var endReason: SessionEndReason?
        var notificationTitle: String?
        var notificationBody: String?
        var notificationSound: Bool
        var playChime: Bool
        /// A never-established arm request may end without mutating a
        /// separately owned override once exact non-ownership is proven.
        var allowsUnownedExternalOverrideCompletion = false
        /// Optional explanation to retain after recovery terminates.
        var completionError: String?
    }

    private var pendingRestore: PendingRestore?
    private var restoreGate = NonSleepRestoreGate()
    /// Set before AppKit is allowed to terminate so queued manual/scheduled
    /// arm work cannot cross the quit decision.
    private var terminationPending = false
    private var terminationRestoreGeneration: NonSleepRestoreGeneration?
    /// Prevents outside-override repair from crossing helper removal while
    /// that app-side operation is suspended.
    private var uninstallInProgress = false

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
            self?.resyncAfterWake()
        }
        systemMonitor?.onWillSleep = { [weak self] in
            self?.recordSleepTransition()
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
            await refreshHelperInstallState()
            await reconcileWithHelper()
        }

        startTickLoop()
    }

    // MARK: - Derived state for UI

    var isArmed: Bool { phase == .armed || phase == .disarming }

    var sleepPresentation: SleepPresentationState {
        let presentationPhase: SleepPresentationPhase = switch phase {
        case .disarmed: .disarmed
        case .arming: .arming
        case .armed: .armed
        case .disarming: .restoring
        }
        let observedOverride = overrideStateVerified ? overrideActive : nil
        let eligibleHelperSessionProven = helperSessionProven && helperState.isUsable
        return SleepPresentationPolicy.resolve(
            phase: presentationPhase,
            observedOverride: observedOverride,
            helperSessionProven: eligibleHelperSessionProven
        )
    }

    private func invalidateHelperSessionProof() {
        helperSessionProven = false
        helperProofEpoch &+= 1
    }

    private func beginHelperLifecycleOperation() {
        helperLifecycleOperationsInFlight += 1
        helperLifecycleEpoch &+= 1
    }

    private func endHelperLifecycleOperation() {
        helperLifecycleOperationsInFlight -= 1
        helperLifecycleEpoch &+= 1
    }

    private func refreshHelperInstallState() async {
        beginHelperLifecycleOperation()
        defer { endHelperLifecycleOperation() }
        await helper.refreshInstallState()
    }

    private func recordSleepTransition() {
        lastSleepSignal = Date()
        sleepGeneration &+= 1
        invalidateHelperSessionProof()
        overrideStateVerified = false

        let cancelledPendingIntent = pendingArm != nil
        // Suppress the active schedule occurrence even when its queued
        // confirm task has not yet changed the phase from disarmed.
        if let occurrence = scheduleOccurrence {
            suppressedOccurrence = occurrence
        } else if config.scheduleAutomationEnabled,
                  let active = ScheduleEngine.activeOccurrence(
                      windows: config.schedules,
                      at: lastSleepSignal,
                      calendar: .current
                  ) {
            suppressedOccurrence = active
        }
        pendingArm = nil
        scheduleOccurrence = nil

        let terminatesActiveIntent = phase == .arming
            || phase == .armed
            || phase == .disarming
            || armRequestsInFlight > 0
            || pendingRestore != nil
            || sleepTerminationGeneration != nil
        if terminatesActiveIntent {
            if sleepTerminationGeneration == nil {
                sleepTerminationGeneration = sleepGeneration
                sleepTerminationActuation = pendingRestore?.actuation ?? .disarm
            }
            cancelPendingRestoreForSleepTransition()
            phase = .disarming
            stopHeartbeat()
            lastError = "System sleep ended the keep-awake request. Restoring normal sleep."
        } else if cancelledPendingIntent {
            lastError = "The keep-awake request was cancelled because the system slept."
        }
        publishWidget()
        if terminatesActiveIntent {
            scheduleSleepTerminationRestore()
        }
    }

    /// Brackets every helper arm suspension so terminal recovery knows when a
    /// late request has settled. The restore worker still runs immediately;
    /// this count only prevents completion before the final compensating
    /// restore can run.
    private func trackedArm(_ options: HelperArmOptions) async throws -> HelperReply {
        armRequestsInFlight += 1
        defer {
            armRequestsInFlight -= 1
            scheduleSleepTerminationRestore()
        }
        return try await helper.arm(options)
    }

    private func scheduleSleepTerminationRestore() {
        guard sleepTerminationGeneration != nil,
              sleepTerminationTask == nil
        else { return }

        sleepTerminationTask = Task { [weak self] in
            await self?.restoreAfterSleepTransition()
        }
    }

    /// Idempotent recovery starts even while an arm reply is outstanding and
    /// repeats after it settles. A helper reply alone is insufficient: the
    /// independently refreshed registry must also prove the override is off.
    private func restoreAfterSleepTransition() async {
        defer { sleepTerminationTask = nil }

        while !Task.isCancelled {
            guard let terminalGeneration = sleepTerminationGeneration,
                  let terminalActuation = sleepTerminationActuation
            else { return }

            do {
                let reply: HelperReply
                switch terminalActuation {
                case .disarm:
                    reply = try await helper.disarm(HelperDisarmOptions(
                        forceSleep: false,
                        reason: "system sleep terminal fence"
                    ))
                case .repairOverride:
                    reply = try await helper.repairOverride()
                }
                guard terminalGeneration == sleepTerminationGeneration else { continue }

                systemMonitor?.refresh()
                refreshSystemFlags()
                if SleepOverrideSafety.isRestoreProven(reply),
                   overrideStateVerified,
                   !overrideActive,
                   armRequestsInFlight == 0 {
                    let endedSession = currentSession != nil
                    pendingRestore = nil
                    stopRestoreMonitor()
                    if endedSession {
                        finalizeSession(endReason: .systemSlept)
                    } else {
                        stopHeartbeat()
                    }
                    sleepTerminationGeneration = nil
                    sleepTerminationActuation = nil
                    phase = .disarmed
                    lastError = nil
                    systemMonitor?.refresh()
                    refreshSystemFlags()
                    if endedSession,
                       config.behavior.notifyOnStateChanges,
                       sleepPresentation == .verifiedNormal {
                        notifications.post(
                            title: "Keep-awake ended",
                            body: "Your Mac was put to sleep, so Lidless restored normal behavior."
                        )
                    }
                    publishWidget()
                    return
                }

                lastError = reply.error
                    ?? (armRequestsInFlight == 0
                        ? "Normal sleep is not verified yet. Lidless will keep checking."
                        : "Waiting for an in-flight arm request before normal sleep can be verified.")
            } catch {
                guard terminalGeneration == sleepTerminationGeneration else { continue }
                lastError = "Normal sleep is not verified yet (\(error.localizedDescription)). Lidless will keep checking."
            }

            systemMonitor?.refresh()
            refreshSystemFlags()
            publishWidget()
            do {
                try await Task.sleep(for: .seconds(5))
            } catch {
                return
            }
        }
    }

    var effectiveConfig: CutoffConfig { config.cutoffs.applying(sessionOverrides) }

    /// The override is on but no Lidless session explains it — either another
    /// tool set it, or a restore failed. Never let this be invisible.
    var overrideLeaked: Bool { sleepPresentation == .outsideOverride }
    var overrideStateUnknown: Bool { sleepPresentation == .unknown }

    var statusHeadline: String {
        switch sleepPresentation {
        case .verifiedNormal: "Sleeping normally"
        case .verifyingArm: "Verifying sleep override…"
        case .verifiedArmed: "Staying awake"
        case .restoring: "Restoring sleep…"
        case .outsideOverride: "Sleep is disabled"
        case .unknown: "Sleep state unknown"
        }
    }

    var statusDetail: String? {
        switch sleepPresentation {
        case .verifiedArmed:
            if let projected = projectedCutoff {
                return "\(projected.label) · \(Format.countdown(to: projected.date, from: now))"
            }
            // No projected end date yet, but safety guards may still be
            // armed (floor/thermal) — never imply they aren't.
            if let summary = currentSession?.cutoffSummary, summary != "No cutoffs" {
                return summary
            }
            return "No automatic cutoff — disarm manually"
        case .verifyingArm, .restoring:
            return nil
        case .outsideOverride:
            return "Sleep override is active outside Lidless"
        case .unknown:
            return "Lidless couldn't verify the system sleep state"
        case .verifiedNormal:
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
        switch sleepPresentation {
        case .verifiedNormal: "eye.slash"
        case .verifyingArm: "eye"
        case .verifiedArmed: "eye.fill"
        case .restoring, .outsideOverride, .unknown:
            "eye.trianglebadge.exclamationmark"
        }
    }

    var menuBarText: String? {
        guard config.behavior.countdownInMenuBar,
              sleepPresentation == .verifiedArmed,
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
        guard !terminationPending, phase == .disarmed else { return }
        lastError = nil

        guard sleepPresentation == .verifiedNormal else {
            lastError = "Lidless must verify that normal sleep is enabled before arming."
            return
        }

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
        guard !terminationPending,
              let intent = pendingArm,
              phase == .disarmed
        else { return }
        if case .refusedBelowFloor = intent.assessment { return }
        guard sleepPresentation == .verifiedNormal else {
            pendingArm = nil
            scheduleOccurrence = nil
            lastError = "Lidless must verify that normal sleep is enabled before arming."
            return
        }

        phase = .arming
        invalidateHelperSessionProof()
        overrideStateVerified = false
        // Replace any persisted verified-OFF widget claim before the first
        // suspension point that can lead to the helper applying the override.
        guard publishWidget() else {
            phase = .disarmed
            pendingArm = nil
            scheduleOccurrence = nil
            lastError = "Couldn't arm because the widget safety state couldn't be persisted."
            return
        }
        await notifications.requestAuthorizationIfNeeded()

        // The confirmation may have remained open while the helper was
        // upgraded or replaced. Probe the live service at the mutation
        // boundary; a cached ready state is not authorization to arm.
        let eligibilityEpoch = helperProofEpoch
        await refreshHelperInstallState()
        guard phase == .arming, eligibilityEpoch == helperProofEpoch else {
            if phase == .arming {
                phase = .disarmed
                pendingArm = nil
                scheduleOccurrence = nil
                lastError = "Couldn't arm because the helper changed during verification."
                publishWidget()
            }
            return
        }
        guard helperState.isUsable else {
            phase = .disarmed
            pendingArm = nil
            scheduleOccurrence = nil
            lastError = "Couldn't arm because the current helper is not eligible."
            publishWidget()
            return
        }

        // Re-read the registry after every suspension. The helper repeats this
        // preflight immediately before mutation, but the app must not knowingly
        // send an arm request over newly active or unreadable external state.
        systemMonitor?.refresh()
        refreshSystemFlags()
        let observedBeforeArm = overrideStateVerified ? overrideActive : nil
        guard SleepOverrideSafety.preflight(observed: observedBeforeArm) == .safeToArm else {
            phase = .disarmed
            pendingArm = nil
            scheduleOccurrence = nil
            lastError = "Couldn't arm because normal sleep is no longer verified."
            publishWidget()
            return
        }

        // Cancellation, expiry, and battery events can all run while the
        // authorization/helper probes are suspended. Honor only the same live
        // intent and the same assessment the user actually confirmed.
        guard let pending = pendingArm,
              pending.createdAt == intent.createdAt,
              pending.source == intent.source,
              pending.overrides == intent.overrides else {
            phase = .disarmed
            pendingArm = nil
            scheduleOccurrence = nil
            lastError = "Arming was cancelled or expired before verification completed."
            publishWidget()
            return
        }
        let freshAssessment = CutoffEngine.assessArm(
            config: config.cutoffs.applying(pending.overrides),
            battery: battery
        )
        if case .refusedBelowFloor = freshAssessment {
            phase = .disarmed
            pendingArm = nil
            scheduleOccurrence = nil
            lastError = "Couldn't arm because the battery reached the safety floor."
            publishWidget()
            return
        }
        guard freshAssessment == intent.assessment else {
            phase = .disarmed
            pendingArm = nil
            scheduleOccurrence = nil
            lastError = "Battery conditions changed. Review the updated warning before arming."
            publishWidget()
            return
        }

        let options = HelperArmOptions(
            lowPowerMode: config.behavior.lowPowerModeWhileArmed,
            tcpKeepAlive: config.behavior.tcpKeepAliveWhileArmed
        )
        // The mutation dispatch is the commit point: remove the pending card
        // before the XPC suspension so Cancel or a battery refresh cannot
        // mutate a request that is already being applied by the helper.
        pendingArm = nil
        let armProofEpoch = eligibilityEpoch
        let armSleepGeneration = sleepGeneration

        do {
            let reply = try await trackedArm(options)
            guard phase == .arming,
                  helperState.isUsable,
                  armSleepGeneration == sleepGeneration,
                  armProofEpoch == helperProofEpoch,
                  SleepOverrideSafety.isArmProven(reply) else {
                invalidateHelperSessionProof()
                overrideStateVerified = false
                if sleepTerminationGeneration != nil {
                    scheduleSleepTerminationRestore()
                    publishWidget()
                    return
                }
                if pendingRestore != nil {
                    startRestoreMonitor()
                    publishWidget()
                    return
                }
                let message = "Couldn't arm: \(reply.error ?? "The helper could not verify the sleep override.")"
                pendingArm = nil
                suppressCurrentScheduleOccurrence()

                let independentlyObserved = refreshedSleepOverride()
                switch SleepOverrideSafety.failedArmDisposition(
                    reply,
                    independentlyObserved: independentlyObserved
                ) {
                case .alreadyRestored:
                    phase = .disarmed
                    lastError = message
                    publishWidget()
                case .externalOverride:
                    phase = .disarmed
                    lastError = "Couldn't arm because a sleep override is active outside Lidless. Lidless left it unchanged."
                    publishWidget()
                case .recoveryRequired:
                    _ = beginRestore(PendingRestore(
                        options: HelperDisarmOptions(forceSleep: false, reason: "recovering failed arm"),
                        endReason: nil,
                        notificationTitle: nil,
                        notificationBody: nil,
                        notificationSound: false,
                        playChime: false,
                        allowsUnownedExternalOverrideCompletion: true,
                        completionError: message
                    ))
                }
                await refreshHelperInstallState()
                return
            }
            helperSessionProven = true

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
            systemMonitor?.refresh()
            refreshSystemFlags()
            evaluateCutoffs()

            if config.behavior.notifyOnStateChanges,
               sleepPresentation == .verifiedArmed {
                notifications.post(
                    title: "Keeping your Mac awake",
                    body: session.cutoffSummary
                )
            }
            publishWidget()
        } catch {
            if sleepTerminationGeneration != nil {
                invalidateHelperSessionProof()
                overrideStateVerified = false
                scheduleSleepTerminationRestore()
                publishWidget()
                return
            }
            pendingArm = nil
            suppressCurrentScheduleOccurrence()
            let message = "Couldn't arm: \(error.localizedDescription)"
            _ = beginRestore(PendingRestore(
                options: HelperDisarmOptions(forceSleep: false, reason: "recovering interrupted arm"),
                endReason: nil,
                notificationTitle: nil,
                notificationBody: nil,
                notificationSound: false,
                playChime: false,
                allowsUnownedExternalOverrideCompletion: true,
                completionError: message
            ))
            await refreshHelperInstallState()
        }
    }

    /// The always-available "Disarm & restore normal sleep".
    func disarm() async {
        pendingArm = nil
        guard phase == .armed || phase == .arming else { return }
        suppressCurrentScheduleOccurrence()
        guard let restoreID = beginRestore(PendingRestore(
            options: HelperDisarmOptions(forceSleep: false, reason: "manual disarm"),
            waitsForCompletion: true,
            endReason: currentSession == nil ? nil : .manual,
            notificationTitle: config.behavior.notifyOnStateChanges ? "Normal sleep restored" : nil,
            notificationBody: config.behavior.notifyOnStateChanges ? "Lidless is disarmed." : nil,
            notificationSound: false,
            playChime: false,
            allowsUnownedExternalOverrideCompletion: currentSession == nil,
            completionError: nil
        )) else { return }
        _ = await waitForRestore(restoreID: restoreID)
    }

    /// Fences queued intent immediately before AppKit is allowed to terminate.
    /// A disarmed phase is not enough: the independent registry state must be
    /// readable and normal.
    func prepareForImmediateTermination() -> Bool {
        let independentlyObserved = refreshedSleepOverride()
        guard NonSleepRestoreGate.allowsImmediateTermination(
            isDisarmed: phase == .disarmed,
            hasActiveSession: currentSession != nil,
            hasPendingRestore: pendingRestore != nil,
            independentlyObserved: independentlyObserved,
            presentation: sleepPresentation
        )
        else { return false }

        terminationPending = true
        terminationRestoreGeneration = nil
        pendingArm = nil
        scheduleOccurrence = nil
        return true
    }

    /// Returns only after the same restore generation has completed. AppKit
    /// keeps its terminate-later request open during recovery, so an `.appQuit`
    /// history record cannot be written for a quit that was already cancelled.
    func disarmForQuit() async -> Bool {
        guard phase == .armed else { return false }
        terminationPending = true
        pendingArm = nil
        scheduleOccurrence = nil
        guard let restoreID = beginRestore(PendingRestore(
            options: HelperDisarmOptions(forceSleep: false, reason: "app quit"),
            waitsForCompletion: true,
            endReason: .appQuit,
            notificationTitle: nil,
            notificationBody: nil,
            notificationSound: false,
            playChime: false,
            completionError: nil
        )) else {
            terminationPending = false
            return false
        }
        terminationRestoreGeneration = restoreID
        return await waitForRestore(restoreID: restoreID)
    }

    private func fireCutoff(reasons: [CutoffReason]) async {
        guard phase == .armed, let primary = reasons.first else { return }

        let sleepAfter = config.behavior.sleepOnCutoff && lidClosed
        let label = cutoffLabel(primary)

        _ = beginRestore(PendingRestore(
            // Restoration is always idempotent. `sleepnow` is a separate,
            // one-shot follow-up after two-source normal-sleep proof.
            options: HelperDisarmOptions(forceSleep: false, reason: label),
            forceSleepFollowUp: sleepAfter
                ? HelperDisarmOptions(forceSleep: true, reason: label)
                : nil,
            endReason: .cutoff(primary),
            notificationTitle: config.behavior.notifyOnStateChanges
                ? (sleepAfter ? "Sleep requested" : "Keep-awake ended")
                : nil,
            notificationBody: config.behavior.notifyOnStateChanges ? label : nil,
            notificationSound: config.behavior.playCutoffSound,
            playChime: config.behavior.playCutoffSound,
            completionError: nil
        ))
    }

    /// Starts a restore and completes the session only after an exact helper
    /// reply and a fresh independent registry read both prove normal sleep.
    /// Otherwise the session and crash journal stay live while one
    /// generation-bound worker retries the idempotent restore.
    @discardableResult
    private func beginRestore(
        _ requested: PendingRestore
    ) -> NonSleepRestoreGeneration? {
        if let restoreID = pendingRestore?.id { return restoreID }
        guard !terminationPending || requested.endReason == .appQuit else {
            return nil
        }

        var pending = requested
        guard pending.actuation.allowsConfiguration(
            forceSleepRequested: pending.options.forceSleep || pending.forceSleepFollowUp != nil,
            finalizesSession: pending.endReason != nil,
            allowsUnownedExternalOverrideCompletion: pending.allowsUnownedExternalOverrideCompletion
        ) else {
            lastError = "Invalid normal-sleep recovery configuration."
            return nil
        }
        let restoreID = restoreGate.begin(
            forceSleepRequested: pending.forceSleepFollowUp != nil,
            requiresFinalProof: pending.endReason == .appQuit
        )
        pending.id = restoreID
        pendingRestore = pending
        phase = .disarming
        stopHeartbeat()
        invalidateHelperSessionProof()
        overrideStateVerified = false
        publishWidget()
        startRestoreMonitor()
        return restoreID
    }

    private func waitForRestore(
        restoreID: NonSleepRestoreGeneration
    ) async -> Bool {
        while true {
            if restoreGate.consumeCompletion(restoreID) {
                return true
            }
            guard !Task.isCancelled else {
                abandonRestoreWait(restoreID: restoreID)
                return false
            }

            if restoreGate.isAwaitingFinalProof(restoreID) {
                if let completed = await verifyQuitAtTerminationBoundary(
                    restoreID: restoreID
                ) {
                    return completed
                }
                continue
            }

            guard restoreGate.owns(restoreID),
                  pendingRestore?.id == restoreID
            else {
                abandonRestoreWait(restoreID: restoreID)
                return false
            }
            do {
                try await Task.sleep(for: .milliseconds(100))
            } catch {
                if restoreGate.consumeCompletion(restoreID) {
                    return true
                }
                abandonRestoreWait(restoreID: restoreID)
                return false
            }
        }
    }

    /// Quit receives a second helper reply and a fresh independent registry
    /// read immediately before `.appQuit` is finalized. Until this returns
    /// true, AppKit's terminate-later request remains open and the crash
    /// journal remains live.
    private func verifyQuitAtTerminationBoundary(
        restoreID: NonSleepRestoreGeneration
    ) async -> Bool? {
        guard terminationPending,
              terminationRestoreGeneration == restoreID,
              let pending = pendingRestore,
              pending.id == restoreID,
              pending.endReason == .appQuit,
              restoreGate.isAwaitingFinalProof(restoreID)
        else { return false }
        guard case .disarm = pending.actuation else { return false }

        do {
            let reply = try await helper.disarm(pending.options)
            guard !Task.isCancelled else {
                abandonRestoreWait(restoreID: restoreID)
                return false
            }
            guard terminationPending,
                  terminationRestoreGeneration == restoreID,
                  pendingRestore?.id == restoreID
            else { return false }
            guard sleepTerminationGeneration == nil else {
                cancelPendingRestoreForSleepTransition()
                scheduleSleepTerminationRestore()
                return false
            }

            let independentlyObserved = refreshedSleepOverride()
            switch restoreGate.evaluateFinalProof(
                generation: restoreID,
                helperReply: reply,
                independentlyObserved: independentlyObserved,
                armRequestsInFlight: armRequestsInFlight
            ) {
            case .complete:
                completePendingRestore(expectedID: restoreID)
                return nil
            case .retry:
                lastError = reply.error
                    ?? (armRequestsInFlight == 0
                        ? "Normal sleep changed before quit could be committed. Lidless will verify it again."
                        : "Waiting for an in-flight arm request before quit can be committed.")
                startRestoreMonitor(delayFirstAttempt: true)
                publishWidget()
                return nil
            case .ignore:
                return false
            case .dispatchForceSleep, .awaitFinalProof:
                return false
            }
        } catch {
            guard !Task.isCancelled else {
                abandonRestoreWait(restoreID: restoreID)
                return false
            }
            guard restoreGate.rejectFinalProof(restoreID) == .retry else {
                return false
            }
            lastError = "The final normal-sleep check failed (\(error.localizedDescription)). Lidless will keep restoring before quit."
            startRestoreMonitor(delayFirstAttempt: true)
            publishWidget()
            return nil
        }
    }

    private func completePendingRestore(
        expectedID restoreID: NonSleepRestoreGeneration
    ) {
        guard sleepTerminationGeneration == nil,
              let pending = pendingRestore,
              pending.id == restoreID,
              restoreGate.isCompleted(restoreID)
        else { return }

        pendingRestore = nil
        stopRestoreMonitor()

        if let endReason = pending.endReason {
            finalizeSession(endReason: endReason)
        } else {
            stopHeartbeat()
        }

        phase = .disarmed
        lastError = pending.completionError
        refreshSystemFlags()

        if let title = pending.notificationTitle,
           let body = pending.notificationBody,
           sleepPresentation == .verifiedNormal {
            notifications.post(
                title: title,
                body: body,
                sound: pending.notificationSound
            )
        }
        if pending.playChime,
           sleepPresentation == .verifiedNormal {
            notifications.playCutoffChime()
        }
        if !pending.waitsForCompletion {
            restoreGate.consumeCompletion(restoreID)
        }
        publishWidget()
    }

    private func startRestoreMonitor(delayFirstAttempt: Bool = false) {
        guard restoreMonitorTask == nil,
              let restoreID = pendingRestore?.id
        else { return }

        restoreMonitorTask = Task { [weak self] in
            await self?.runRestoreMonitor(
                restoreID: restoreID,
                delayFirstAttempt: delayFirstAttempt
            )
        }
    }

    private func runRestoreMonitor(
        restoreID: NonSleepRestoreGeneration,
        delayFirstAttempt: Bool
    ) async {
        defer {
            // A cancelled worker may resume after a newer restore begins. It
            // must never clear that newer worker's task slot.
            if pendingRestore?.id == restoreID {
                restoreMonitorTask = nil
            }
        }

        var shouldDelay = delayFirstAttempt
        while !Task.isCancelled {
            guard phase == .disarming,
                  let pending = pendingRestore,
                  pending.id == restoreID
            else { return }

            if shouldDelay {
                do {
                    try await Task.sleep(for: .seconds(5))
                } catch {
                    return
                }
                guard pendingRestore?.id == restoreID else { return }
            }
            shouldDelay = true

            do {
                let reply: HelperReply
                switch pending.actuation {
                case .disarm:
                    reply = try await helper.disarm(pending.options)
                case .repairOverride:
                    reply = try await helper.repairOverride()
                }
                guard pendingRestore?.id == restoreID else { return }
                guard sleepTerminationGeneration == nil else {
                    cancelPendingRestoreForSleepTransition()
                    scheduleSleepTerminationRestore()
                    return
                }

                let independentlyObserved = refreshedSleepOverride()
                if pending.allowsUnownedExternalOverrideCompletion {
                    switch restoreGate.completeUnownedExternalOverride(
                        generation: restoreID,
                        helperReply: reply,
                        independentlyObserved: independentlyObserved,
                        armRequestsInFlight: armRequestsInFlight,
                        establishedSessionExists: currentSession != nil
                    ) {
                    case .complete:
                        completePendingRestore(expectedID: restoreID)
                        return
                    case .ignore:
                        return
                    case .retry, .dispatchForceSleep, .awaitFinalProof:
                        break
                    }
                }
                switch restoreGate.evaluateBaseProof(
                    generation: restoreID,
                    helperReply: reply,
                    independentlyObserved: independentlyObserved,
                    armRequestsInFlight: armRequestsInFlight
                ) {
                case .complete:
                    completePendingRestore(expectedID: restoreID)
                    return
                case .dispatchForceSleep:
                    if await dispatchForceSleepFollowUp(restoreID: restoreID) {
                        return
                    }
                case .awaitFinalProof:
                    lastError = nil
                    publishWidget()
                    return
                case .retry:
                    lastError = reply.error
                        ?? (armRequestsInFlight == 0
                            ? "Normal sleep is not verified yet. Lidless will keep checking."
                            : "Waiting for an in-flight arm request before normal sleep can be verified.")
                case .ignore:
                    return
                }
            } catch {
                guard pendingRestore?.id == restoreID else { return }
                lastError = "Normal sleep is not verified yet (\(error.localizedDescription)). Lidless will keep checking."
            }
            publishWidget()
        }
    }

    /// Returns true only when this worker is finished. The pure gate commits
    /// the one-shot authorization before this method suspends in XPC.
    private func dispatchForceSleepFollowUp(
        restoreID: NonSleepRestoreGeneration
    ) async -> Bool {
        guard let pending = pendingRestore,
              pending.id == restoreID,
              let followUp = pending.forceSleepFollowUp
        else { return true }

        do {
            let reply = try await helper.disarm(followUp)
            guard pendingRestore?.id == restoreID else { return true }
            guard sleepTerminationGeneration == nil else {
                cancelPendingRestoreForSleepTransition()
                scheduleSleepTerminationRestore()
                return true
            }
            let followUpObservation = refreshedSleepOverride()
            switch restoreGate.evaluateFollowUpProof(
                generation: restoreID,
                helperReply: reply,
                independentlyObserved: followUpObservation,
                armRequestsInFlight: armRequestsInFlight
            ) {
            case .complete:
                completePendingRestore(expectedID: restoreID)
                return pendingRestore?.id != restoreID
            case .retry:
                markForceSleepFollowUpUnverified(
                    restoreID: restoreID,
                    detail: reply.error ?? "the helper did not return complete restore proof"
                )
            case .ignore:
                return true
            case .awaitFinalProof:
                return true
            case .dispatchForceSleep:
                return false
            }
        } catch {
            guard pendingRestore?.id == restoreID else { return true }
            markForceSleepFollowUpUnverified(
                restoreID: restoreID,
                detail: error.localizedDescription
            )
        }
        return false
    }

    private func markForceSleepFollowUpUnverified(
        restoreID: NonSleepRestoreGeneration,
        detail: String
    ) {
        guard var pending = pendingRestore,
              pending.id == restoreID
        else { return }
        let message = "The follow-up sleep request was ambiguous (\(detail)). Lidless did not repeat it."
        pending.notificationTitle = "Keep-awake ended"
        pending.playChime = false
        pending.completionError = message
        pendingRestore = pending
        lastError = message
    }

    private func abandonRestoreWait(
        restoreID: NonSleepRestoreGeneration
    ) {
        guard terminationRestoreGeneration == restoreID else {
            if var pending = pendingRestore,
               pending.id == restoreID {
                pending.waitsForCompletion = false
                pendingRestore = pending
            } else {
                restoreGate.consumeCompletion(restoreID)
            }
            return
        }
        terminationPending = false
        terminationRestoreGeneration = nil

        guard var recovery = pendingRestore,
              recovery.id == restoreID,
              recovery.endReason == .appQuit
        else { return }

        restoreGate.cancel(restoreID)
        pendingRestore = nil
        stopRestoreMonitor()
        recovery.id = nil
        recovery.waitsForCompletion = false
        recovery.endReason = currentSession == nil ? nil : .manual
        _ = beginRestore(recovery)
    }

    private func refreshedSleepOverride() -> Bool? {
        systemMonitor?.refresh()
        refreshSystemFlags()
        return overrideStateVerified ? overrideActive : nil
    }

    private func cancelPendingRestoreForSleepTransition() {
        if let restoreID = pendingRestore?.id {
            restoreGate.cancel(restoreID)
            if terminationRestoreGeneration == restoreID {
                terminationPending = false
                terminationRestoreGeneration = nil
            }
        }
        pendingRestore = nil
        stopRestoreMonitor()
    }

    private func stopRestoreMonitor() {
        restoreMonitorTask?.cancel()
        restoreMonitorTask = nil
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
        scheduledWakeReconciliation.invalidate()
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
        guard !terminationPending,
              !uninstallInProgress,
              sleepTerminationGeneration == nil,
              phase == .disarmed,
              currentSession == nil,
              pendingArm == nil,
              pendingRestore == nil,
              armRequestsInFlight == 0,
              sleepPresentation == .outsideOverride
        else { return }
        guard helperState.isUsable else {
            lastError = "The current helper is unavailable or incompatible. Open Setup before restoring the outside sleep override."
            requestMainWindow()
            return
        }
        guard refreshedSleepOverride() == true,
              sleepPresentation == .outsideOverride
        else {
            lastError = "Lidless could not freshly verify the outside sleep override. Check the system state and try again."
            publishWidget()
            return
        }

        _ = beginRestore(PendingRestore(
            actuation: .repairOverride,
            options: HelperDisarmOptions(
                forceSleep: false,
                reason: "repairing outside sleep override"
            ),
            forceSleepFollowUp: nil,
            waitsForCompletion: false,
            endReason: nil,
            notificationTitle: nil,
            notificationBody: nil,
            notificationSound: false,
            playChime: false,
            allowsUnownedExternalOverrideCompletion: false,
            completionError: nil
        ))
    }

    func installHelper() async {
        beginHelperLifecycleOperation()
        defer { endHelperLifecycleOperation() }
        do {
            try await helper.install()
        } catch {
            lastError = "Helper install failed: \(error.localizedDescription)"
        }
        await helper.refreshInstallState()
    }

    func refreshHelperState() async {
        await refreshHelperInstallState()
        if (phase == .armed || phase == .arming),
           !helperState.isUsable {
            invalidateHelperSessionProof()
            publishWidget()
            startTerminalRecoveryAfterHelperProofLoss(
                "The current helper is no longer eligible to supervise this keep-awake request."
            )
        }
    }

    func openApprovalSettings() {
        helper.openApprovalSettings()
    }

    /// Full uninstall: restore pmset state, remove helper + its data,
    /// deregister the daemon, drop login item, delete app data.
    /// Returns an error message, or nil on success.
    func uninstall() async -> String? {
        guard !uninstallInProgress else {
            return "Helper removal is already in progress."
        }

        uninstallInProgress = true
        beginHelperLifecycleOperation()
        defer {
            endHelperLifecycleOperation()
            uninstallInProgress = false
        }

        if phase == .armed {
            await disarm()
        }
        guard phase == .disarmed, pendingRestore == nil else {
            return "Normal sleep has not been verified yet. Lidless is keeping the helper installed while recovery continues."
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
            body: "Helper and Lidless data removed. Drag Lidless.app to the Trash to finish."
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
        scheduledWakeReconciliation.invalidate()
        invalidateHelperSessionProof()
        overrideStateVerified = false
        let transitionPersisted = publishWidget()
        let detail = transitionPersisted
            ? "The helper connection changed, so Lidless ended the keep-awake session instead of re-arming it."
            : "The helper connection changed and the widget safety transition could not be persisted. Lidless ended the keep-awake session instead of re-arming it."
        startTerminalRecoveryAfterHelperProofLoss(detail)
    }

    /// Loss of live helper proof is a terminal safety event, not continuity
    /// authorization. In particular, a user or another safety tool restoring
    /// `disablesleep 0` must never be automatically reversed by a re-arm.
    private func startTerminalRecoveryAfterHelperProofLoss(_ detail: String) {
        guard phase == .armed || phase == .arming else {
            if phase == .disarming { startRestoreMonitor() }
            return
        }
        pendingArm = nil
        suppressCurrentScheduleOccurrence()
        _ = beginRestore(PendingRestore(
            options: HelperDisarmOptions(forceSleep: false, reason: "helper proof lost"),
            endReason: currentSession == nil ? nil : .helperProofLost,
            notificationTitle: config.behavior.notifyOnStateChanges ? "Keep-awake ended" : nil,
            notificationBody: config.behavior.notifyOnStateChanges
                ? "Lidless could no longer prove the sleep override, so it restored normal sleep."
                : nil,
            notificationSound: false,
            playChime: false,
            allowsUnownedExternalOverrideCompletion: currentSession == nil,
            completionError: detail
        ))
    }

    /// A failed or terminal scheduled arm is suppressed for the rest of its
    /// current window. Otherwise the 15-second automation tick could
    /// immediately recreate the intent that safety recovery just ended.
    private func suppressCurrentScheduleOccurrence() {
        if let occurrence = scheduleOccurrence {
            suppressedOccurrence = occurrence
        } else if config.scheduleAutomationEnabled,
                  let active = ScheduleEngine.activeOccurrence(
                      windows: config.schedules,
                      at: Date(),
                      calendar: .current
                  ) {
            suppressedOccurrence = active
        }
        scheduleOccurrence = nil
    }

    private func resyncAfterWake() {
        recordSleepTransition()
        systemMonitor?.refresh()
        refreshSystemFlags()
        // Wake may only advance terminal recovery. A session that crossed a
        // sleep boundary can never regain helper proof from a status poll.
        scheduleSleepTerminationRestore()
        publishWidget()
    }

    /// Launch reconciliation: helper-owned supervision or unfinished recovery
    /// without a matching app session must converge through the same verified
    /// normal-sleep coordinator as every other terminal path.
    private func launchReconciliationContext() -> LaunchReconciliationSafety.Context {
        LaunchReconciliationSafety.Context(
            isDisarmed: phase == .disarmed,
            hasCurrentSession: currentSession != nil,
            hasQueuedArmIntent: pendingArm != nil || scheduleOccurrence != nil,
            hasPendingRestore: pendingRestore != nil,
            armRequestsInFlight: armRequestsInFlight,
            terminationPending: terminationPending,
            uninstallInProgress: uninstallInProgress,
            sleepTerminationInProgress: sleepTerminationGeneration != nil,
            helperReachable: helperState.isReachable,
            helperProofEpoch: helperProofEpoch,
            helperLifecycleEpoch: helperLifecycleEpoch,
            helperLifecycleOperationsInFlight: helperLifecycleOperationsInFlight,
            sleepGeneration: sleepGeneration
        )
    }

    private func reconcileWithHelper() async {
        let initial = launchReconciliationContext()
        let initialHelperState = helperState
        guard LaunchReconciliationSafety.canQuery(initial) else { return }
        guard let status = try? await helper.status() else { return }

        switch LaunchReconciliationSafety.decide(
            initial: initial,
            current: launchReconciliationContext(),
            helperStateUnchanged: helperState == initialHelperState,
            status: status
        ) {
        case .abandon:
            return
        case .none:
            break
        case .restore(let cancelQueuedArmIntent):
            if cancelQueuedArmIntent {
                pendingArm = nil
                suppressCurrentScheduleOccurrence()
            }
            guard beginRestore(PendingRestore(
                options: HelperDisarmOptions(
                    forceSleep: false,
                    reason: "unfinished helper recovery found at app launch"
                ),
                endReason: nil,
                notificationTitle: "Normal sleep verified",
                notificationBody: "Lidless found unfinished helper recovery from a previous run and verified normal sleep.",
                notificationSound: false,
                playChime: false,
                completionError: nil
            )) != nil else { return }
            refreshSystemFlags()
            publishWidget()
            return
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
                let observedOverride: Bool? = simulated.sleepDisabled
                overrideActive = observedOverride ?? false
                overrideStateVerified = true
                if phase == .armed, observedOverride != true {
                    invalidateHelperSessionProof()
                    startTerminalRecoveryAfterHelperProofLoss(
                        "The system sleep override changed or could no longer be verified."
                    )
                }
            }
        } else if let systemMonitor {
            lidClosed = systemMonitor.lidClosed
            hasLid = systemMonitor.hasLid
            if lastOverrideRevision != systemMonitor.overrideRevision {
                lastOverrideRevision = systemMonitor.overrideRevision
                let observedOverride = systemMonitor.overrideActive
                overrideStateVerified = observedOverride != nil
                overrideActive = observedOverride ?? false
                if phase == .armed, observedOverride != true {
                    invalidateHelperSessionProof()
                    startTerminalRecoveryAfterHelperProofLoss(
                        "The system sleep override changed or could no longer be verified."
                    )
                }
            }
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
        guard phase == .armed,
              sleepPresentation == .verifiedArmed
        else { return }

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

        guard !terminationPending,
              phase == .disarmed,
              pendingArm == nil,
              helperState.isUsable,
              sleepPresentation == .verifiedNormal
        else {
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
    /// reconciliation against reply-committed evidence; an unusable helper
    /// pauses (never blindly cancels) maintenance.
    private func maintainScheduledWake() {
        guard !isSimulation, helperState.isUsable else { return }

        let next = config.scheduleAutomationEnabled
            ? ScheduleEngine.nextStart(windows: config.schedules, after: Date(), calendar: .current)
            : nil
        let desired: Date? = next.map { $0.start.addingTimeInterval(-60) }

        guard let request = scheduledWakeReconciliation.begin(desired: desired) else {
            return
        }
        Task { [weak self] in
            guard let self else { return }
            guard scheduledWakeReconciliation.isCurrent(request.id) else {
                scheduledWakeReconciliation.discardUndispatched(request.id)
                return
            }
            do {
                try await helper.scheduleWake(request.desired)
                scheduledWakeReconciliation.complete(request.id, outcome: .confirmed)
            } catch HelperClientError.rejected(_) {
                scheduledWakeReconciliation.complete(request.id, outcome: .rejected)
            } catch {
                scheduledWakeReconciliation.complete(request.id, outcome: .uncertain)
            }
        }
    }

    // MARK: - Heartbeat

    private func startHeartbeat() {
        stopHeartbeat()
        let generation = heartbeatGeneration
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(HelperArmOptions.heartbeatInterval))
                guard let self,
                      !Task.isCancelled,
                      self.heartbeatGeneration == generation,
                      self.phase == .armed
                else { return }
                let proofEpoch = self.helperProofEpoch
                do {
                    let reply = try await self.helper.heartbeat()
                    guard !Task.isCancelled,
                          self.heartbeatGeneration == generation,
                          self.phase == .armed
                    else { return }
                    if proofEpoch != self.helperProofEpoch
                        || !SleepOverrideSafety.isArmProven(reply) {
                        self.invalidateHelperSessionProof()
                        self.overrideStateVerified = false
                        self.publishWidget()
                        self.startTerminalRecoveryAfterHelperProofLoss(
                            reply.error ?? "The helper could no longer prove the live sleep override."
                        )
                        return
                    } else {
                        self.helperSessionProven = true
                        self.systemMonitor?.refresh()
                        self.refreshSystemFlags()
                        self.publishWidget()
                    }
                } catch {
                    guard !Task.isCancelled,
                          self.heartbeatGeneration == generation,
                          self.phase == .armed
                    else { return }
                    self.invalidateHelperSessionProof()
                    self.overrideStateVerified = false
                    self.publishWidget()
                    self.startTerminalRecoveryAfterHelperProofLoss(
                        "The helper heartbeat failed (\(error.localizedDescription))."
                    )
                    return
                }
            }
        }
    }

    private func stopHeartbeat() {
        heartbeatGeneration = UUID()
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

    @discardableResult
    private func publishWidget() -> Bool {
        let projected = projectedCutoff
        let widgetStatusLine: String
        switch sleepPresentation {
        case .restoring:
            widgetStatusLine = "Restoring normal sleep…"
        case .verifyingArm:
            widgetStatusLine = "Verifying sleep override…"
        case .verifiedArmed:
            widgetStatusLine = projected?.label ?? "Until disarmed"
        case .outsideOverride:
            widgetStatusLine = "Sleep override active — not Lidless"
        case .unknown:
            widgetStatusLine = "Sleep state unknown"
        case .verifiedNormal:
            widgetStatusLine = "Sleeping normally"
        }
        let snapshot = WidgetSnapshot(
            // Keep the legacy bit internally consistent with the v2 proof.
            // WidgetStore removes the v1 file before publishing this schema.
            armed: sleepPresentation == .verifiedArmed,
            statusLine: widgetStatusLine,
            batteryPercent: battery.percent,
            isCharging: battery.isCharging,
            drainPerHour: drainPerHour,
            projectedCutoff: projected?.date,
            projectedCutoffLabel: projected?.label,
            overrideActive: overrideActive,
            overrideStateVerified: overrideStateVerified,
            sleepPresentation: sleepPresentation,
            recentSamples: Array(rollingSamples.suffix(WidgetStore.maxSamples)),
            updatedAt: Date()
        )
        return widgetPublisher.publish(snapshot)
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
