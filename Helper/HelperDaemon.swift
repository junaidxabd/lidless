import Foundation
import IOKit
import IOKit.pwr_mgt
import Security
import LidlessCore

// IOKit's iokit_common_msg() message constants aren't bridged into Swift;
// values from <IOKit/IOMessage.h> (sys_iokit | sub_iokit_common | code).
private let kIOMessageSystemWillSleep: UInt32 = 0xE000_0280
private let kIOMessageCanSystemSleep: UInt32 = 0xE000_0270
private let kIOMessageSystemHasPoweredOn: UInt32 = 0xE000_0300

/// The privileged daemon. Deliberately dumb: it never decides *when* to cut
/// off — the app does — it only actuates pmset and enforces one invariant:
///
///     The sleep override must never outlive supervision.
///
/// Enforcement is layered so no single failure strands the override:
///  1. Sentinel-first ordering: the on-disk sentinel (with everything needed
///     to undo) is written *before* the override is enabled, removed *after*
///     it is restored.
///  2. Connection supervision: the arming app connection invalidating (quit,
///     crash) restores immediately.
///  3. Watchdog: no heartbeat within TTL restores (app alive but wedged).
///  4. launchd: `KeepAlive.PathState` on the sentinel relaunches a crashed
///     helper while the override is on; `RunAtLoad` runs a restore pass at
///     boot. Every helper launch restores if a sentinel exists.
///  5. Forced-sleep detection: if the system sleeps anyway (user forced it),
///     the override is released before sleep completes.
///  6. Restore failure never gives up: the sentinel stays, retries continue.
///
/// Threading: all state lives on `queue`. XPC entry points and IOKit
/// callbacks hop onto it; nothing touches state anywhere else. That
/// discipline is what the `@unchecked Sendable` asserts.
final class HelperDaemon: NSObject, NSXPCListenerDelegate, @unchecked Sendable {

    private let queue = DispatchQueue(label: "com.lidless.helper.state")
    private let log = HelperLog()

    private var listener: NSXPCListener?

    // Session state (queue-only).
    private var sentinel: OverrideSentinel?
    /// Identity of the connection that armed the current session; identity
    /// (not the object) is all supervision needs, and it's Sendable.
    private var armedConnectionID: ObjectIdentifier?
    private var activeConnections = 0
    private var lastActivity = Date()

    /// A restore that failed; retried on every tick until it succeeds.
    private var restorePending: OverrideSentinel?

    // Supervision clocks are monotonic (mach time), never wall-clock: an NTP
    // step or manual clock change must neither extend the unsupervised
    // window (clock back) nor spuriously kill a healthy session (clock
    // forward). The sentinel keeps wall-clock copies for diagnostics only —
    // recovery never reads them (it restores unconditionally).
    private var watchdogDeadline = DispatchTime.distantFuture
    private var nextRestoreAttempt = DispatchTime.distantFuture
    /// Watchdog forbearance right after wake, so the app has time to resume
    /// heartbeats before a deadline that expired during sleep fires.
    private var graceUntil = DispatchTime.now()

    private var tickTimer: DispatchSourceTimer?
    private var signalSources: [DispatchSourceSignal] = []

    // Sleep/wake notification plumbing.
    private var powerNotifyPort: IONotificationPortRef?
    private var powerNotifier: io_object_t = 0
    private var rootPowerConnection: io_connect_t = 0

    /// The exact rendered date string is stored alongside the Date so
    /// cancellation always matches what pmset was given — re-rendering after
    /// a timezone change would cancel nothing.
    private struct StoredWake: Codable {
        var date: Date
        var rendered: String
    }

    private var scheduledWake: StoredWake?
    private let scheduledWakeURL = URL(fileURLWithPath: HelperPaths.workDirectory)
        .appendingPathComponent("scheduled-wake.json")

    // MARK: - Lifecycle

    func start() {
        queue.async { [self] in
            log.info("LidlessHelper v\(LidlessIDs.helperVersion) started (pid \(ProcessInfo.processInfo.processIdentifier), uid \(getuid()))")
            ensureWorkDirectory()
            loadScheduledWake()
            recoveryPass()
            installSignalHandlers()
            registerForSleepWake()
            startTick()
        }

        let listener = NSXPCListener(machServiceName: LidlessIDs.helperMachService)
        listener.delegate = self
        self.listener = listener
        listener.resume()
    }

    private func ensureWorkDirectory() {
        try? FileManager.default.createDirectory(
            atPath: HelperPaths.workDirectory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o755]
        )
    }

    /// First act of every launch — boot, crash relaunch, on-demand start:
    /// if a sentinel exists, the system may be overridden with nobody
    /// supervising. Restore first, ask questions never. If the app is in
    /// fact alive, its connection-interruption handler re-arms within
    /// seconds and the blip is logged on both sides.
    private func recoveryPass() {
        let url = URL(fileURLWithPath: HelperPaths.sentinel)
        guard FileManager.default.fileExists(atPath: url.path) else {
            if PMSet.readSleepDisabled() == true {
                log.info("sleep override is active but no sentinel exists — not ours; leaving untouched (repair available from the app)")
            }
            return
        }

        if let data = try? Data(contentsOf: url),
           let found = IPCCoding.decode(OverrideSentinel.self, from: data) {
            log.critical("launch found active sentinel (armed \(found.armedAt)) — restoring normal sleep")
            performRestore(found, reason: "helper launch with sentinel present")
        } else {
            // Unreadable sentinel: prior state unknown. Fail safe: sleep on.
            log.critical("launch found corrupt sentinel — forcing disablesleep 0")
            let fallback = OverrideSentinel(
                armedAt: Date(),
                watchdogTTL: HelperArmOptions.defaultWatchdogTTL,
                watchdogDeadline: Date(),
                priorSleepDisabled: false
            )
            performRestore(fallback, reason: "corrupt sentinel recovery")
        }
    }

    private func installSignalHandlers() {
        for sig in [SIGTERM, SIGINT] {
            signal(sig, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: sig, queue: queue)
            source.setEventHandler { [weak self] in
                guard let self else { exit(0) }
                self.log.info("received signal \(sig)")
                if let sentinel = self.sentinel ?? self.restorePending {
                    self.performRestore(sentinel, reason: "helper terminating (signal \(sig))")
                }
                exit(0)
            }
            source.resume()
            signalSources.append(source)
        }
    }

    private func startTick() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 5, repeating: 5)
        timer.setEventHandler { [weak self] in self?.tick() }
        timer.resume()
        tickTimer = timer
    }

    /// 5-second heartbeat of the safety net itself.
    private func tick() {
        let mono = DispatchTime.now()

        if let pending = restorePending, mono >= nextRestoreAttempt {
            log.error("retrying failed restore")
            performRestore(pending, reason: "restore retry")
        }

        if let sentinel, mono > watchdogDeadline, mono > graceUntil {
            log.critical("watchdog expired (armed \(sentinel.armedAt), ttl \(Int(sentinel.watchdogTTL))s) — restoring normal sleep")
            performRestore(sentinel, reason: "watchdog expired")
        }

        // Idle exit: nothing armed, nothing pending, nobody connected.
        // launchd restarts us on the next XPC lookup or at boot.
        if sentinel == nil, restorePending == nil, activeConnections == 0,
           Date().timeIntervalSince(lastActivity) > 180 {
            log.info("idle — exiting (launchd relaunches on demand)")
            exit(0)
        }
    }

    // MARK: - Sleep/wake awareness

    private func registerForSleepWake() {
        var notifyPort: IONotificationPortRef?
        var notifier: io_object_t = 0
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        let callback: IOServiceInterestCallback = { refcon, _, messageType, messageArgument in
            guard let refcon else { return }
            let daemon = Unmanaged<HelperDaemon>.fromOpaque(refcon).takeUnretainedValue()
            daemon.handlePowerMessage(messageType, argument: messageArgument)
        }

        rootPowerConnection = IORegisterForSystemPower(refcon, &notifyPort, callback, &notifier)
        guard rootPowerConnection != 0, let notifyPort else {
            log.error("IORegisterForSystemPower failed — forced-sleep detection unavailable")
            return
        }
        IONotificationPortSetDispatchQueue(notifyPort, queue)
        powerNotifyPort = notifyPort
        powerNotifier = notifier
    }

    /// Runs on `queue` (the notification port's dispatch queue).
    private func handlePowerMessage(_ messageType: UInt32, argument: UnsafeMutableRawPointer?) {
        switch messageType {
        case UInt32(kIOMessageSystemWillSleep):
            // With the override on, ordinary sleep is impossible — reaching
            // here while armed means someone forced sleep. Honor it: release
            // the override so the machine stays asleep, end the session.
            if let sentinel {
                log.info("system is being forced to sleep while armed — restoring and ending session")
                performRestore(sentinel, reason: "system forced sleep")
            }
            IOAllowPowerChange(rootPowerConnection, Int(bitPattern: argument))
        case UInt32(kIOMessageCanSystemSleep):
            IOAllowPowerChange(rootPowerConnection, Int(bitPattern: argument))
        case UInt32(kIOMessageSystemHasPoweredOn):
            graceUntil = .now() + 30
            log.info("system woke — 30s watchdog grace")
        default:
            break
        }
    }

    // MARK: - Arm / restore core

    private func writeSentinel(_ sentinel: OverrideSentinel) throws {
        ensureWorkDirectory()
        let url = URL(fileURLWithPath: HelperPaths.sentinel)
        try IPCCoding.encoder().encode(sentinel).write(to: url, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private func removeSentinelFile() {
        try? FileManager.default.removeItem(atPath: HelperPaths.sentinel)
    }

    fileprivate func handleArm(_ options: HelperArmOptions, connectionID: ObjectIdentifier?, reply: @escaping @Sendable (Data) -> Void) {
        guard restorePending == nil else {
            reply(replyData(ok: false, error: "helper is recovering from a failed restore; cannot arm"))
            return
        }

        let now = Date()
        let ttl = min(max(options.watchdogTTL, HelperArmOptions.watchdogTTLRange.lowerBound),
                      HelperArmOptions.watchdogTTLRange.upperBound)

        if var current = sentinel {
            // Re-arm: refresh supervision, keep the original priors — they
            // describe the pre-session world we'll eventually restore.
            current.watchdogTTL = ttl
            current.watchdogDeadline = now.addingTimeInterval(ttl)
            sentinel = current
            try? writeSentinel(current)
            watchdogDeadline = .now() + ttl
            armedConnectionID = connectionID
            log.info("re-armed (ttl \(Int(ttl))s)")
            reply(replyData(ok: true))
            return
        }

        // Fresh arm. Capture priors, persist the undo record, then mutate.
        var record = OverrideSentinel(
            armedAt: now,
            watchdogTTL: ttl,
            watchdogDeadline: now.addingTimeInterval(ttl),
            priorSleepDisabled: PMSet.readSleepDisabled() ?? false
        )

        let custom = (try? PMSet.readCustom()) ?? ""
        if options.lowPowerMode {
            if let key = PMSet.lowPowerModeKey(fromCustom: custom) {
                record.lowPowerModeKey = key
                record.priorLowPowerMode = PMSetParser.intSetting(key, fromCustom: custom)
            } else {
                log.info("low power mode requested but unsupported on this system — skipping")
            }
        }
        if options.tcpKeepAlive {
            record.priorTCPKeepAlive = PMSetParser.intSetting("tcpkeepalive", fromCustom: custom)
        }

        do {
            try writeSentinel(record)
        } catch {
            reply(replyData(ok: false, error: "could not persist recovery sentinel: \(error.localizedDescription)"))
            return
        }

        do {
            try PMSet.setSleepDisabled(true)
        } catch {
            // Outcome UNKNOWN, not "not applied": pmset can mutate the
            // setting and then hang past the timeout. Abort the arm, but
            // only drop the sentinel if the registry verifiably reads the
            // prior state — otherwise the sentinel stays and the retry loop
            // + launchd own driving it back to safe.
            log.error("failed to enable override: \(error)")
            abortFreshArm(record, reply: reply, error: "\(error)")
            return
        }

        if let readback = PMSet.readSleepDisabled(), readback == false {
            log.error("disablesleep readback is still 0 after set — reverting")
            abortFreshArm(record, reply: reply, error: "system did not accept the sleep override")
            return
        }

        // Best-effort extras; never fail the arm over them.
        if let key = record.lowPowerModeKey {
            do { try PMSet.setEverywhere(key: key, value: 1) }
            catch { log.error("could not enable low power mode: \(error)") }
        }
        if record.priorTCPKeepAlive != nil {
            do { try PMSet.setEverywhere(key: "tcpkeepalive", value: 1) }
            catch { log.error("could not enforce tcpkeepalive: \(error)") }
        }

        sentinel = record
        watchdogDeadline = .now() + ttl
        armedConnectionID = connectionID
        log.info("armed: override ON (ttl \(Int(ttl))s, lpm \(record.lowPowerModeKey ?? "off"), tcp \(record.priorTCPKeepAlive != nil ? "on" : "off"), priorSleepDisabled \(record.priorSleepDisabled))")
        reply(replyData(ok: true))
    }

    /// Failed fresh arm with unknown side effects. Best-effort revert, then
    /// verify: sentinel is removed only when the registry provably shows the
    /// prior state; anything else parks in `restorePending` so the 30s retry
    /// and `KeepAlive.PathState` keep supervising until it's provably safe.
    private func abortFreshArm(_ record: OverrideSentinel, reply: @escaping @Sendable (Data) -> Void, error: String) {
        try? PMSet.setSleepDisabled(record.priorSleepDisabled)
        if PMSet.readSleepDisabled() == record.priorSleepDisabled {
            removeSentinelFile()
        } else {
            log.critical("aborted arm but the override state is unverified — keeping sentinel and retrying restore")
            restorePending = record
            nextRestoreAttempt = .now() + 30
        }
        reply(replyData(ok: false, error: error))
    }

    /// The single restore path used by every trigger. Sets the world back to
    /// the sentinel's priors; only on full success does the sentinel leave
    /// the disk. On failure, state moves to `restorePending` and the tick
    /// retries forever (launchd keeps us alive: the sentinel still exists).
    private func performRestore(_ record: OverrideSentinel, reason: String) {
        do {
            try PMSet.setSleepDisabled(record.priorSleepDisabled)
        } catch {
            log.critical("RESTORE FAILED (\(reason)): \(error) — will retry")
            sentinel = nil
            armedConnectionID = nil
            watchdogDeadline = .distantFuture
            restorePending = record
            nextRestoreAttempt = .now() + 30
            return
        }

        if let readback = PMSet.readSleepDisabled(), readback != record.priorSleepDisabled {
            log.critical("RESTORE readback mismatch (\(reason)) — will retry")
            sentinel = nil
            armedConnectionID = nil
            watchdogDeadline = .distantFuture
            restorePending = record
            nextRestoreAttempt = .now() + 30
            return
        }

        // Extras are best-effort: they can't strand sleep, only comfort.
        if let key = record.lowPowerModeKey, let priors = record.priorLowPowerMode {
            do { try PMSet.restore(key: key, sections: priors) }
            catch { log.error("could not restore \(key): \(error)") }
        }
        if let priors = record.priorTCPKeepAlive {
            do { try PMSet.restore(key: "tcpkeepalive", sections: priors) }
            catch { log.error("could not restore tcpkeepalive: \(error)") }
        }

        removeSentinelFile()
        sentinel = nil
        armedConnectionID = nil
        watchdogDeadline = .distantFuture
        restorePending = nil
        log.info("restored normal sleep (\(reason))")
    }

    // MARK: - XPC entry points (hop to queue; every path must reply)

    fileprivate func handlePing(reply: @escaping @Sendable (Data) -> Void) {
        queue.async { [self] in
            lastActivity = Date()
            reply(IPCCoding.encode(currentStatus()))
        }
    }

    fileprivate func enqueueArm(_ optionsJSON: Data, connectionID: ObjectIdentifier?, reply: @escaping @Sendable (Data) -> Void) {
        queue.async { [self] in
            lastActivity = Date()
            guard let options = IPCCoding.decode(HelperArmOptions.self, from: optionsJSON) else {
                reply(replyData(ok: false, error: "malformed arm options"))
                return
            }
            handleArm(options, connectionID: connectionID, reply: reply)
        }
    }

    fileprivate func handleHeartbeat(reply: @escaping @Sendable (Data) -> Void) {
        queue.async { [self] in
            lastActivity = Date()
            guard var current = sentinel else {
                reply(replyData(ok: false, error: "no active session"))
                return
            }
            current.watchdogDeadline = Date().addingTimeInterval(current.watchdogTTL)
            sentinel = current
            try? writeSentinel(current)
            watchdogDeadline = .now() + current.watchdogTTL
            reply(replyData(ok: true))
        }
    }

    fileprivate func handleDisarm(_ optionsJSON: Data, reply: @escaping @Sendable (Data) -> Void) {
        queue.async { [self] in
            lastActivity = Date()
            guard let options = IPCCoding.decode(HelperDisarmOptions.self, from: optionsJSON) else {
                reply(replyData(ok: false, error: "malformed disarm options"))
                return
            }

            if let sentinel {
                performRestore(sentinel, reason: "disarm: \(options.reason)")
            }
            let restored = restorePending == nil
            reply(replyData(ok: restored, error: restored ? nil : "restore failed; helper is retrying"))

            if options.forceSleep, restored {
                // Give the app a moment to post its notification/sound, and
                // skip if a new session armed in the window.
                queue.asyncAfter(deadline: .now() + 3) { [self] in
                    guard sentinel == nil else { return }
                    log.info("forcing sleep (\(options.reason))")
                    do { try PMSet.sleepNow() }
                    catch { log.error("sleepnow failed: \(error)") }
                }
            }
        }
    }

    fileprivate func handleRepairOverride(reply: @escaping @Sendable (Data) -> Void) {
        queue.async { [self] in
            lastActivity = Date()
            if let sentinel {
                performRestore(sentinel, reason: "repair requested")
            } else {
                do {
                    try PMSet.setSleepDisabled(false)
                    log.info("repaired externally-set override: disablesleep 0")
                } catch {
                    reply(replyData(ok: false, error: "\(error)"))
                    return
                }
            }
            reply(replyData(ok: restorePending == nil))
        }
    }

    fileprivate func handleScheduleWake(_ epoch: Double, reply: @escaping @Sendable (Data) -> Void) {
        queue.async { [self] in
            lastActivity = Date()
            if epoch > 0 {
                // Validate and register the replacement first; only then
                // cancel the old wake — never trade a working wake for none.
                let date = Date(timeIntervalSince1970: epoch)
                let horizon = Date().addingTimeInterval(14 * 24 * 3600)
                guard date > Date(), date < horizon else {
                    reply(replyData(ok: false, error: "wake date out of range"))
                    return
                }
                if let existing = scheduledWake, abs(existing.date.timeIntervalSince1970 - epoch) < 1 {
                    // Already registered; re-scheduling would duplicate the
                    // pmset event.
                    reply(replyData(ok: true))
                    return
                }
                let previous = scheduledWake
                do {
                    let rendered = try PMSet.scheduleWake(at: date)
                    scheduledWake = StoredWake(date: date, rendered: rendered)
                    persistScheduledWake()
                    log.info("scheduled wake at \(date)")
                } catch {
                    reply(replyData(ok: false, error: "\(error)"))
                    return
                }
                if let previous, previous.rendered != scheduledWake?.rendered {
                    try? PMSet.cancelWake(rendered: previous.rendered)
                }
            } else if let existing = scheduledWake {
                try? PMSet.cancelWake(rendered: existing.rendered)
                scheduledWake = nil
                persistScheduledWake()
            }
            reply(replyData(ok: true))
        }
    }

    fileprivate func handleUninstall(reply: @escaping @Sendable (Data) -> Void) {
        queue.async { [self] in
            lastActivity = Date()
            if let sentinel {
                performRestore(sentinel, reason: "uninstall")
            }
            guard restorePending == nil else {
                reply(replyData(ok: false, error: "restore failed; not removing helper data while the override may be active"))
                return
            }
            if let existing = scheduledWake {
                try? PMSet.cancelWake(rendered: existing.rendered)
                scheduledWake = nil
            }
            log.info("uninstalling: removing \(HelperPaths.workDirectory)")
            // Any later log line would recreate the directory we just
            // removed; from here on, log to the unified log only.
            log.disableFileSink()
            try? FileManager.default.removeItem(atPath: HelperPaths.workDirectory)
            reply(replyData(ok: true))
        }
    }

    private func currentStatus() -> HelperStatus {
        HelperStatus(
            helperVersion: LidlessIDs.helperVersion,
            armed: sentinel != nil,
            sleepDisabled: PMSet.readSleepDisabled() ?? (sentinel != nil),
            armedSince: sentinel?.armedAt,
            watchdogDeadline: sentinel?.watchdogDeadline,
            scheduledWake: scheduledWake?.date
        )
    }

    private func replyData(ok: Bool, error: String? = nil) -> Data {
        IPCCoding.encode(HelperReply(ok: ok, error: error, status: currentStatus()))
    }

    private func persistScheduledWake() {
        if let scheduledWake {
            try? IPCCoding.encode(scheduledWake).write(to: scheduledWakeURL, options: .atomic)
        } else {
            try? FileManager.default.removeItem(at: scheduledWakeURL)
        }
    }

    private func loadScheduledWake() {
        guard let data = try? Data(contentsOf: scheduledWakeURL) else { return }
        scheduledWake = IPCCoding.decode(StoredWake.self, from: data)
        if let scheduledWake, scheduledWake.date < Date() {
            self.scheduledWake = nil
            persistScheduledWake()
        }
    }

    // MARK: - NSXPCListenerDelegate

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        // Only the Lidless app may talk to this daemon. With a real signing
        // team, require same-team + bundle identifier; ad-hoc development
        // builds fall back to identifier-only (loudly logged).
        let requirement: String
        if let team = Self.ownTeamIdentifier() {
            requirement = "anchor apple generic and identifier \"\(LidlessIDs.appBundleID)\" and certificate leaf[subject.OU] = \"\(team)\""
        } else {
            requirement = "identifier \"\(LidlessIDs.appBundleID)\""
            log.error("DEV MODE: helper is not team-signed; accepting peers by identifier only")
        }
        do {
            try newConnection.setCodeSigningRequirement(requirement)
        } catch {
            log.error("rejecting connection: could not apply code-signing requirement: \(error)")
            return false
        }

        let connectionID = ObjectIdentifier(newConnection)
        newConnection.exportedInterface = NSXPCInterface(with: LidlessHelperXPC.self)
        newConnection.exportedObject = HelperXPCBridge(daemon: self, connectionID: connectionID)
        newConnection.invalidationHandler = { [weak self] in
            self?.connectionEnded(connectionID)
        }
        // Count the connection before resuming it: a fast invalidation must
        // never decrement before the increment lands.
        queue.async { [self] in
            activeConnections += 1
            lastActivity = Date()
        }
        newConnection.resume()
        return true
    }

    private func connectionEnded(_ connectionID: ObjectIdentifier) {
        queue.async { [self] in
            activeConnections = max(0, activeConnections - 1)
            lastActivity = Date()
            if connectionID == armedConnectionID, let sentinel {
                log.critical("supervising app connection invalidated while armed — restoring normal sleep")
                performRestore(sentinel, reason: "app connection invalidated")
            }
        }
    }

    private static func ownTeamIdentifier() -> String? {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return nil }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else { return nil }
        var info: CFDictionary?
        guard SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
              let dict = info as? [String: Any]
        else { return nil }
        return dict[kSecCodeInfoTeamIdentifier as String] as? String
    }
}

// MARK: - Per-connection XPC facade

/// Thin bridge so the daemon can associate each call with its connection's
/// identity (for supervision) without touching `NSXPCConnection.current`.
final class HelperXPCBridge: NSObject, LidlessHelperXPC {
    private let daemon: HelperDaemon
    private let connectionID: ObjectIdentifier

    init(daemon: HelperDaemon, connectionID: ObjectIdentifier) {
        self.daemon = daemon
        self.connectionID = connectionID
    }

    func ping(_ reply: @escaping @Sendable (Data) -> Void) {
        daemon.handlePing(reply: reply)
    }

    func arm(_ optionsJSON: Data, reply: @escaping @Sendable (Data) -> Void) {
        daemon.enqueueArm(optionsJSON, connectionID: connectionID, reply: reply)
    }

    func heartbeat(_ reply: @escaping @Sendable (Data) -> Void) {
        daemon.handleHeartbeat(reply: reply)
    }

    func disarm(_ optionsJSON: Data, reply: @escaping @Sendable (Data) -> Void) {
        daemon.handleDisarm(optionsJSON, reply: reply)
    }

    func repairOverride(_ reply: @escaping @Sendable (Data) -> Void) {
        daemon.handleRepairOverride(reply: reply)
    }

    func scheduleWake(_ epoch: Double, reply: @escaping @Sendable (Data) -> Void) {
        daemon.handleScheduleWake(epoch, reply: reply)
    }

    func uninstall(_ reply: @escaping @Sendable (Data) -> Void) {
        daemon.handleUninstall(reply: reply)
    }
}
