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
    /// Blocks scheduled-wake mutation while launch status is suspended. A
    /// startup refresh may have cached `.ready`, but the second live query can
    /// still reveal a stale or different-wire responder.
    private var launchReconciliationInFlight = false
    private(set) var drainPerHour: Double?
    private(set) var rollingSamples: [BatterySample] = []

    /// Ticked by the 15s loop so time-derived computed properties refresh.
    private(set) var now = Date()

    var helperState: HelperInstallState { helper.installState }

    /// No new arm may replace a prior session journal or proceed while its
    /// durability is unknown. Restore/disarm remains available independently.
    var sessionEvidenceRequiresReconciliation: Bool {
        launchReconciliationInFlight
            || sessionStore.unresolvedSession != nil
            || sessionStore.lastLoadResult.errorMessage != nil
            || sessionStore.lastSaveResult.errorMessage != nil
    }

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
    private var thermalStrikeTracker = ThermalStrikeTracker()
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
    /// A different-wire reply cannot clear a terminal generation while an arm
    /// is still in flight. Latch that status and wait without sending another
    /// unsupported mutation; once the late arm settles, surface manual recovery.
    private var sleepTerminationIncompatibleWireStatus: HelperStatus?
    /// The restore generation whose automatic recovery terminally stopped
    /// because the responder uses an unsupported wire protocol. Terminalizing
    /// deliberately preserves `pendingRestore` and `.disarming` to keep the
    /// session and crash journal live, so the fence cannot be represented by
    /// the absence of a monitor task: any later helper-proof loss restarts one
    /// from exactly that state. Generations are UUID-identified, so a retired
    /// value can never alias a newer one and needs no clearing.
    private var manualRecoveryGeneration: NonSleepRestoreGeneration?
    /// The sleep-transition fence has no restore generation to latch: that path
    /// already cleared `pendingRestore`. Its self-invalidating key is the sleep
    /// generation, which `recordSleepTransition` bumps, so a later transition
    /// can never inherit a stale fence.
    private var manualRecoverySleepGeneration: UInt64?
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
        /// A launch orphan remains outside live session state until a current
        /// helper reply selects its truthful terminal reason.
        var orphanEndReason: SessionEndReason? = nil
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
    /// Fences new work routed through this AppState while a helper registration
    /// request is suspended. This process-local admission control cannot
    /// cancel an already-dispatched XPC call or constrain another process.
    private var helperRegistrationInProgress = false

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
        var id: UUID
        var plan: ArmIntentPlan
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
        surfacePersistenceErrors()
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
        surfacePersistenceErrors()
        notifications.activate()
        batteryMonitor.start()
        thermalMonitor.start()
        systemMonitor?.start()
        battery = batteryMonitor.current
        thermal = thermalMonitor.reading
        processThermal = thermalMonitor.processLevel
        refreshSystemFlags()

        Task {
            guard await refreshHelperInstallState() else { return }
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

    /// A user-initiated registration passes through intermediate
    /// unclassified states by design. Surfacing them as terminal helper
    /// warnings would flash a false verdict mid-operation. Deliberately scoped
    /// to those flows — `installHelper()` holds the same exclusion — and not to
    /// a plain status refresh, which writes `installState` once at the end:
    /// folding that in would mute a real warning for the whole XPC timeout,
    /// which is longest exactly when the helper is wedged.
    var helperLifecycleWorkInProgress: Bool {
        helperRegistrationInProgress
    }

    private func refreshHelperInstallState() async -> Bool {
        guard !helperRegistrationInProgress else { return false }
        beginHelperLifecycleOperation()
        defer { endHelperLifecycleOperation() }
        await helper.refreshInstallState()
        retainRecoveryOnlyHelperStateIfNeeded()
        return true
    }

    /// Single synchronous admission boundary for accepted live helper evidence.
    /// A non-current responder may still help prove normal sleep when its wire
    /// protocol is compatible, but it must lose cached wake/arm authority before
    /// any path-specific proof, retry, completion, or return can run.
    private func retainRecoveryOnlyHelperStateIfNeeded(_ status: HelperStatus) {
        if !SleepOverrideSafety.isCurrentHelper(status) {
            helper.recordRecoveryOnlyStatus(status)
        }
        retainRecoveryOnlyHelperStateIfNeeded()
    }

    /// The same boundary for evidence the client classified itself. An
    /// install-state refresh reads live status inside `HelperClient`, so the
    /// app never sees that `HelperStatus`; routing the surviving
    /// classification through here keeps one wake-admission decision instead
    /// of a second copy of the rule. Cached scheduled-wake authority survives
    /// only an exact-current `.ready` (or `.simulated`) classification, so a
    /// stale, different-wire, unresponsive, or unclassifiable responder can
    /// never inherit a confirmation that belonged to another one. Demotes
    /// only; it never promotes.
    private func retainRecoveryOnlyHelperStateIfNeeded() {
        guard !helperState.isUsable else { return }
        scheduledWakeReconciliation.invalidate()
    }

    /// True once automatic recovery for the live generation has terminally
    /// stopped. `.disarming` then no longer means work is in progress, so
    /// user-facing copy must not promise verification Lidless will not attempt.
    var automaticRecoveryStopped: Bool {
        // Only `.disarming` can be fenced, and both keys outlive their episode
        // by design. Narrowing here keeps a retired key from reading as a live
        // fence if this is ever consulted from another context.
        guard phase == .disarming else { return false }
        if let pending = pendingRestore {
            return manualRecoveryGeneration == pending.id
        }
        // No pending restore: the only way to sit in `.disarming` is a sleep
        // transition, whose fence is keyed on the sleep generation.
        return manualRecoverySleepGeneration == sleepGeneration
    }

    /// A different wire protocol cannot safely participate in automatic
    /// recovery. Stop this generation without claiming restoration, preserve
    /// the live session/journal, and surface the manual recovery boundary.
    @discardableResult
    private func stopAutomaticRecoveryForIncompatibleWire(
        _ status: HelperStatus,
        restoreID: NonSleepRestoreGeneration? = nil
    ) -> Bool {
        guard !SleepOverrideSafety.isRecoveryCompatibleHelper(status) else {
            return false
        }
        guard armRequestsInFlight == 0 else {
            lastError = "Waiting for an in-flight arm request before automatic recovery can stop safely."
            publishWidget()
            return false
        }

        retainRecoveryOnlyHelperStateIfNeeded(status)
        // The sleep-transition caller has no generation to latch — it already
        // cleared `pendingRestore` — but its resting state is just as fenced,
        // so key that one on the sleep generation.
        manualRecoverySleepGeneration = sleepGeneration
        if let restoreID {
            // Latch before stopping the worker: the monitor can be restarted
            // from `.disarming` plus a live `pendingRestore` by any later
            // helper-proof loss, and both entry points consult this latch.
            manualRecoveryGeneration = restoreID
            restoreGate.cancel(restoreID)
            if terminationRestoreGeneration == restoreID {
                terminationPending = false
                terminationRestoreGeneration = nil
            }
            if var pending = pendingRestore,
               pending.id == restoreID {
                pending.waitsForCompletion = false
                pendingRestore = pending
            }
            stopRestoreMonitor()
        }
        lastError = "The helper changed to an unsupported wire protocol. Lidless stopped automatic recovery without claiming normal sleep. Keep the helper registered, use Setup's emergency sleep recovery, verify normal sleep, and contact Lidless support."
        // Overview does not render `lastError` and is the default pane, so a
        // bare request would surface only the `.restoring` hero — the exact
        // false impression this fence removes. Route to the pane that shows
        // the message and holds the command it tells the user to run.
        requestMainWindow(pane: .setup)
        publishWidget()
        return true
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
                sleepTerminationIncompatibleWireStatus = nil
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

            if let incompatibleStatus = sleepTerminationIncompatibleWireStatus {
                if armRequestsInFlight == 0 {
                    stopAutomaticRecoveryForIncompatibleWire(incompatibleStatus)
                    sleepTerminationGeneration = nil
                    sleepTerminationActuation = nil
                    sleepTerminationIncompatibleWireStatus = nil
                    return
                }
                lastError = "The helper changed to an unsupported wire protocol while an arm request was still settling. Lidless is preserving the recovery fence and will not send another unsupported request."
                publishWidget()
                do {
                    try await Task.sleep(for: .milliseconds(100))
                } catch {
                    return
                }
                continue
            }

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
                retainRecoveryOnlyHelperStateIfNeeded(reply.status)
                if !SleepOverrideSafety.isRecoveryCompatibleHelper(reply.status) {
                    sleepTerminationIncompatibleWireStatus = reply.status
                    if armRequestsInFlight == 0,
                       stopAutomaticRecoveryForIncompatibleWire(reply.status) {
                        sleepTerminationGeneration = nil
                        sleepTerminationActuation = nil
                        sleepTerminationIncompatibleWireStatus = nil
                        return
                    }
                    lastError = "The helper changed to an unsupported wire protocol while an arm request was still settling. Lidless is preserving the recovery fence and will not send another unsupported request."
                } else {
                    systemMonitor?.refresh()
                    refreshSystemFlags()
                    let independentlyObserved = overrideStateVerified ? overrideActive : nil
                    if SleepOverrideSafety.isRestoreProven(
                            reply,
                            independentlyObserved: independentlyObserved
                       ),
                       armRequestsInFlight == 0 {
                        let endedSession = currentSession != nil
                        var persistenceError: String?
                        pendingRestore = nil
                        stopRestoreMonitor()
                        if endedSession {
                            persistenceError = finalizeSession(endReason: .systemSlept)
                        } else {
                            stopHeartbeat()
                        }
                        sleepTerminationGeneration = nil
                        sleepTerminationActuation = nil
                        sleepTerminationIncompatibleWireStatus = nil
                        phase = .disarmed
                        lastError = persistenceError
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
                }
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
        case .verifyingArm: "Verifying keep-awake…"
        case .verifiedArmed: "Keeping this Mac awake"
        case .restoring: "Restoring normal sleep…"
        case .outsideOverride: "Sleep override outside Lidless"
        case .unknown: "System sleep is unverified"
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
            // Only the pre-classification value is silent here. `.unknown` is a
            // concluded verdict that the helper cannot be verified, so hiding
            // it would render a terminal state as an ordinary schedule.
            if helperState == .unknown {
                return "Helper status unverified"
            }
            if !helperState.isUsable, helperState != .checking {
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
        case .verifiedNormal: "moon.zzz"
        case .verifyingArm: "hourglass"
        case .verifiedArmed: "bolt"
        case .restoring: "arrow.triangle.2.circlepath"
        case .outsideOverride: "exclamationmark.triangle"
        case .unknown: "questionmark.circle"
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
        if cfg.batteryFloorEnabled, battery.state != .noBattery {
            parts.append("Floor \(cfg.batteryFloorPercent)%")
        }
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

    private func batteryPresetIsAttainable(_ source: SessionSource) -> Bool {
        BatteryPresetAdmission.isAttainable(source: source, battery: battery)
    }

    private func armIntentPlan(
        for overrides: SessionOverrides?,
        scheduledOccurrence: ScheduleEngine.Occurrence? = nil
    ) -> ArmIntentPlan {
        ArmIntentPlan(
            cutoffs: config.cutoffs.applying(overrides),
            helperOptions: HelperArmOptions(
                lowPowerMode: config.behavior.lowPowerModeWhileArmed,
                tcpKeepAlive: config.behavior.tcpKeepAliveWhileArmed
            ),
            scheduledOccurrence: scheduledOccurrence
        )
    }

    private func liveScheduledOccurrence(
        for source: SessionSource,
        at reference: Date = Date()
    ) -> ScheduleEngine.Occurrence? {
        guard case .schedule(let expectedWindowID) = source,
              config.scheduleAutomationEnabled,
              let occurrence = ScheduleEngine.activeOccurrence(
                  windows: config.schedules,
                  at: reference,
                  calendar: .current
              ),
              occurrence.windowID == expectedWindowID
        else { return nil }
        return occurrence
    }

    private func currentArmIntentPlan(
        for pending: PendingArm,
        at reference: Date = Date()
    ) -> ArmIntentPlan {
        armIntentPlan(
            for: pending.overrides,
            scheduledOccurrence: liveScheduledOccurrence(
                for: pending.source,
                at: reference
            )
        )
    }

    func beginArmFlow(preset: ArmPreset? = nil) {
        guard !sessionEvidenceRequiresReconciliation else {
            lastError = "Lidless is finishing session-evidence reconciliation. Keep Awake will be available after the prior record is durable."
            return
        }
        guard !terminationPending,
              !helperRegistrationInProgress,
              phase == .disarmed,
              pendingArm == nil
        else { return }
        lastError = nil

        guard sleepPresentation == .verifiedNormal else {
            lastError = "Lidless must verify that normal sleep is enabled before arming."
            return
        }

        guard helperState.isUsable else {
            requestMainWindow()
            return
        }

        // The confirmation and preset decision must start from a synchronous
        // power-source read, not a cached event or the launch-time unknown.
        batteryMonitor.refresh()
        battery = batteryMonitor.current

        let overrides = preset?.overrides()
        let source: SessionSource = preset.map { .preset($0) } ?? .manual
        guard batteryPresetIsAttainable(source) else {
            lastError = "The 20% preset doesn't apply because this Mac has no internal battery."
            return
        }
        let assessmentAt = Date()
        let plan = armIntentPlan(for: overrides)
        let assessment = CutoffEngine.assessArm(
            config: plan.cutoffs,
            battery: battery,
            thermal: thermal,
            processThermal: processThermal,
            at: assessmentAt
        )
        let pending = PendingArm(
            id: UUID(),
            plan: plan,
            overrides: overrides,
            source: source,
            assessment: assessment,
            projection: projection(for: plan.cutoffs),
            createdAt: assessmentAt
        )
        pendingArm = pending

        // Presets are explicit intent — skip the confirm card when there's
        // nothing to warn about. The master control always shows the card.
        if preset != nil, assessment == .ok {
            Task { await confirmArm(expectedIntentID: pending.id) }
        }
    }

    func cancelArmFlow() {
        guard let pending = pendingArm else { return }
        if case .schedule = pending.source {
            suppressedOccurrence = pending.plan.scheduledOccurrence
            scheduleOccurrence = nil
        }
        pendingArm = nil
    }

    /// Clear history transactionally. A failed write restores the in-memory
    /// rows so the user can retry without restarting and surfaces the error at
    /// the same product boundary as every other persistence operation.
    @discardableResult
    func clearSessionHistory() -> Bool {
        let previousSaveError = sessionStore.lastSaveResult.errorMessage
        let result = sessionStore.clearHistory()
        if let message = result.errorMessage {
            lastError = message
            return false
        }
        if sessionStore.lastLoadResult.errorMessage != nil {
            // Clearing valid history does not repair an unreadable session
            // journal. Keep the fail-closed admission reason visible.
            surfacePersistenceErrors()
        } else if let previousSaveError, lastError == previousSaveError {
            lastError = config.lastPersistenceError
        }
        return true
    }

    func refreshPendingProjection() {
        guard let pending = pendingArm else { return }
        guard batteryPresetIsAttainable(pending.source) else {
            pendingArm = nil
            scheduleOccurrence = nil
            lastError = "The 20% preset no longer applies because no internal battery is present."
            return
        }
        let assessmentAt = Date()
        let currentPlan = currentArmIntentPlan(
            for: pending,
            at: assessmentAt
        )
        if case .schedule = pending.source,
           currentPlan.scheduledOccurrence == nil {
            pendingArm = nil
            scheduleOccurrence = nil
            return
        }
        let assessment = CutoffEngine.assessArm(
            config: currentPlan.cutoffs,
            battery: battery,
            thermal: thermal,
            processThermal: processThermal,
            at: assessmentAt
        )
        let retainsConfirmation = pending.plan == currentPlan
            && pending.assessment == assessment
        if case .schedule = pending.source,
           !retainsConfirmation {
            pendingArm = nil
            scheduleOccurrence = nil
            return
        }
        pendingArm = PendingArm(
            id: retainsConfirmation ? pending.id : UUID(),
            plan: currentPlan,
            overrides: pending.overrides,
            source: pending.source,
            assessment: assessment,
            projection: projection(for: currentPlan.cutoffs),
            createdAt: pending.createdAt
        )
    }

    private func projection(for cfg: CutoffConfig) -> ArmProjection {
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
            timeToEmpty = TimeInterval(minutes) * 60
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
        guard let expectedIntentID = pendingArm?.id else { return }
        await confirmArm(expectedIntentID: expectedIntentID)
    }

    func confirmArm(expectedIntentID: UUID) async {
        guard !terminationPending,
              !helperRegistrationInProgress,
              let intent = pendingArm,
              phase == .disarmed
        else { return }
        guard expectedIntentID == intent.id else { return }
        guard !sessionEvidenceRequiresReconciliation else {
            pendingArm = nil
            scheduleOccurrence = nil
            lastError = "Lidless is finishing session-evidence reconciliation. Keep Awake will be available after the prior record is durable."
            return
        }
        guard ArmIntentConfirmationSafety.authorizes(
            expectedIntentID: expectedIntentID,
            currentIntentID: intent.id,
            confirmedPlan: intent.plan,
            currentPlan: currentArmIntentPlan(for: intent)
        ) else {
            refreshPendingProjection()
            lastError = "Safety settings changed. Review the updated plan before arming."
            return
        }
        guard intent.assessment.allowsArm else { return }
        guard batteryPresetIsAttainable(intent.source) else {
            pendingArm = nil
            scheduleOccurrence = nil
            lastError = "The 20% preset no longer applies because no internal battery is present."
            return
        }
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
        guard await refreshHelperInstallState() else {
            if phase == .arming {
                phase = .disarmed
                pendingArm = nil
                scheduleOccurrence = nil
                lastError = "Couldn't arm because helper removal began during verification."
                publishWidget()
            }
            return
        }
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

        // The configured thermal guard is a safety promise. Poll it at the
        // mutation boundary instead of relying on a cached nominal sample.
        let thermalBoundaryAt = Date()
        await thermalMonitor.pollNow(notBefore: thermalBoundaryAt)
        thermal = thermalMonitor.reading
        processThermal = thermalMonitor.processLevel
        guard phase == .arming,
              eligibilityEpoch == helperProofEpoch,
              helperState.isUsable else {
            if phase == .arming {
                phase = .disarmed
                pendingArm = nil
                scheduleOccurrence = nil
                lastError = "Couldn't arm because safety state changed during thermal verification."
                publishWidget()
            }
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

        // Re-read battery evidence after every suspension and immediately
        // before the final assessment. No await separates this assessment
        // from helper arm dispatch.
        batteryMonitor.refresh()
        battery = batteryMonitor.current

        // Cancellation, expiry, and battery events can all run while the
        // authorization/helper probes are suspended. Honor only the same live
        // intent and the same assessment the user actually confirmed.
        guard let pending = pendingArm,
              pending.id == intent.id,
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
        guard ArmIntentConfirmationSafety.authorizes(
            expectedIntentID: expectedIntentID,
            currentIntentID: pending.id,
            confirmedPlan: intent.plan,
            currentPlan: currentArmIntentPlan(for: pending)
        ) else {
            phase = .disarmed
            refreshPendingProjection()
            lastError = "Safety settings changed during verification. Review the updated plan before arming."
            publishWidget()
            return
        }
        let freshAssessment = CutoffEngine.assessArm(
            config: pending.plan.cutoffs,
            battery: battery,
            thermal: thermal,
            processThermal: processThermal,
            at: Date()
        )
        guard batteryPresetIsAttainable(pending.source) else {
            phase = .disarmed
            pendingArm = nil
            scheduleOccurrence = nil
            lastError = "Couldn't arm because the 20% preset no longer has an internal battery endpoint."
            publishWidget()
            return
        }
        if case .refusedBelowFloor = freshAssessment {
            phase = .disarmed
            pendingArm = nil
            scheduleOccurrence = nil
            lastError = "Couldn't arm because the battery reached the safety floor."
            publishWidget()
            return
        }
        if case .refusedBatteryTelemetryUnavailable = freshAssessment {
            phase = .disarmed
            pendingArm = nil
            scheduleOccurrence = nil
            lastError = "Couldn't arm because the battery state could not be verified."
            publishWidget()
            return
        }
        if case .refusedThermalTelemetryUnavailable = freshAssessment {
            phase = .disarmed
            pendingArm = nil
            scheduleOccurrence = nil
            lastError = "Couldn't arm because the thermal safety state could not be verified."
            publishWidget()
            return
        }
        if case .refusedThermalPressure(let detail) = freshAssessment {
            phase = .disarmed
            pendingArm = nil
            scheduleOccurrence = nil
            lastError = "Couldn't arm because thermal protection is already triggered: \(detail)."
            publishWidget()
            return
        }
        guard freshAssessment == intent.assessment else {
            phase = .disarmed
            pendingArm = nil
            scheduleOccurrence = nil
            lastError = "Safety conditions changed. Review the updated warning before arming."
            publishWidget()
            return
        }

        let options = pending.plan.helperOptions
        // The mutation dispatch is the commit point: remove the pending card
        // before the XPC suspension so Cancel or a battery refresh cannot
        // mutate a request that is already being applied by the helper.
        pendingArm = nil
        let armProofEpoch = eligibilityEpoch
        let armSleepGeneration = sleepGeneration

        do {
            let reply = try await trackedArm(options)
            let responseIsOwned = phase == .arming
                && armSleepGeneration == sleepGeneration
                && armProofEpoch == helperProofEpoch
            // A superseded reply is still consumed below: `failedArmDisposition`
            // may disarm the phase or start recovery, because a failed arm can
            // have partially applied and must never be left unrecovered. So it
            // crosses the boundary too. The boundary only demotes, and the live
            // re-classification at the end of this branch re-promotes an
            // exact-current responder, so this is the fail-closed direction.
            retainRecoveryOnlyHelperStateIfNeeded(reply.status)
            guard responseIsOwned,
                  helperState.isUsable,
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
                    let restoreID = beginRestore(PendingRestore(
                        options: HelperDisarmOptions(forceSleep: false, reason: "recovering failed arm"),
                        endReason: nil,
                        notificationTitle: nil,
                        notificationBody: nil,
                        notificationSound: false,
                        playChime: false,
                        allowsUnownedExternalOverrideCompletion: true,
                        completionError: message
                    ))
                    if let restoreID {
                        stopAutomaticRecoveryForIncompatibleWire(
                            reply.status,
                            restoreID: restoreID
                        )
                    }
                }
                _ = await refreshHelperInstallState()
                return
            }

            // The arm reply proves the helper mutation, not that safety
            // evidence sampled before XPC dispatch stayed current throughout
            // the suspension. Re-read battery evidence and revalidate the
            // thermal sample before accepting a session; otherwise enter the
            // verified-restoration coordinator used by every other cutoff.
            batteryMonitor.refresh()
            battery = batteryMonitor.current
            let postArmAssessment = CutoffEngine.assessArm(
                config: pending.plan.cutoffs,
                battery: battery,
                thermal: thermal,
                processThermal: processThermal,
                at: Date()
            )
            let postArmAssessmentAccepted: Bool
            switch pending.source {
            case .schedule:
                postArmAssessmentAccepted = postArmAssessment.allowsArm
            case .manual, .preset:
                // A user-confirmed warning cannot silently change while the
                // XPC request is suspended.
                postArmAssessmentAccepted = postArmAssessment == freshAssessment
            }
            guard pending.plan == currentArmIntentPlan(for: pending),
                  postArmAssessmentAccepted,
                  batteryPresetIsAttainable(pending.source) else {
                // Before mutation, transient telemetry stays retryable. Once
                // a helper arm was proven, suppress this schedule occurrence
                // so repeated arm/restore mutations cannot flap all window.
                suppressCurrentScheduleOccurrence()
                helperSessionProven = true
                _ = beginRestore(PendingRestore(
                    options: HelperDisarmOptions(
                        forceSleep: false,
                        reason: "safety evidence changed during arm"
                    ),
                    endReason: nil,
                    notificationTitle: nil,
                    notificationBody: nil,
                    notificationSound: false,
                    playChime: false,
                    completionError: "The keep-awake request was restored because its confirmed safety plan or evidence changed while arming."
                ))
                return
            }

            // A persistence operation can fail while the XPC arm request is
            // suspended. The helper mutation is then restored without
            // replacing any prior unresolved session evidence.
            guard !sessionEvidenceRequiresReconciliation else {
                suppressCurrentScheduleOccurrence()
                helperSessionProven = true
                _ = beginRestore(PendingRestore(
                    options: HelperDisarmOptions(
                        forceSleep: false,
                        reason: "session evidence reconciliation began during arm"
                    ),
                    endReason: nil,
                    notificationTitle: nil,
                    notificationBody: nil,
                    notificationSound: false,
                    playChime: false,
                    completionError: "The keep-awake request was restored because prior session evidence still requires durable reconciliation."
                ))
                return
            }
            helperSessionProven = true

            let startedAt = Date()
            let cfg = pending.plan.cutoffs
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

            if case .schedule = pending.source {
                // scheduleOccurrence set by the automation path before calling.
            } else {
                scheduleOccurrence = nil
            }

            // Never present an armed session until its crash journal is
            // durable. If the write fails, immediately enter the same
            // verified-restoration coordinator used by every safety cutoff.
            let checkpointResult = sessionStore.checkpoint(session)
            let checkpointAccepted = checkpointResult == .succeeded
                || (isSimulation && checkpointResult == .notAttempted)
            guard checkpointAccepted else {
                surfacePersistenceFailure(checkpointResult)
                suppressCurrentScheduleOccurrence()
                _ = beginRestore(PendingRestore(
                    options: HelperDisarmOptions(
                        forceSleep: false,
                        reason: "active-session journal could not be persisted"
                    ),
                    endReason: .persistenceFailure,
                    notificationTitle: nil,
                    notificationBody: nil,
                    notificationSound: false,
                    playChime: false,
                    completionError: checkpointResult.errorMessage
                        ?? "Lidless restored normal sleep because the active-session record could not be made durable."
                ))
                return
            }

            phase = .armed
            thermalStrikeTracker.reset()
            warnedKinds = []
            lastSessionSampleAt = startedAt
            lastError = nil
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
            _ = await refreshHelperInstallState()
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
        guard !helperRegistrationInProgress else { return false }
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
        guard !helperRegistrationInProgress, phase == .armed else { return false }
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

            retainRecoveryOnlyHelperStateIfNeeded(reply.status)
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
            case .manualRecoveryRequired:
                stopAutomaticRecoveryForIncompatibleWire(
                    reply.status,
                    restoreID: restoreID
                )
                return false
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

        var persistenceError: String?
        if let endReason = pending.endReason {
            persistenceError = finalizeSession(endReason: endReason)
        } else {
            stopHeartbeat()
        }
        if let orphanEndReason = pending.orphanEndReason {
            let result = sessionStore.archiveOrphanedSession(endReason: orphanEndReason)
            surfacePersistenceFailure(result)
            persistenceError = result.errorMessage ?? persistenceError
        }

        phase = .disarmed
        lastError = pending.completionError ?? persistenceError
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
              let restoreID = pendingRestore?.id,
              manualRecoveryGeneration != restoreID
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
                  pending.id == restoreID,
                  // A generation fenced for an unsupported wire protocol must
                  // never dispatch another privileged mutation, and its 5s
                  // retry must never overwrite the manual-recovery instruction.
                  manualRecoveryGeneration != restoreID
            else { return }

            if shouldDelay {
                do {
                    try await Task.sleep(for: .seconds(5))
                } catch {
                    return
                }
                // Re-check the fence here too, so the loop is self-fencing
                // rather than relying on an external `stopRestoreMonitor()`.
                guard pendingRestore?.id == restoreID,
                      manualRecoveryGeneration != restoreID
                else { return }
            }
            shouldDelay = true

            guard armRequestsInFlight == 0 else {
                lastError = "Waiting for an in-flight arm request before normal sleep recovery can continue."
                publishWidget()
                continue
            }

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

                retainRecoveryOnlyHelperStateIfNeeded(reply.status)
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
                    case .retry, .manualRecoveryRequired,
                         .dispatchForceSleep, .awaitFinalProof:
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
                    if pending.forceSleepFollowUp != nil,
                       !SleepOverrideSafety.isCurrentHelper(reply.status) {
                        markForceSleepFollowUpSkipped(restoreID: restoreID)
                    }
                    completePendingRestore(expectedID: restoreID)
                    return
                case .manualRecoveryRequired:
                    stopAutomaticRecoveryForIncompatibleWire(
                        reply.status,
                        restoreID: restoreID
                    )
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
            retainRecoveryOnlyHelperStateIfNeeded(reply.status)
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
            case .manualRecoveryRequired:
                stopAutomaticRecoveryForIncompatibleWire(
                    reply.status,
                    restoreID: restoreID
                )
                return true
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

    private func markForceSleepFollowUpSkipped(
        restoreID: NonSleepRestoreGeneration
    ) {
        guard var pending = pendingRestore,
              pending.id == restoreID,
              pending.forceSleepFollowUp != nil
        else { return }
        let message = "The follow-up sleep request was skipped because the responder did not match this app's current safety revision. Normal sleep was verified."
        pending.forceSleepFollowUp = nil
        if pending.notificationTitle != nil {
            pending.notificationTitle = "Keep-awake ended"
            pending.notificationBody = message
        }
        pending.notificationSound = false
        pending.playChime = false
        pending.completionError = message
        pendingRestore = pending
        lastError = message
    }

    private func markForceSleepFollowUpUnverified(
        restoreID: NonSleepRestoreGeneration,
        detail: String
    ) {
        guard var pending = pendingRestore,
              pending.id == restoreID
        else { return }
        let message = "The follow-up sleep request was ambiguous (\(detail)). Lidless did not repeat it."
        if pending.notificationTitle != nil {
            pending.notificationTitle = "Keep-awake ended"
            pending.notificationBody = message
        }
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

    @discardableResult
    private func finalizeSession(endReason: SessionEndReason) -> String? {
        stopHeartbeat()
        nextTimeCutoff = nil
        scheduleOccurrence = nil

        guard var session = currentSession else { return nil }
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
        surfacePersistenceFailure(sessionStore.append(session))
        let persistenceError = sessionStore.lastSaveResult.errorMessage
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
        return persistenceError
    }

    func cutoffLabel(_ reason: CutoffReason) -> String {
        switch reason {
        case .thermal(let detail): "Thermal protection: \(detail)"
        case .thermalTelemetryUnavailable: "Thermal safety state could not be verified"
        case .batteryTelemetryUnavailable: "Battery state could not be verified"
        case .batteryFloor(let percent, let floor): "Battery reached \(percent)% (floor \(floor)%)"
        case .offTime: "Reached the scheduled off-time"
        case .durationElapsed: "Duration limit reached"
        case .scheduleEnded: "Scheduled window ended"
        }
    }

    // MARK: - Repair / uninstall

    func repairOverride() async {
        guard !terminationPending,
              !helperRegistrationInProgress,
              sleepTerminationGeneration == nil,
              phase == .disarmed,
              currentSession == nil,
              pendingArm == nil,
              pendingRestore == nil,
              armRequestsInFlight == 0,
              sleepPresentation == .outsideOverride
        else { return }

        // Recovery may be performed by the exact current wire protocol even
        // when its safety behavior revision is stale, but never from cached
        // eligibility alone. Recheck the live responder before selecting the
        // de-risking operation, then revalidate every app-local exclusion that
        // could have changed while the probe was suspended.
        guard await refreshHelperInstallState() else { return }
        guard !terminationPending,
              !helperRegistrationInProgress,
              sleepTerminationGeneration == nil,
              phase == .disarmed,
              currentSession == nil,
              pendingArm == nil,
              pendingRestore == nil,
              armRequestsInFlight == 0,
              sleepPresentation == .outsideOverride
        else { return }
        guard helperState.isRecoveryUsable else {
            lastError = "The helper is unavailable or uses a different wire protocol. Automatic recovery is unavailable. Open Setup for emergency sleep recovery. Keep the helper registered and contact Lidless support for a separately reviewed removal procedure."
            requestMainWindow(pane: .setup)
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
        guard !terminationPending,
              !helperRegistrationInProgress,
              helperLifecycleOperationsInFlight == 0,
              phase == .disarmed,
              currentSession == nil,
              pendingArm == nil,
              pendingRestore == nil,
              armRequestsInFlight == 0,
              sleepTerminationGeneration == nil
        else {
            lastError = "Wait for active recovery or helper work to finish before installing the helper."
            return
        }
        lastError = nil
        // Installation can change which responder is admitted. Drop app-local
        // scheduled-wake reply evidence first, then reconcile only after the
        // lifecycle exclusion is released and an exact-current helper replies.
        scheduledWakeReconciliation.invalidate()
        // Exclude arm confirmation and repair while the user-authorized
        // registration request is suspended.
        helperRegistrationInProgress = true
        beginHelperLifecycleOperation()
        defer {
            endHelperLifecycleOperation()
            helperRegistrationInProgress = false
            maintainScheduledWake()
        }
        do {
            try await helper.install()
        } catch {
            lastError = "Helper install failed: \(error.localizedDescription)"
        }
        await helper.refreshInstallState()
    }

    func refreshHelperState() async {
        guard await refreshHelperInstallState() else { return }
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

    /// Public helper cleanup is intentionally unavailable. Keep this API as an
    /// immediate refusal for older callers; it performs no state transition or
    /// helper, login-item, notification, schedule, or persistence mutation.
    func uninstall() async -> String? {
        return "Automatic helper cleanup is disabled. No state was changed by this request. Keep the helper registered. If normal sleep is unverified, use Setup's emergency recovery command and verify the registry result, then contact support for a reviewed removal procedure."
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
        refreshPendingProjection()
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
            helperRegistrationInProgress: helperRegistrationInProgress,
            sleepTerminationInProgress: sleepTerminationGeneration != nil,
            helperReachable: helperState.isRecoveryUsable,
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
        guard !launchReconciliationInFlight else { return }
        launchReconciliationInFlight = true
        defer { launchReconciliationInFlight = false }
        guard let status = try? await helper.status() else { return }

        let current = launchReconciliationContext()
        let helperStateUnchanged = helperState == initialHelperState
        guard LaunchReconciliationSafety.responseBelongsToContext(
            initial: initial,
            current: current,
            helperStateUnchanged: helperStateUnchanged
        ) else { return }
        retainRecoveryOnlyHelperStateIfNeeded(status)
        let decision = LaunchReconciliationSafety.decide(
            initial: initial,
            current: current,
            helperStateUnchanged: helperStateUnchanged,
            status: status
        )
        switch decision {
        case .abandon:
            return
        case .none:
            surfacePersistenceFailure(
                sessionStore.archiveOrphanedSession(endReason: .appQuit)
            )
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
                orphanEndReason: .appQuit,
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
        // Release the launch exclusion here — after the decision and the
        // demotion, per its own ordering rule — so this maintenance pass is
        // not blocked by this function's own in-flight guard. The `defer`
        // still covers every earlier exit; clearing twice is a no-op.
        launchReconciliationInFlight = false
        maintainScheduledWake()
        surfacePersistenceErrors()
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
        // Copy on every tick as a fallback for a missed notification, and let
        // the core freshness policy expire a stalled pmset sample.
        thermal = thermalMonitor.reading
        processThermal = thermalMonitor.processLevel

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

        retryPendingOrphanArchiveIfNeeded()
        scheduleAutomationTick()
        // Reconcile the RTC wake on every tick, independent of automation
        // gating — turning automation off (or deleting the last window) must
        // cancel a previously registered wake.
        maintainScheduledWake()
        surfacePersistenceErrors()
        publishWidget()
    }

    /// Retry only a reconciliation whose end reason was already selected.
    /// Launch-loaded journals without a reason still require live helper proof.
    private func retryPendingOrphanArchiveIfNeeded() {
        guard phase == .disarmed,
              currentSession == nil,
              pendingRestore == nil,
              !launchReconciliationInFlight,
              sessionStore.unresolvedSession?.endReason != nil
        else { return }

        let previousError = sessionStore.lastPersistenceError
        let result = sessionStore.retryOrphanedSessionArchive()
        if let message = result.errorMessage {
            lastError = message
        } else if let previousError, lastError == previousError {
            lastError = nil
        }
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

        // One tracker understands both sample-identified pmset evidence and
        // time-paced ProcessInfo pressure. Neither source can starve the other.
        let thermalStrikes = thermalStrikeTracker.observe(
            config: effectiveConfig,
            thermal: thermal,
            processThermal: processThermal,
            at: reference
        )

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
            if !config.scheduleAutomationEnabled {
                fired.append(.scheduleEnded)
            } else if let live = ScheduleEngine.activeOccurrence(
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
                    title: "Keep-awake ending soon",
                    body: "\(projected.label) — about \(Format.duration(remaining)) left. Lidless will request normal sleep when the cutoff fires."
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
                body: "\(percent)% — keep-awake ends at \(cfg.batteryFloorPercent)%, then Lidless will request normal sleep."
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
              !helperRegistrationInProgress,
              !sessionEvidenceRequiresReconciliation,
              phase == .disarmed,
              pendingArm == nil,
              helperState.isUsable,
              sleepPresentation == .verifiedNormal
        else {
            return
        }

        if let active = ScheduleEngine.activeOccurrence(windows: config.schedules, at: reference, calendar: .current),
           active != suppressedOccurrence {
            let assessment = CutoffEngine.assessArm(
                config: config.cutoffs,
                battery: battery,
                thermal: thermal,
                processThermal: processThermal,
                at: reference
            )
            switch assessment {
            case .refusedBelowFloor:
                // A real floor crossing stays suppressed until the next
                // occurrence rather than repeatedly trying to arm.
                suppressedOccurrence = active
            case .refusedBatteryTelemetryUnavailable,
                 .refusedThermalTelemetryUnavailable,
                 .refusedThermalPressure:
                // Telemetry loss or thermal pressure is retryable: leave the
                // occurrence eligible so later safe evidence can admit it.
                return
            case .ok, .lowBatteryWarning:
                let plan = armIntentPlan(
                    for: nil,
                    scheduledOccurrence: active
                )
                let pending = PendingArm(
                    id: UUID(),
                    plan: plan,
                    overrides: nil,
                    source: .schedule(windowID: active.windowID),
                    assessment: assessment,
                    projection: projection(for: plan.cutoffs),
                    createdAt: reference
                )
                scheduleOccurrence = active
                pendingArm = pending
                Task { await confirmArm(expectedIntentID: pending.id) }
            }
        }
    }

    /// Keep an RTC wake registered just before the next window so a closed,
    /// sleeping MacBook can wake up and arm itself (best effort — DarkWake
    /// still runs launchd + us long enough to arm). Desired-state
    /// reconciliation against reply-committed evidence; an unusable helper
    /// pauses (never blindly cancels) maintenance.
    private func maintainScheduledWake() {
        guard !isSimulation,
              !helperRegistrationInProgress,
              !launchReconciliationInFlight,
              helperLifecycleOperationsInFlight == 0,
              pendingRestore == nil,
              sleepTerminationGeneration == nil,
              !terminationPending,
              phase != .disarming,
              helperState.isUsable
        else { return }

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
                    self.retainRecoveryOnlyHelperStateIfNeeded(reply.status)
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
        surfacePersistenceFailure(sessionStore.checkpoint(session))
    }

    private func surfacePersistenceFailure(
        _ result: StorePersistenceResult
    ) {
        if let message = result.errorMessage {
            lastError = message
        }
    }

    private func surfacePersistenceErrors() {
        if let message = sessionStore.lastPersistenceError
            ?? config.lastPersistenceError {
            lastError = message
        }
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
