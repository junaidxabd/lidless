import Foundation
import Darwin
import IOKit
import IOKit.pwr_mgt
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
///  2. Connection supervision: the arming app connection interrupting or
///     invalidating requests immediate restoration exactly once.
///  3. Watchdog: no heartbeat within TTL restores (app alive but wedged).
///  4. launchd configuration: `KeepAlive.PathState` on the sentinel requests
///     relaunch while the override may be on; `RunAtLoad` requests a boot
///     recovery pass. Actual launchd/crash behavior remains a live gate.
///  5. Forced-sleep detection: if the system sleeps anyway (user forced it),
///     the override is released before sleep completes.
///  6. Restore failure remains pending and the tick retries while this process
///     lives; a trusted retained marker requests launchd relaunch.
///
/// Threading: all state lives on `queue`. XPC entry points and IOKit
/// callbacks hop onto it; nothing touches state anywhere else. That
/// discipline is what the `@unchecked Sendable` asserts.
final class HelperDaemon: NSObject, NSXPCListenerDelegate, @unchecked Sendable {
    /// Producer-owned declaration of the behavior actually implemented by
    /// this daemon. Keep this independent from the app's required revision so
    /// an app-side bump cannot silently make an unchanged helper compatible.
    private static let implementedSafetyRevision = 8
    private static let maximumSentinelBytes = 64 * 1024
    private static let maximumDurableMutationMarkerBytes = 16 * 1024
    private static let maximumScheduledWakeReconciliationMarkerBytes = 16 * 1024
    private static let maximumScheduledWakeLedgerBytes = 64 * 1024

    private struct StorageError: LocalizedError {
        let operation: String
        let code: Int32?

        var errorDescription: String? {
            guard let code else { return operation }
            return "\(operation): \(String(cString: strerror(code)))"
        }
    }

    private struct ScheduledWakeAdapterError: LocalizedError {
        let message: String

        var errorDescription: String? { message }
    }

    /// Durable evidence that a mutating child may exist. It is published
    /// before launch and removed only after this exact helper process observes
    /// the command exit. A later helper may recover under an inherited marker,
    /// but it can never manufacture that missing exit observation.
    private struct DurableMutationMarker: Codable, Equatable {
        static let currentVersion = 2

        enum Operation: String, Codable {
            case enableOverride
            case restoreOverride
            case applyManagedSettings
            case forceSleep
            case scheduleWake
            case cancelWake

            var concernsScheduledWake: Bool {
                self == .scheduleWake || self == .cancelWake
            }
        }

        var version: Int
        var id: UUID
        var operation: Operation
        var startedAt: Date
        /// Version 1 markers decode with nil and remain operator-only. Every
        /// new marker records the kernel boot session so a later reboot can
        /// prove that the inherited child no longer exists.
        var bootSessionUUID: UUID?

        init(operation: Operation, bootSessionUUID: UUID) {
            version = Self.currentVersion
            id = UUID()
            self.operation = operation
            startedAt = Date()
            self.bootSessionUUID = bootSessionUUID
        }
    }

    /// Separate from child-exit evidence: this marker means a durable wake
    /// ledger transaction still needs reconciliation. It is published before
    /// the first pending ledger state and removed only after exact readback.
    private struct ScheduledWakeReconciliationMarker: Codable, Equatable {
        static let currentVersion = 1

        var version: Int = Self.currentVersion
        var id: UUID = UUID()
        var startedAt: Date = Date()
    }

    private enum ScheduledWakeReconciliationProgress {
        case settled(observedEvents: [String])
        case needsMoreWork
    }

    private let queue = DispatchQueue(label: "com.lidless.helper.state")
    private let log = HelperLog()
    /// Computed once after queue-owned recovery and before the listener is
    /// exposed. A missing value means every peer is rejected.
    private var peerCodeSigningRequirement: String?

    private var listener: NSXPCListener?

    // Session state (queue-only).
    private var sentinel: OverrideSentinel?
    /// Fresh process-local identities avoid object-address reuse when a late
    /// callback from an old connection races a newly accepted connection.
    private var armedConnectionID: UUID?
    private var connectionSupervision = HelperConnectionSupervisionSafety<UUID>()
    private var lastActivity = Date()

    /// A restore that failed; retried on every tick until it succeeds.
    private var restorePending: OverrideSentinel?
    /// Timed-out mutating children whose exit Foundation has not observed.
    /// Retaining the exact `Process` closes the late-completion window: no
    /// sentinel deletion, new risky work, cleanup, or voluntary exit is
    /// allowed while any witness remains unresolved.
    private var unresolvedMutationWitnesses: [PMSet.TerminationWitness] = []
    private var durableMutationMarker: DurableMutationMarker?
    private var currentBootSessionUUID: UUID?
    /// True only when this process loaded the marker rather than creating it.
    /// Such a process can never prove the original child exited, so it may
    /// recover repeatedly but must retain the marker and recovery evidence.
    private var durableMutationMarkerLoadedFromPriorProcess = false
    private var durableMutationMarkerPriorChildExitProvenByReboot = false
    private var durableMutationMarkerFailure: String?
    /// Invalidates delayed force-sleep follow-ups whenever any later helper or
    /// system lifecycle intent arrives. This closes the nil -> active -> nil
    /// ABA window that a sentinel-only guard cannot detect.
    private var lifecycleGeneration = UUID()
    // Supervision clocks are monotonic (mach time), never wall-clock: an NTP
    // step or manual clock change must neither extend the unsupervised
    // window (clock back) nor spuriously kill a healthy session (clock
    // forward). The in-memory record keeps a wall-clock copy for status;
    // the disk sentinel is deliberately immutable while the override is on.
    // Recovery never trusts either deadline (it restores unconditionally).
    private var watchdogDeadline = DispatchTime.distantFuture
    private var nextRestoreAttempt = DispatchTime.distantFuture
    /// Watchdog forbearance right after wake, so the app has time to resume
    /// heartbeats before a deadline that expired during sleep fires.
    private var graceUntil = DispatchTime.now()
    /// A signal requests termination; it does not authorize abandoning an
    /// unverified restore. This remains latched for the process lifetime.
    private var terminationRequested = false

    private var tickTimer: DispatchSourceTimer?
    private var signalSources: [DispatchSourceSignal] = []

    // Sleep/wake notification plumbing.
    private var powerNotifyPort: IONotificationPortRef?
    private var powerNotifier: io_object_t = 0
    private var rootPowerConnection: io_connect_t = 0
    /// A delayed force-sleep request is never authorized when the helper
    /// cannot observe an intervening sleep/wake lifecycle.
    private var powerObservationAvailable = false

    /// Revision-7 wrote a single best-effort record. It is accepted only from
    /// the trusted root-owned file path and immediately migrated to a
    /// cancellation obligation; it is never promoted to current truth.
    private struct LegacyStoredWake: Codable {
        var date: Date
        var rendered: String
    }

    private var scheduledWakeLedger = ScheduledWakeLedger()
    private var scheduledWakeLedgerLoaded = false
    private var scheduledWakeLedgerFailure: String?
    private var scheduledWakeReconciliationMarker: ScheduledWakeReconciliationMarker?
    private var scheduledWakeReconciliationMarkerLoaded = false
    private var scheduledWakeReconciliationMarkerFailure: String?
    private var nextScheduledWakeReconciliation = DispatchTime.now()

    // MARK: - Lifecycle

    /// `kern.bootsessionuuid` changes only across a machine reboot. A helper
    /// process restart within the same boot is deliberately insufficient proof
    /// that a reparented mutating child has exited.
    private func readCurrentBootSessionUUID() -> UUID? {
        var byteCount = 0
        guard sysctlbyname(
            "kern.bootsessionuuid",
            nil,
            &byteCount,
            nil,
            0
        ) == 0, byteCount > 1, byteCount <= 1_024 else {
            return nil
        }

        var bytes = [CChar](repeating: 0, count: byteCount)
        let readResult = bytes.withUnsafeMutableBytes { buffer in
            sysctlbyname(
                "kern.bootsessionuuid",
                buffer.baseAddress,
                &byteCount,
                nil,
                0
            )
        }
        guard readResult == 0 else { return nil }
        let terminator = bytes.firstIndex(of: 0) ?? bytes.endIndex
        let utf8 = bytes[..<terminator].map { UInt8(bitPattern: $0) }
        return UUID(uuidString: String(decoding: utf8, as: UTF8.self))
    }

    func start() {
        // Finish queue-owned recovery setup before the XPC listener is exposed.
        // Signal sources are installed first: a signal delivered during a
        // blocking recovery pass queues behind that pass instead of taking the
        // default process-termination path or observing uninitialized state.
        queue.sync { [self] in
            installSignalHandlers()
            currentBootSessionUUID = readCurrentBootSessionUUID()
            if currentBootSessionUUID == nil {
                log.critical("kernel boot-session identity is unavailable; new mutations will be refused")
            }
            let storageFailure: Error?
            do {
                try ensureSecureWorkDirectory()
                storageFailure = nil
            } catch {
                // Never append through an untrusted root path. Unified logging
                // remains available while recovery fails closed in memory.
                log.disableFileSink()
                storageFailure = error
                log.critical("helper storage is not trusted: \(error.localizedDescription)")
            }
            var recoveryStorageFailure = storageFailure
            if storageFailure == nil {
                do {
                    try loadDurableMutationMarker()
                } catch {
                    durableMutationMarkerFailure = error.localizedDescription
                    durableMutationMarkerLoadedFromPriorProcess = true
                    recoveryStorageFailure = error
                    log.critical(
                        "durable mutation marker cannot be trusted: \(error.localizedDescription)"
                    )
                }
                do {
                    try loadScheduledWakeReconciliationMarker()
                } catch {
                    scheduledWakeReconciliationMarkerFailure = error.localizedDescription
                    scheduledWakeReconciliationMarkerLoaded = false
                    log.critical(
                        "scheduled-wake reconciliation marker cannot be trusted: \(error.localizedDescription)"
                    )
                }
            } else {
                durableMutationMarkerFailure = storageFailure?.localizedDescription
                durableMutationMarkerLoadedFromPriorProcess = true
                scheduledWakeReconciliationMarkerFailure = storageFailure?.localizedDescription
                scheduledWakeReconciliationMarkerLoaded = false
            }
            recoveryPass(storageFailure: recoveryStorageFailure)
            log.info("LidlessHelper v\(LidlessIDs.helperVersion) started (pid \(ProcessInfo.processInfo.processIdentifier), uid \(getuid()))")
            if let storageFailure {
                recordScheduledWakeLedgerFailure(
                    "scheduled-wake ledger storage is unavailable: \(storageFailure.localizedDescription)"
                )
            } else {
                do {
                    try loadScheduledWakeLedger()
                    if sentinel == nil, restorePending == nil,
                       !unresolvedMutationRemains() {
                        let progress = try reconcileScheduledWakeLedger(
                            reason: "helper launch",
                            maximumActions: 1
                        )
                        if case .settled(let observedEvents) = progress {
                            try finishScheduledWakeReconciliation(
                                observedEvents: observedEvents
                            )
                        }
                    }
                } catch {
                    recordScheduledWakeLedgerFailure(
                        "scheduled-wake recovery failed at launch: \(error.localizedDescription)"
                    )
                }
            }
            registerForSleepWake()
            startTick()
        }

        // Identity validation can touch the filesystem/Security framework.
        // Run it only after recovery and signal supervision are live, but still
        // before any XPC peer can observe the result.
        peerCodeSigningRequirement = XPCPeerPolicy.validatedRequirementForCurrentProcess(
            appBundleID: LidlessIDs.appBundleID,
            helperBundleID: LidlessIDs.helperLabel
        )

        let listener = NSXPCListener(machServiceName: LidlessIDs.helperMachService)
        listener.delegate = self
        self.listener = listener
        listener.resume()
    }

    /// First act of every actual launch — boot, crash relaunch, on-demand:
    /// if a sentinel exists, the system may be overridden with nobody
    /// supervising. Restore first, ask questions never. If the app is alive,
    /// its connection-interruption handler terminally ends that request; a
    /// later keep-awake session always requires a fresh arm decision.
    private func recoveryPass(storageFailure: Error?) {
        if let storageFailure {
            recoverUntrustedSentinel(
                reason: "helper storage validation failed: \(storageFailure.localizedDescription)"
            )
            return
        }

        do {
            guard let found = try readTrustedSentinel() else {
                if let marker = durableMutationMarker,
                   !marker.operation.concernsScheduledWake {
                    recoverUntrustedSentinel(
                        reason: "a prior-process \(marker.operation.rawValue) mutation marker has no recovery sentinel"
                    )
                    return
                }
                if PMSet.readSleepDisabled() == true {
                    log.info("sleep override is active but no sentinel exists — not ours; leaving untouched (repair available from the app)")
                }
                return
            }
            log.critical("launch found active sentinel (armed \(found.armedAt)) — restoring normal sleep")
            performRestore(found, reason: "helper launch with sentinel present")
        } catch {
            recoverUntrustedSentinel(
                reason: "sentinel metadata or contents are untrusted: \(error.localizedDescription)"
            )
        }
    }

    /// Unknown/corrupt storage can prove no optional prior. Force ordinary
    /// sleep, retain in-process recovery pending, never delete untrusted marker
    /// evidence, and never claim that managed settings were restored.
    private func recoverUntrustedSentinel(reason: String) {
        log.critical("\(reason) — forcing disablesleep 0 and retaining recovery")
        let fallback = OverrideSentinel(
            version: 0,
            armedAt: Date(),
            watchdogTTL: HelperArmOptions.defaultWatchdogTTL,
            watchdogDeadline: Date(),
            priorSleepDisabled: false
        )
        performRestore(fallback, reason: reason)
    }

    private func installSignalHandlers() {
        let terminationSignals = [SIGTERM, SIGINT]
        // Minimize the default-termination window by setting both managed
        // dispositions before constructing either dispatch source.
        for sig in terminationSignals {
            signal(sig, SIG_IGN)
        }
        for sig in terminationSignals {
            let source = DispatchSource.makeSignalSource(signal: sig, queue: queue)
            // The daemon and its signal sources intentionally live for the
            // process lifetime; a strong capture removes any nil-self path
            // that could silently discard a termination request.
            source.setEventHandler { [self] in
                log.info("received signal \(sig)")
                terminationRequested = true
                advanceLifecycle()
                if let sentinel = sentinel ?? restorePending {
                    performRestore(sentinel, reason: "helper terminating (signal \(sig))")
                }
                finishTerminationIfSafe()
            }
            source.resume()
            signalSources.append(source)
        }
    }

    private func finishTerminationIfSafe() {
        guard !unresolvedMutationRemains() else { return }
        guard !durableMutationMarkerRequiresRecovery else { return }
        guard !scheduledWakeLedgerNeedsRecovery else { return }
        guard HelperTerminationSafety.canVoluntarilyExit(
            terminationRequested: terminationRequested,
            hasSentinel: sentinel != nil,
            hasPendingRestore: restorePending != nil
        ) else { return }
        log.info("termination requested with no helper-owned restore remaining — exiting")
        exit(0)
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

        if mono >= nextScheduledWakeReconciliation,
           sentinel == nil, restorePending == nil,
           !unresolvedMutationRemains(),
           scheduledWakeLedgerNeedsRecovery {
            do {
                if !scheduledWakeReconciliationMarkerLoaded {
                    try loadScheduledWakeReconciliationMarker()
                }
                if !scheduledWakeLedgerLoaded {
                    try loadScheduledWakeLedger()
                }
                let progress = try reconcileScheduledWakeLedger(
                    reason: "periodic recovery",
                    maximumActions: 1
                )
                switch progress {
                case .settled(let observedEvents):
                    try finishScheduledWakeReconciliation(
                        observedEvents: observedEvents
                    )
                case .needsMoreWork:
                    nextScheduledWakeReconciliation = .now() + 5
                }
            } catch {
                recordScheduledWakeLedgerFailure(
                    "scheduled-wake periodic recovery failed: \(error.localizedDescription)"
                )
            }
        }

        if terminationRequested {
            finishTerminationIfSafe()
        }

        // Idle exit: nothing armed, nothing pending, nobody connected.
        // launchd restarts us on the next XPC lookup or at boot.
        if sentinel == nil, restorePending == nil,
           !unresolvedMutationRemains(), connectionSupervision.isEmpty,
           !durableMutationMarkerRequiresRecovery,
           !scheduledWakeLedgerNeedsRecovery,
           Date().timeIntervalSince(lastActivity) > 180 {
            log.info("idle — exiting (launchd is configured for on-demand launch)")
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
        powerObservationAvailable = true
    }

    /// Runs on `queue` (the notification port's dispatch queue).
    private func handlePowerMessage(_ messageType: UInt32, argument: UnsafeMutableRawPointer?) {
        advanceLifecycle()
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

    private func advanceLifecycle() {
        lifecycleGeneration = UUID()
    }

    private func ensureSecureWorkDirectory() throws {
        var directoryDescriptor = try openSecureWorkDirectory()
        try closeStorageDescriptor(
            &directoryDescriptor,
            operation: "close verified helper work directory"
        )
    }

    /// Opens the exact root-owned work directory relative to a separately
    /// proven parent descriptor. Existing directory metadata is never silently
    /// chmod/chowned into trust, and the sentinel receives its own proof below;
    /// other child-path hardening is a separate review surface.
    private func openSecureWorkDirectory() throws -> Int32 {
        var parentDescriptor = open(
            HelperPaths.workDirectoryParent,
            O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
        )
        guard parentDescriptor >= 0 else {
            throw StorageError(
                operation: "open helper storage parent without following links",
                code: errno
            )
        }
        defer {
            if parentDescriptor >= 0 {
                _ = Darwin.close(parentDescriptor)
            }
        }

        let parentMetadata = try storageMetadata(for: parentDescriptor)
        guard HelperStorageSafety.isSecureStorageDirectory(parentMetadata) else {
            throw StorageError(
                operation: "helper storage parent is not exact root:wheel mode 0755 without an ACL",
                code: nil
            )
        }

        let createResult = mkdirat(
            parentDescriptor,
            HelperPaths.workDirectoryName,
            mode_t(0o755)
        )
        let created = createResult == 0
        if !created {
            let createErrno = errno
            guard createErrno == EEXIST else {
                throw StorageError(
                    operation: "create helper work directory",
                    code: createErrno
                )
            }
        }

        var directoryDescriptor = openat(
            parentDescriptor,
            HelperPaths.workDirectoryName,
            O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
        )
        guard directoryDescriptor >= 0 else {
            throw StorageError(
                operation: "open helper work directory without following links",
                code: errno
            )
        }
        defer {
            if directoryDescriptor >= 0 {
                _ = Darwin.close(directoryDescriptor)
            }
        }

        if created {
            guard fchown(directoryDescriptor, 0, 0) == 0 else {
                throw StorageError(
                    operation: "set helper work-directory owner",
                    code: errno
                )
            }
            guard fchmod(directoryDescriptor, mode_t(0o755)) == 0 else {
                throw StorageError(
                    operation: "set helper work-directory mode",
                    code: errno
                )
            }
        }

        let metadata = try storageMetadata(for: directoryDescriptor)
        guard HelperStorageSafety.isSecureWorkDirectory(metadata) else {
            throw StorageError(
                operation: "helper work directory is not exact root:wheel mode 0755 without an ACL",
                code: nil
            )
        }

        // Retrying both barriers for an existing directory matters: a prior
        // process can be killed after mkdir/fchmod but before either barrier.
        // Metadata observed from cache is not durable namespace proof.
        try fullySynchronize(
            directoryDescriptor,
            operation: "fully synchronize helper work directory"
        )
        try fullySynchronize(
            parentDescriptor,
            operation: "fully synchronize helper work-directory parent entry"
        )
        try closeStorageDescriptor(
            &parentDescriptor,
            operation: "close synchronized helper storage parent"
        )

        let result = directoryDescriptor
        directoryDescriptor = -1
        return result
    }

    /// `fsync` alone does not promise device persistence or strict ordering on
    /// macOS. F_FULLFSYNC requests the filesystem/drive barrier; unsupported
    /// storage fails closed rather than weakening recovery silently.
    private func fullySynchronize(
        _ descriptor: Int32,
        operation: String
    ) throws {
        while fcntl(descriptor, F_FULLFSYNC) != 0 {
            let syncErrno = errno
            if syncErrno == EINTR { continue }
            throw StorageError(operation: operation, code: syncErrno)
        }
    }

    /// A close error after a mutation is not success: Darwin can report late
    /// I/O failure here. Callers set the descriptor invalid before throwing so
    /// a deferred cleanup never risks closing a reused descriptor.
    private func closeStorageDescriptor(
        _ descriptor: inout Int32,
        operation: String
    ) throws {
        let closeResult = Darwin.close(descriptor)
        let closeErrno = errno
        descriptor = -1
        guard closeResult == 0 else {
            throw StorageError(operation: operation, code: closeErrno)
        }
    }

    private func storageMetadata(
        for descriptor: Int32
    ) throws -> HelperStorageSafety.Metadata {
        var fileStatus = stat()
        guard fstat(descriptor, &fileStatus) == 0 else {
            throw StorageError(operation: "inspect helper storage", code: errno)
        }

        let kind: HelperStorageSafety.ObjectKind
        switch fileStatus.st_mode & mode_t(S_IFMT) {
        case mode_t(S_IFDIR):
            kind = .directory
        case mode_t(S_IFREG):
            kind = .regularFile
        default:
            kind = .other
        }

        errno = 0
        let accessControlList = acl_get_fd_np(descriptor, ACL_TYPE_EXTENDED)
        let aclErrno = errno
        let hasExtendedACL: Bool
        if let accessControlList {
            hasExtendedACL = true
            _ = acl_free(UnsafeMutableRawPointer(accessControlList))
        } else if aclErrno == ENOENT {
            hasExtendedACL = false
        } else {
            throw StorageError(
                operation: "inspect helper storage ACL",
                code: aclErrno
            )
        }

        return HelperStorageSafety.Metadata(
            kind: kind,
            ownerUID: UInt32(fileStatus.st_uid),
            ownerGID: UInt32(fileStatus.st_gid),
            permissions: UInt32(fileStatus.st_mode & mode_t(0o7777)),
            linkCount: UInt64(fileStatus.st_nlink),
            hasExtendedACL: hasExtendedACL
        )
    }

    private func readTrustedSentinel() throws -> OverrideSentinel? {
        var directoryDescriptor = try openSecureWorkDirectory()
        defer {
            if directoryDescriptor >= 0 {
                _ = Darwin.close(directoryDescriptor)
            }
        }

        var fileDescriptor = openat(
            directoryDescriptor,
            HelperPaths.sentinelFilename,
            O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC
        )
        if fileDescriptor < 0 {
            let openErrno = errno
            if openErrno == ENOENT {
                try closeStorageDescriptor(
                    &directoryDescriptor,
                    operation: "close helper work directory after absent sentinel"
                )
                return nil
            }
            throw StorageError(
                operation: "open recovery sentinel without following links",
                code: openErrno
            )
        }
        defer {
            if fileDescriptor >= 0 {
                _ = Darwin.close(fileDescriptor)
            }
        }

        let directoryMetadata = try storageMetadata(for: directoryDescriptor)
        let sentinelMetadata = try storageMetadata(for: fileDescriptor)
        guard HelperStorageSafety.isTrustedSentinel(
            workDirectory: directoryMetadata,
            sentinel: sentinelMetadata
        ) else {
            throw StorageError(
                operation: "recovery sentinel is not an exact root:wheel single-link mode 0600 regular file without an ACL",
                code: nil
            )
        }

        let data = try readSentinelData(from: fileDescriptor)
        guard let record = IPCCoding.decode(OverrideSentinel.self, from: data) else {
            throw StorageError(
                operation: "recovery sentinel contents are not valid",
                code: nil
            )
        }
        try closeStorageDescriptor(
            &fileDescriptor,
            operation: "close recovery sentinel after trusted read"
        )
        try closeStorageDescriptor(
            &directoryDescriptor,
            operation: "close helper work directory after trusted read"
        )
        return record
    }

    private func readSentinelData(from fileDescriptor: Int32) throws -> Data {
        var result = Data()
        var buffer = [UInt8](repeating: 0, count: 4 * 1024)

        while true {
            let byteCount = buffer.withUnsafeMutableBytes { bytes in
                Darwin.read(fileDescriptor, bytes.baseAddress, bytes.count)
            }
            if byteCount == 0 { return result }
            if byteCount < 0 {
                let readErrno = errno
                if readErrno == EINTR { continue }
                throw StorageError(
                    operation: "read recovery sentinel",
                    code: readErrno
                )
            }

            let count = Int(byteCount)
            guard result.count <= Self.maximumSentinelBytes - count else {
                throw StorageError(
                    operation: "recovery sentinel exceeds the maximum reviewed size",
                    code: nil
                )
            }
            result.append(contentsOf: buffer.prefix(count))
        }
    }

    private func writeSentinel(_ sentinel: OverrideSentinel) throws {
        let data = try IPCCoding.encoder().encode(sentinel)
        guard data.count <= Self.maximumSentinelBytes else {
            throw StorageError(
                operation: "encoded recovery sentinel exceeds the maximum reviewed size",
                code: nil
            )
        }

        var directoryDescriptor = try openSecureWorkDirectory()
        defer {
            if directoryDescriptor >= 0 {
                _ = Darwin.close(directoryDescriptor)
            }
        }

        var fileDescriptor = openat(
            directoryDescriptor,
            HelperPaths.sentinelFilename,
            O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC,
            mode_t(0o600)
        )
        guard fileDescriptor >= 0 else {
            throw StorageError(
                operation: "exclusively create recovery sentinel",
                code: errno
            )
        }
        defer {
            if fileDescriptor >= 0 {
                _ = Darwin.close(fileDescriptor)
            }
        }

        guard fchown(fileDescriptor, 0, 0) == 0 else {
            throw StorageError(operation: "set recovery sentinel owner", code: errno)
        }
        guard fchmod(fileDescriptor, mode_t(0o600)) == 0 else {
            throw StorageError(operation: "set recovery sentinel mode", code: errno)
        }

        let directoryMetadata = try storageMetadata(for: directoryDescriptor)
        let initialSentinelMetadata = try storageMetadata(for: fileDescriptor)
        guard HelperStorageSafety.isTrustedSentinel(
            workDirectory: directoryMetadata,
            sentinel: initialSentinelMetadata
        ) else {
            throw StorageError(
                operation: "new recovery sentinel metadata is not trusted",
                code: nil
            )
        }

        try data.withUnsafeBytes { bytes in
            var offset = 0
            while offset < bytes.count {
                let byteCount = Darwin.write(
                    fileDescriptor,
                    bytes.baseAddress?.advanced(by: offset),
                    bytes.count - offset
                )
                if byteCount < 0 {
                    let writeErrno = errno
                    if writeErrno == EINTR { continue }
                    throw StorageError(
                        operation: "write recovery sentinel",
                        code: writeErrno
                    )
                }
                guard byteCount > 0 else {
                    throw StorageError(
                        operation: "write recovery sentinel made no progress",
                        code: nil
                    )
                }
                offset += byteCount
            }
        }

        try fullySynchronize(
            fileDescriptor,
            operation: "fully synchronize recovery sentinel"
        )
        let finalDirectoryMetadata = try storageMetadata(
            for: directoryDescriptor
        )
        let finalSentinelMetadata = try storageMetadata(for: fileDescriptor)
        guard HelperStorageSafety.isTrustedSentinel(
            workDirectory: finalDirectoryMetadata,
            sentinel: finalSentinelMetadata
        ) else {
            throw StorageError(
                operation: "persisted recovery sentinel metadata changed before arm",
                code: nil
            )
        }

        try closeStorageDescriptor(
            &fileDescriptor,
            operation: "close fully synchronized recovery sentinel"
        )
        try fullySynchronize(
            directoryDescriptor,
            operation: "fully synchronize recovery sentinel directory entry"
        )
        try closeStorageDescriptor(
            &directoryDescriptor,
            operation: "close fully synchronized recovery sentinel directory"
        )
    }

    private func removeSentinelFile() throws {
        var directoryDescriptor = try openSecureWorkDirectory()
        defer {
            if directoryDescriptor >= 0 {
                _ = Darwin.close(directoryDescriptor)
            }
        }

        if unlinkat(directoryDescriptor, HelperPaths.sentinelFilename, 0) != 0 {
            let unlinkErrno = errno
            if unlinkErrno != ENOENT {
                throw StorageError(
                    operation: "remove recovery sentinel",
                    code: unlinkErrno
                )
            }
        }
        try fullySynchronize(
            directoryDescriptor,
            operation: "fully synchronize recovery sentinel removal"
        )
        try closeStorageDescriptor(
            &directoryDescriptor,
            operation: "close fully synchronized recovery sentinel removal directory"
        )
    }

    private func persistDurableMutationMarker(
        _ marker: DurableMutationMarker
    ) throws {
        let data = try IPCCoding.encoder().encode(marker)
        guard data.count <= Self.maximumDurableMutationMarkerBytes else {
            throw StorageError(
                operation: "encoded durable mutation marker exceeds the maximum reviewed size",
                code: nil
            )
        }

        var directoryDescriptor = try openSecureWorkDirectory()
        defer {
            if directoryDescriptor >= 0 {
                _ = Darwin.close(directoryDescriptor)
            }
        }
        let temporaryFilename = ".mutation-in-flight-\(UUID().uuidString).tmp"
        var temporaryPublished = false
        defer {
            if !temporaryPublished, directoryDescriptor >= 0 {
                _ = unlinkat(directoryDescriptor, temporaryFilename, 0)
            }
        }

        var fileDescriptor = openat(
            directoryDescriptor,
            temporaryFilename,
            O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC,
            mode_t(0o600)
        )
        guard fileDescriptor >= 0 else {
            throw StorageError(
                operation: "exclusively create durable mutation marker candidate",
                code: errno
            )
        }
        defer {
            if fileDescriptor >= 0 {
                _ = Darwin.close(fileDescriptor)
            }
        }

        guard fchown(fileDescriptor, 0, 0) == 0,
              fchmod(fileDescriptor, mode_t(0o600)) == 0 else {
            throw StorageError(
                operation: "set durable mutation marker ownership and mode",
                code: errno
            )
        }
        let directoryMetadata = try storageMetadata(for: directoryDescriptor)
        let initialFileMetadata = try storageMetadata(for: fileDescriptor)
        guard HelperStorageSafety.isTrustedSentinel(
            workDirectory: directoryMetadata,
            sentinel: initialFileMetadata
        ) else {
            throw StorageError(
                operation: "new durable mutation marker metadata is not trusted",
                code: nil
            )
        }

        try data.withUnsafeBytes { bytes in
            var offset = 0
            while offset < bytes.count {
                let byteCount = Darwin.write(
                    fileDescriptor,
                    bytes.baseAddress?.advanced(by: offset),
                    bytes.count - offset
                )
                if byteCount < 0 {
                    let writeErrno = errno
                    if writeErrno == EINTR { continue }
                    throw StorageError(
                        operation: "write durable mutation marker candidate",
                        code: writeErrno
                    )
                }
                guard byteCount > 0 else {
                    throw StorageError(
                        operation: "write durable mutation marker candidate made no progress",
                        code: nil
                    )
                }
                offset += byteCount
            }
        }
        try fullySynchronize(
            fileDescriptor,
            operation: "fully synchronize durable mutation marker candidate"
        )
        let finalFileMetadata = try storageMetadata(for: fileDescriptor)
        guard HelperStorageSafety.isTrustedSentinel(
            workDirectory: directoryMetadata,
            sentinel: finalFileMetadata
        ) else {
            throw StorageError(
                operation: "durable mutation marker metadata changed before publication",
                code: nil
            )
        }
        try closeStorageDescriptor(
            &fileDescriptor,
            operation: "close fully synchronized durable mutation marker candidate"
        )

        guard renameat(
            directoryDescriptor,
            temporaryFilename,
            directoryDescriptor,
            HelperPaths.durableMutationMarkerFilename
        ) == 0 else {
            throw StorageError(
                operation: "atomically publish durable mutation marker",
                code: errno
            )
        }
        temporaryPublished = true
        try fullySynchronize(
            directoryDescriptor,
            operation: "fully synchronize durable mutation marker directory entry"
        )
        try closeStorageDescriptor(
            &directoryDescriptor,
            operation: "close fully synchronized durable mutation marker directory"
        )
    }

    private func loadDurableMutationMarker() throws {
        var directoryDescriptor = try openSecureWorkDirectory()
        defer {
            if directoryDescriptor >= 0 {
                _ = Darwin.close(directoryDescriptor)
            }
        }
        var fileDescriptor = openat(
            directoryDescriptor,
            HelperPaths.durableMutationMarkerFilename,
            O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC
        )
        if fileDescriptor < 0 {
            let openErrno = errno
            if openErrno == ENOENT {
                try closeStorageDescriptor(
                    &directoryDescriptor,
                    operation: "close helper work directory after absent mutation marker"
                )
                durableMutationMarker = nil
                durableMutationMarkerLoadedFromPriorProcess = false
                durableMutationMarkerPriorChildExitProvenByReboot = false
                durableMutationMarkerFailure = nil
                return
            }
            throw StorageError(
                operation: "open durable mutation marker without following links",
                code: openErrno
            )
        }
        defer {
            if fileDescriptor >= 0 {
                _ = Darwin.close(fileDescriptor)
            }
        }

        let directoryMetadata = try storageMetadata(for: directoryDescriptor)
        let markerMetadata = try storageMetadata(for: fileDescriptor)
        guard HelperStorageSafety.isTrustedSentinel(
            workDirectory: directoryMetadata,
            sentinel: markerMetadata
        ) else {
            throw StorageError(
                operation: "durable mutation marker metadata is not trusted",
                code: nil
            )
        }
        let data = try readStorageRecordData(
            from: fileDescriptor,
            maximumBytes: Self.maximumDurableMutationMarkerBytes,
            operation: "read durable mutation marker"
        )
        guard let marker = try? IPCCoding.decoder().decode(
            DurableMutationMarker.self,
            from: data
        ), (marker.version == 1
                || marker.version == DurableMutationMarker.currentVersion),
           marker.startedAt.timeIntervalSinceReferenceDate.isFinite else {
            throw StorageError(
                operation: "durable mutation marker contents or version are unsupported",
                code: nil
            )
        }
        if marker.version == DurableMutationMarker.currentVersion,
           marker.bootSessionUUID == nil {
            throw StorageError(
                operation: "current durable mutation marker lacks its boot-session identity",
                code: nil
            )
        }
        try closeStorageDescriptor(
            &fileDescriptor,
            operation: "close durable mutation marker after trusted read"
        )
        try closeStorageDescriptor(
            &directoryDescriptor,
            operation: "close helper work directory after mutation marker read"
        )
        durableMutationMarker = marker
        durableMutationMarkerLoadedFromPriorProcess = true
        durableMutationMarkerPriorChildExitProvenByReboot =
            DurableMutationRecoverySafety.priorChildExitIsProven(
                markerBootSessionUUID: marker.bootSessionUUID,
                currentBootSessionUUID: currentBootSessionUUID
            )
        durableMutationMarkerFailure = nil
        if durableMutationMarkerPriorChildExitProvenByReboot {
            log.info("a reboot boundary proves the prior mutating child cannot remain; bounded recovery may proceed")
        } else {
            log.critical("same-boot prior-command child exit is unproven; restart cannot clear the marker, and a reboot is the reviewed recovery boundary")
        }
    }

    private func removeDurableMutationMarkerFile() throws {
        var directoryDescriptor = try openSecureWorkDirectory()
        defer {
            if directoryDescriptor >= 0 {
                _ = Darwin.close(directoryDescriptor)
            }
        }
        if unlinkat(
            directoryDescriptor,
            HelperPaths.durableMutationMarkerFilename,
            0
        ) != 0 {
            let unlinkErrno = errno
            if unlinkErrno != ENOENT {
                throw StorageError(
                    operation: "remove durable mutation marker",
                    code: unlinkErrno
                )
            }
        }
        try fullySynchronize(
            directoryDescriptor,
            operation: "fully synchronize durable mutation marker removal"
        )
        try closeStorageDescriptor(
            &directoryDescriptor,
            operation: "close fully synchronized mutation marker removal directory"
        )
    }

    private func persistScheduledWakeReconciliationMarker(
        _ marker: ScheduledWakeReconciliationMarker
    ) throws {
        let data = try IPCCoding.encoder().encode(marker)
        guard data.count <= Self.maximumScheduledWakeReconciliationMarkerBytes else {
            throw StorageError(
                operation: "encoded scheduled-wake reconciliation marker exceeds the maximum reviewed size",
                code: nil
            )
        }

        var directoryDescriptor = try openSecureWorkDirectory()
        defer {
            if directoryDescriptor >= 0 {
                _ = Darwin.close(directoryDescriptor)
            }
        }
        let temporaryFilename = ".scheduled-wake-recovery-\(UUID().uuidString).tmp"
        var temporaryPublished = false
        defer {
            if !temporaryPublished, directoryDescriptor >= 0 {
                _ = unlinkat(directoryDescriptor, temporaryFilename, 0)
            }
        }

        var fileDescriptor = openat(
            directoryDescriptor,
            temporaryFilename,
            O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC,
            mode_t(0o600)
        )
        guard fileDescriptor >= 0 else {
            throw StorageError(
                operation: "exclusively create scheduled-wake reconciliation marker candidate",
                code: errno
            )
        }
        defer {
            if fileDescriptor >= 0 {
                _ = Darwin.close(fileDescriptor)
            }
        }

        guard fchown(fileDescriptor, 0, 0) == 0,
              fchmod(fileDescriptor, mode_t(0o600)) == 0 else {
            throw StorageError(
                operation: "set scheduled-wake reconciliation marker ownership and mode",
                code: errno
            )
        }
        let directoryMetadata = try storageMetadata(for: directoryDescriptor)
        let initialFileMetadata = try storageMetadata(for: fileDescriptor)
        guard HelperStorageSafety.isTrustedSentinel(
            workDirectory: directoryMetadata,
            sentinel: initialFileMetadata
        ) else {
            throw StorageError(
                operation: "new scheduled-wake reconciliation marker metadata is not trusted",
                code: nil
            )
        }

        try data.withUnsafeBytes { bytes in
            var offset = 0
            while offset < bytes.count {
                let byteCount = Darwin.write(
                    fileDescriptor,
                    bytes.baseAddress?.advanced(by: offset),
                    bytes.count - offset
                )
                if byteCount < 0 {
                    let writeErrno = errno
                    if writeErrno == EINTR { continue }
                    throw StorageError(
                        operation: "write scheduled-wake reconciliation marker candidate",
                        code: writeErrno
                    )
                }
                guard byteCount > 0 else {
                    throw StorageError(
                        operation: "write scheduled-wake reconciliation marker candidate made no progress",
                        code: nil
                    )
                }
                offset += byteCount
            }
        }
        try fullySynchronize(
            fileDescriptor,
            operation: "fully synchronize scheduled-wake reconciliation marker candidate"
        )
        let finalFileMetadata = try storageMetadata(for: fileDescriptor)
        guard HelperStorageSafety.isTrustedSentinel(
            workDirectory: directoryMetadata,
            sentinel: finalFileMetadata
        ) else {
            throw StorageError(
                operation: "scheduled-wake reconciliation marker metadata changed before publication",
                code: nil
            )
        }
        try closeStorageDescriptor(
            &fileDescriptor,
            operation: "close fully synchronized scheduled-wake reconciliation marker candidate"
        )

        guard renameat(
            directoryDescriptor,
            temporaryFilename,
            directoryDescriptor,
            HelperPaths.scheduledWakeReconciliationMarkerFilename
        ) == 0 else {
            throw StorageError(
                operation: "atomically publish scheduled-wake reconciliation marker",
                code: errno
            )
        }
        temporaryPublished = true
        try fullySynchronize(
            directoryDescriptor,
            operation: "fully synchronize scheduled-wake reconciliation marker directory entry"
        )
        try closeStorageDescriptor(
            &directoryDescriptor,
            operation: "close fully synchronized scheduled-wake reconciliation marker directory"
        )
    }

    private func loadScheduledWakeReconciliationMarker() throws {
        var directoryDescriptor = try openSecureWorkDirectory()
        defer {
            if directoryDescriptor >= 0 {
                _ = Darwin.close(directoryDescriptor)
            }
        }
        var fileDescriptor = openat(
            directoryDescriptor,
            HelperPaths.scheduledWakeReconciliationMarkerFilename,
            O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC
        )
        if fileDescriptor < 0 {
            let openErrno = errno
            if openErrno == ENOENT {
                try closeStorageDescriptor(
                    &directoryDescriptor,
                    operation: "close helper work directory after absent scheduled-wake reconciliation marker"
                )
                scheduledWakeReconciliationMarker = nil
                scheduledWakeReconciliationMarkerLoaded = true
                scheduledWakeReconciliationMarkerFailure = nil
                return
            }
            throw StorageError(
                operation: "open scheduled-wake reconciliation marker without following links",
                code: openErrno
            )
        }
        defer {
            if fileDescriptor >= 0 {
                _ = Darwin.close(fileDescriptor)
            }
        }

        let directoryMetadata = try storageMetadata(for: directoryDescriptor)
        let markerMetadata = try storageMetadata(for: fileDescriptor)
        guard HelperStorageSafety.isTrustedSentinel(
            workDirectory: directoryMetadata,
            sentinel: markerMetadata
        ) else {
            throw StorageError(
                operation: "scheduled-wake reconciliation marker metadata is not trusted",
                code: nil
            )
        }
        let data = try readStorageRecordData(
            from: fileDescriptor,
            maximumBytes: Self.maximumScheduledWakeReconciliationMarkerBytes,
            operation: "read scheduled-wake reconciliation marker"
        )
        guard let marker = try? IPCCoding.decoder().decode(
            ScheduledWakeReconciliationMarker.self,
            from: data
        ), marker.version == ScheduledWakeReconciliationMarker.currentVersion,
           marker.startedAt.timeIntervalSinceReferenceDate.isFinite else {
            throw StorageError(
                operation: "scheduled-wake reconciliation marker contents or version are unsupported",
                code: nil
            )
        }
        try closeStorageDescriptor(
            &fileDescriptor,
            operation: "close scheduled-wake reconciliation marker after trusted read"
        )
        try closeStorageDescriptor(
            &directoryDescriptor,
            operation: "close helper work directory after scheduled-wake reconciliation marker read"
        )
        scheduledWakeReconciliationMarker = marker
        scheduledWakeReconciliationMarkerLoaded = true
        scheduledWakeReconciliationMarkerFailure = nil
    }

    private func removeScheduledWakeReconciliationMarkerFile() throws {
        var directoryDescriptor = try openSecureWorkDirectory()
        defer {
            if directoryDescriptor >= 0 {
                _ = Darwin.close(directoryDescriptor)
            }
        }
        if unlinkat(
            directoryDescriptor,
            HelperPaths.scheduledWakeReconciliationMarkerFilename,
            0
        ) != 0 {
            let unlinkErrno = errno
            if unlinkErrno != ENOENT {
                throw StorageError(
                    operation: "remove scheduled-wake reconciliation marker",
                    code: unlinkErrno
                )
            }
        }
        try fullySynchronize(
            directoryDescriptor,
            operation: "fully synchronize scheduled-wake reconciliation marker removal"
        )
        try closeStorageDescriptor(
            &directoryDescriptor,
            operation: "close fully synchronized scheduled-wake reconciliation marker removal directory"
        )
    }

    private func ensureScheduledWakeReconciliationMarker() throws {
        if !scheduledWakeReconciliationMarkerLoaded {
            try loadScheduledWakeReconciliationMarker()
        }
        if let failure = scheduledWakeReconciliationMarkerFailure {
            throw ScheduledWakeAdapterError(
                message: "scheduled-wake reconciliation marker is untrusted: \(failure)"
            )
        }
        guard scheduledWakeReconciliationMarker == nil else { return }

        let candidate = ScheduledWakeReconciliationMarker()
        do {
            try persistScheduledWakeReconciliationMarker(candidate)
        } catch {
            scheduledWakeReconciliationMarkerLoaded = false
            scheduledWakeReconciliationMarkerFailure = error.localizedDescription
            throw error
        }
        scheduledWakeReconciliationMarker = candidate
        scheduledWakeReconciliationMarkerLoaded = true
        scheduledWakeReconciliationMarkerFailure = nil
    }

    private func clearScheduledWakeReconciliationMarkerAfterProof() throws {
        if !scheduledWakeReconciliationMarkerLoaded {
            try loadScheduledWakeReconciliationMarker()
        }
        if let failure = scheduledWakeReconciliationMarkerFailure {
            throw ScheduledWakeAdapterError(
                message: "scheduled-wake reconciliation marker is untrusted: \(failure)"
            )
        }
        guard scheduledWakeReconciliationMarker != nil else { return }
        do {
            try removeScheduledWakeReconciliationMarkerFile()
        } catch {
            scheduledWakeReconciliationMarkerLoaded = false
            scheduledWakeReconciliationMarkerFailure = error.localizedDescription
            throw error
        }
        scheduledWakeReconciliationMarker = nil
        scheduledWakeReconciliationMarkerLoaded = true
        scheduledWakeReconciliationMarkerFailure = nil
    }

    /// A failed create/write/full-sync/close may still have published a marker.
    /// Resolve it immediately from the trusted descriptor path; corrupt or
    /// untrusted bytes fall back to ordinary-sleep recovery and remain pending.
    private func reconcileSentinelPersistenceFailure(reason: String) {
        do {
            guard let record = try readTrustedSentinel() else { return }
            performRestore(record, reason: reason)
        } catch {
            recoverUntrustedSentinel(
                reason: "\(reason); persisted marker cannot be trusted: \(error.localizedDescription)"
            )
        }
    }

    fileprivate func handleArm(_ options: HelperArmOptions, connectionID: UUID, reply: @escaping @Sendable (Data) -> Void) {
        guard connectionSupervision.contains(connectionID) else {
            reply(replyData(ok: false, error: "the requesting connection already ended; refusing to arm"))
            return
        }
        guard HelperClientAdmissionSafety.allows(
            .arm,
            identity: options.clientIdentity
        ) else {
            reply(replyData(
                ok: false,
                error: "client protocol or safety revision is not current; refusing to arm"
            ))
            return
        }
        guard !unresolvedMutationRemains() else {
            reply(replyData(
                ok: false,
                error: "a prior power command has not been observed to exit; refusing to arm"
            ))
            return
        }
        guard !durableMutationMarkerRequiresRecovery else {
            reply(replyData(
                ok: false,
                error: "a durable prior-command uncertainty requires reviewed recovery; refusing to arm"
            ))
            return
        }
        advanceLifecycle()
        guard HelperTerminationSafety.allows(.arm, whileTerminationRequested: terminationRequested) else {
            reply(replyData(ok: false, error: "helper termination is pending; refusing to arm"))
            return
        }
        guard restorePending == nil else {
            reply(replyData(ok: false, error: "helper is recovering from a failed restore; cannot arm"))
            return
        }

        switch HelperSessionOwnershipSafety.armDisposition(
            hasActiveSession: sentinel != nil
        ) {
        case .beginFreshSession:
            break
        case .rejectActiveSession:
            reply(replyData(
                ok: false,
                error: "an active session already has a supervising connection; refusing another arm"
            ))
            return
        }

        let ttl = min(max(options.watchdogTTL, HelperArmOptions.watchdogTTLRange.lowerBound),
                      HelperArmOptions.watchdogTTLRange.upperBound)

        // The complete worst-case transaction includes enable, activation +
        // proof, and a full restoration + proof if activation cannot be
        // verified. Process launch and other queue work have no real-time
        // bound, so only the child waits can be budgeted here.
        let maximumBlockingCommandCount =
            HelperSupervisionTiming.maximumArmTransactionCommandCount
        guard HelperSupervisionTiming.isWithinWatchdogBudget(
            commandCount: maximumBlockingCommandCount,
            watchdogTTL: ttl
        ) else {
            reply(replyData(ok: false, error: "helper command timing exceeds the watchdog safety budget"))
            return
        }

        // Snapshot optional settings before the final sleep-state preflight.
        // The `pmset -g custom` child wait is bounded after launch, but the
        // snapshot must not create a preflight-to-mutation window while an
        // override is already active.
        let custom: String?
        if options.lowPowerMode || options.tcpKeepAlive {
            do {
                custom = try PMSet.readCustom()
            } catch {
                custom = nil
                log.error("could not snapshot optional pmset settings; optional mutations will be skipped: \(error)")
            }
        } else {
            custom = nil
        }

        let preparedAt = Date()
        var record = OverrideSentinel(
            armedAt: preparedAt,
            watchdogTTL: ttl,
            watchdogDeadline: preparedAt.addingTimeInterval(ttl),
            priorSleepDisabled: false
        )

        if options.lowPowerMode, let custom {
            if let key = PMSet.lowPowerModeKey(fromCustom: custom) {
                if let priors = ManagedSettingRestorationSafety.capturedPriors(
                    for: key,
                    fromCustom: custom
                ) {
                    record.lowPowerModeKey = key
                    record.priorLowPowerMode = priors
                } else {
                    log.info("low power mode requested but no scoped numeric prior was found — skipping")
                }
            } else {
                log.info("low power mode requested but unsupported on this system — skipping")
            }
        }
        if options.tcpKeepAlive, let custom {
            if let priors = ManagedSettingRestorationSafety.capturedPriors(
                for: "tcpkeepalive",
                fromCustom: custom
            ) {
                record.priorTCPKeepAlive = priors
            } else {
                log.info("tcpkeepalive requested but no restorable prior was found — skipping")
            }
        }

        guard let managedActivationPlan = ManagedSettingRestorationSafety.plan(
            for: record,
            target: .activation
        ) else {
            reply(replyData(ok: false, error: "captured managed-setting state is not safely restorable"))
            return
        }

        // Fresh arm. Take ownership only from a readable, inactive state,
        // after every potentially blocking snapshot operation.
        switch SleepOverrideSafety.preflight(observed: PMSet.readSleepDisabled()) {
        case .safeToArm:
            break
        case .externalOverrideActive:
            reply(replyData(
                ok: false,
                error: "the sleep override is already active outside Lidless; restore normal sleep before arming"
            ))
            return
        case .stateUnverified:
            reply(replyData(
                ok: false,
                error: "could not verify the current sleep state; refusing to arm"
            ))
            return
        }

        do {
            try writeSentinel(record)
        } catch {
            reconcileSentinelPersistenceFailure(
                reason: "fresh arm sentinel persistence failed"
            )
            reply(replyData(ok: false, error: "could not persist recovery sentinel: \(error.localizedDescription)"))
            return
        }

        // The sentinel write can block without end, but the override is not
        // active yet. Re-confirm immediately afterward so that time cannot
        // become an avoidable ownership window. The remaining registry-read
        // to pmset mutation race is cross-process and not atomic on macOS.
        switch SleepOverrideSafety.preflight(observed: PMSet.readSleepDisabled()) {
        case .safeToArm:
            break
        case .externalOverrideActive:
            rejectPreparedArm(
                record,
                error: "the sleep override became active outside Lidless while preparing to arm",
                reply: reply
            )
            return
        case .stateUnverified:
            rejectPreparedArm(
                record,
                error: "the sleep state became unreadable while preparing to arm",
                reply: reply
            )
            return
        }

        // Install ownership before the enabling command. The command runner's
        // tested child-wait budget is below the minimum TTL; process launch
        // and other queue work remain unbounded, while the disk sentinel is
        // the crash supervisor.
        sentinel = record
        armedConnectionID = connectionID
        watchdogDeadline = .now() + ttl

        do {
            try performTrackedMutation(.enableOverride) {
                try PMSet.setSleepDisabled(true)
            }
        } catch {
            // Outcome UNKNOWN, not "not applied": pmset can mutate the
            // setting and then hang past the timeout. Abort the arm, but
            // only drop the sentinel if the registry verifiably reads the
            // prior state — otherwise the sentinel stays and the retry loop
            // + launchd own driving it back to safe.
            log.error("failed to enable override: \(error)")
            if registerUnresolvedMutation(from: error) {
                parkRestore(
                    record,
                    message: "override-enable child termination is unproven; retaining recovery sentinel"
                )
                reply(replyData(
                    ok: false,
                    error: "the override command timed out without a proven child exit; recovery remains supervised"
                ))
                return
            }
            abortFreshArm(record, reply: reply, error: "\(error)")
            return
        }

        let armReadback = PMSet.readSleepDisabled()
        if !SleepOverrideSafety.isVerified(expected: true, observed: armReadback) {
            log.error("disablesleep readback is not verifiably 1 after set — reverting")
            abortFreshArm(record, reply: reply, error: "system did not verifiably accept the sleep override")
            return
        }

        // Optional settings are part of the requested arm transaction. The
        // original snapshot predates the sentinel write and override enable,
        // so prove those captured priors are still exact inside the durable
        // mutation boundary immediately before changing them. This narrows
        // the unavoidable cross-process registry-to-pmset race without ever
        // treating stale priors as restoration authority.
        do {
            try performTrackedMutation(.applyManagedSettings) {
                let freshPriorReadback: String?
                if managedActivationPlan.isEmpty {
                    freshPriorReadback = nil
                } else {
                    freshPriorReadback = try PMSet.readCustom()
                }
                guard ManagedSettingRestorationSafety.isProven(
                    for: record,
                    target: .restoration,
                    fromCustom: freshPriorReadback
                ) else {
                    throw ScheduledWakeAdapterError(
                        message: "captured managed settings changed while preparing to arm"
                    )
                }
                try PMSet.apply(managedActivationPlan)
            }
        } catch {
            _ = registerUnresolvedMutation(from: error)
            performRestore(record, reason: "managed-setting activation failed")
            reply(replyData(
                ok: false,
                error: "managed settings could not be applied and verified; normal-sleep recovery started"
            ))
            return
        }

        let activationReadback: String?
        if managedActivationPlan.isEmpty {
            activationReadback = nil
        } else {
            do {
                activationReadback = try PMSet.readCustom()
            } catch {
                performRestore(
                    record,
                    reason: "managed-setting activation readback failed"
                )
                reply(replyData(
                    ok: false,
                    error: "managed settings could not be read back; normal-sleep recovery started"
                ))
                return
            }
        }
        guard ManagedSettingRestorationSafety.isProven(
            for: record,
            target: .activation,
            fromCustom: activationReadback
        ) else {
            performRestore(
                record,
                reason: "managed-setting activation proof failed"
            )
            reply(replyData(
                ok: false,
                error: "managed settings did not match the requested values; normal-sleep recovery started"
            ))
            return
        }

        // Rebase the in-memory watchdog at the exact complete proof point.
        // The disk sentinel remains immutable while active.
        record.watchdogDeadline = Date().addingTimeInterval(ttl)
        sentinel = record
        watchdogDeadline = .now() + ttl
        let status = currentStatus()
        let result = HelperReply(ok: true, status: status)
        guard SleepOverrideSafety.isArmProven(result) else {
            log.critical("fresh arm lost readable proof before reply — restoring")
            abortFreshArm(record, reply: reply, error: "the sleep override could not be verified at completion")
            return
        }

        log.info("armed: override ON and verified (ttl \(Int(ttl))s, lpm \(record.lowPowerModeKey ?? "off"), tcp \(record.priorTCPKeepAlive != nil ? "on" : "off"))")
        reply(IPCCoding.encode(result))
    }

    /// A second preflight rejected an arm after its recovery sentinel was
    /// written but before Lidless mutated the system. Normally this only
    /// removes the unused sentinel. If cleanup itself fails, retain explicit
    /// supervision and drive the machine to the fail-safe normal-sleep state
    /// rather than leave a configured-relaunch marker with ambiguous ownership.
    private func rejectPreparedArm(
        _ record: OverrideSentinel,
        error: String,
        reply: @escaping @Sendable (Data) -> Void
    ) {
        do {
            try removeSentinelFile()
        } catch {
            log.critical("prepared arm was rejected but sentinel cleanup failed: \(error) — forcing normal-sleep recovery")
            sentinel = record
            armedConnectionID = nil
            watchdogDeadline = .now()
            performRestore(record, reason: "rejected arm sentinel cleanup failed")
        }
        reply(replyData(ok: false, error: error))
    }

    /// Failed fresh arm with unknown side effects. Best-effort revert, then
    /// verify: sentinel is removed only when the registry provably shows the
    /// prior state; anything else parks in `restorePending` for the in-process
    /// 30s retry. If the marker remains, `KeepAlive.PathState` requests relaunch.
    private func abortFreshArm(_ record: OverrideSentinel, reply: @escaping @Sendable (Data) -> Void, error: String) {
        sentinel = nil
        armedConnectionID = nil
        watchdogDeadline = .distantFuture
        let restoreTarget = SleepOverrideSafety.restoreTarget(recordedPrior: record.priorSleepDisabled)
        do {
            try performTrackedMutation(.restoreOverride, allowsExistingMarker: true) {
                try PMSet.setSleepDisabled(restoreTarget)
            }
        } catch {
            if registerUnresolvedMutation(from: error) {
                parkRestore(
                    record,
                    message: "fresh-arm rollback child termination is unproven; retaining recovery sentinel"
                )
                reply(replyData(
                    ok: false,
                    error: "the failed arm could not prove its rollback child exited; recovery remains supervised"
                ))
                return
            }
        }
        if SleepOverrideSafety.isVerified(
            expected: restoreTarget,
            observed: PMSet.readSleepDisabled()
        ) {
            do {
                try removeSentinelFile()
                if durableMutationMarker != nil {
                    try clearDurableMutationMarkerAfterObservedExit()
                }
            } catch {
                log.error("aborted arm restored sleep but durable cleanup failed — retrying")
                restorePending = record
                scheduleRestoreRetry()
            }
        } else {
            log.critical("aborted arm but the override state is unverified — keeping sentinel and retrying restore")
            restorePending = record
            scheduleRestoreRetry()
        }
        reply(replyData(ok: false, error: error))
    }

    /// The single restore path used by every trigger. Sets the world back to
    /// the sentinel's priors; only on full success does an owned sentinel
    /// leave the disk. On failure, state moves to `restorePending` and the
    /// tick retries while this process remains. A trusted disk marker requests
    /// launchd relaunch; the untrusted-storage fallback may be memory-only.
    private func performRestore(_ record: OverrideSentinel, reason: String) {
        guard !unresolvedMutationRemains() else {
            parkRestore(
                record,
                message: "RESTORE WAITING (\(reason)): a prior mutating child has not been observed to exit"
            )
            return
        }
        let restoreTarget = SleepOverrideSafety.restoreTarget(recordedPrior: record.priorSleepDisabled)
        do {
            try performTrackedMutation(
                .restoreOverride,
                allowsExistingMarker: true
            ) {
                try PMSet.setSleepDisabled(restoreTarget)
            }
        } catch {
            _ = registerUnresolvedMutation(from: error)
            parkRestore(
                record,
                message: "RESTORE FAILED (\(reason)): \(error) — will retry"
            )
            return
        }

        let restoreReadback = PMSet.readSleepDisabled()
        if !SleepOverrideSafety.isVerified(
            expected: restoreTarget,
            observed: restoreReadback
        ) {
            parkRestore(
                record,
                message: "RESTORE sleep readback is unverified or mismatched (\(reason)) — will retry"
            )
            return
        }

        guard let managedRestorationPlan = ManagedSettingRestorationSafety.plan(
            for: record,
            target: .restoration
        ) else {
            parkRestore(
                record,
                message: "RESTORE managed-setting snapshot is invalid or unprovable (\(reason)) — retaining sentinel"
            )
            return
        }

        do {
            try performTrackedMutation(
                .applyManagedSettings,
                allowsExistingMarker: true
            ) {
                try PMSet.apply(managedRestorationPlan)
            }
        } catch {
            _ = registerUnresolvedMutation(from: error)
            parkRestore(
                record,
                message: "RESTORE managed-setting command failed (\(reason)): \(error) — will retry"
            )
            return
        }

        let managedReadback: String?
        if managedRestorationPlan.isEmpty {
            managedReadback = nil
        } else {
            do {
                managedReadback = try PMSet.readCustom()
            } catch {
                parkRestore(
                    record,
                    message: "RESTORE managed-setting readback failed (\(reason)): \(error) — will retry"
                )
                return
            }
        }
        guard ManagedSettingRestorationSafety.isRestorationProven(
            for: record,
            fromCustom: managedReadback
        ) else {
            parkRestore(
                record,
                message: "RESTORE managed-setting readback is missing or mismatched (\(reason)) — will retry"
            )
            return
        }

        if durableMutationMarkerRequiresReviewedResolution {
            parkRestore(
                record,
                message: "RESTORE VERIFIED (\(reason)) but same-boot prior-command child exit is unproven; retaining recovery sentinel until the reviewed reboot boundary"
            )
            return
        }

        do {
            try removeSentinelFile()
            if durableMutationMarker != nil {
                try clearDurableMutationMarkerAfterObservedExit()
            }
        } catch {
            parkRestore(
                record,
                message: "RESTORE verified all managed state but durable cleanup failed (\(reason)) — will retry"
            )
            return
        }
        sentinel = nil
        armedConnectionID = nil
        watchdogDeadline = .distantFuture
        restorePending = nil
        log.info("restored normal sleep and all managed settings (\(reason))")
    }

    private func parkRestore(_ record: OverrideSentinel, message: String) {
        log.critical(message)
        sentinel = nil
        armedConnectionID = nil
        watchdogDeadline = .distantFuture
        restorePending = record
        scheduleRestoreRetry()
    }

    /// Records only a command whose termination remained unproven. Ordinary
    /// nonzero exits and killed-and-reaped timeouts have no late-completion
    /// window and need no retained process object.
    @discardableResult
    private func registerUnresolvedMutation(from error: Error) -> Bool {
        guard let commandError = error as? PMSet.CommandError,
              commandError.terminationCertainty == .unproven,
              let witness = commandError.terminationWitness,
              !witness.isResolved
        else { return false }
        unresolvedMutationWitnesses.append(witness)
        return true
    }

    /// Prunes only children whose exact `Process` now reports termination.
    /// Callers run on the serial daemon queue.
    private func unresolvedMutationRemains() -> Bool {
        unresolvedMutationWitnesses.removeAll { $0.isResolved }
        return !unresolvedMutationWitnesses.isEmpty
    }

    private var durableMutationMarkerRequiresRecovery: Bool {
        durableMutationMarker != nil || durableMutationMarkerFailure != nil
    }

    private var durableMutationMarkerCanBeCleared: Bool {
        durableMutationMarker != nil
            && (!durableMutationMarkerLoadedFromPriorProcess
                || durableMutationMarkerPriorChildExitProvenByReboot)
            && !unresolvedMutationRemains()
    }

    private var durableMutationMarkerRequiresReviewedResolution: Bool {
        durableMutationMarkerFailure != nil
            || (durableMutationMarkerLoadedFromPriorProcess
                && !durableMutationMarkerPriorChildExitProvenByReboot)
    }

    private var durableMutationMarkerBlocksWakeAbsenceProof: Bool {
        durableMutationMarkerLoadedFromPriorProcess
            && !durableMutationMarkerPriorChildExitProvenByReboot
            && (durableMutationMarker?.operation.concernsScheduledWake == true
                || durableMutationMarkerFailure != nil)
    }

    /// Publish durable uncertainty before entering a mutating child. Ordinary
    /// exits (including a nonzero command result) authorize this same process
    /// to remove its marker. An unproven timeout, inherited marker, corrupt
    /// marker, or marker-removal failure remains explicit recovery state.
    private func performTrackedMutation(
        _ operation: DurableMutationMarker.Operation,
        allowsExistingMarker: Bool = false,
        _ body: () throws -> Void
    ) throws {
        let createdMarker: Bool
        if durableMutationMarker == nil, durableMutationMarkerFailure == nil {
            guard let currentBootSessionUUID else {
                throw ScheduledWakeAdapterError(
                    message: "kernel boot-session identity is unavailable; refusing a mutation that could not be recovered safely"
                )
            }
            let candidate = DurableMutationMarker(
                operation: operation,
                bootSessionUUID: currentBootSessionUUID
            )
            do {
                try persistDurableMutationMarker(candidate)
            } catch {
                durableMutationMarkerFailure = error.localizedDescription
                durableMutationMarkerLoadedFromPriorProcess = true
                throw error
            }
            durableMutationMarker = candidate
            durableMutationMarkerLoadedFromPriorProcess = false
            durableMutationMarkerPriorChildExitProvenByReboot = false
            createdMarker = true
        } else {
            guard allowsExistingMarker else {
                throw ScheduledWakeAdapterError(
                    message: "a durable prior-command uncertainty blocks another mutation"
                )
            }
            createdMarker = false
        }

        do {
            try body()
        } catch {
            if mutationTerminationIsUnproven(error) {
                throw error
            }
            if createdMarker {
                guard durableMutationMarkerCanBeCleared else {
                    throw ScheduledWakeAdapterError(
                        message: "the mutating child exit is not proven in this helper process"
                    )
                }
                try clearDurableMutationMarkerAfterObservedExit()
            }
            throw error
        }

        if createdMarker {
            guard durableMutationMarkerCanBeCleared else {
                throw ScheduledWakeAdapterError(
                    message: "the mutating child exit is not proven in this helper process"
                )
            }
            try clearDurableMutationMarkerAfterObservedExit()
        }
    }

    private func mutationTerminationIsUnproven(_ error: Error) -> Bool {
        guard let commandError = error as? PMSet.CommandError else {
            return false
        }
        return commandError.terminationCertainty == .unproven
    }

    private func clearDurableMutationMarkerAfterObservedExit() throws {
        guard durableMutationMarkerCanBeCleared else {
            throw ScheduledWakeAdapterError(
                message: "the mutating child exit is not proven in this helper process"
            )
        }
        try removeDurableMutationMarkerFile()
        durableMutationMarker = nil
        durableMutationMarkerLoadedFromPriorProcess = false
        durableMutationMarkerPriorChildExitProvenByReboot = false
        durableMutationMarkerFailure = nil
    }

    private func scheduleRestoreRetry() {
        nextRestoreAttempt = .now() + HelperTerminationSafety.restoreRetryDelay(terminationRequested: terminationRequested)
    }

    // MARK: - XPC entry points (hop to queue; every path must reply)

    fileprivate func handlePing(reply: @escaping @Sendable (Data) -> Void) {
        queue.async { [self] in
            lastActivity = Date()
            reply(IPCCoding.encode(currentStatus()))
        }
    }

    fileprivate func enqueueArm(_ optionsJSON: Data, connectionID: UUID, reply: @escaping @Sendable (Data) -> Void) {
        queue.async { [self] in
            lastActivity = Date()
            guard let options = IPCCoding.decode(HelperArmOptions.self, from: optionsJSON) else {
                reply(replyData(ok: false, error: "malformed arm options"))
                return
            }
            handleArm(options, connectionID: connectionID, reply: reply)
        }
    }

    fileprivate func handleHeartbeat(connectionID: UUID, reply: @escaping @Sendable (Data) -> Void) {
        queue.async { [self] in
            lastActivity = Date()
            switch HelperSessionOwnershipSafety.heartbeatDisposition(
                hasActiveSession: sentinel != nil,
                owner: armedConnectionID,
                requester: connectionID
            ) {
            case .renew:
                break
            case .rejectNoSession:
                reply(replyData(ok: false, error: "no active session"))
                return
            case .rejectNonOwner:
                reply(replyData(ok: false, error: "heartbeat connection does not own the active session"))
                return
            }
            guard var current = sentinel else {
                reply(replyData(ok: false, error: "no active session"))
                return
            }
            // The disk sentinel is immutable while active; recovery ignores
            // its diagnostic deadline. Refresh only queue-owned memory so a
            // slow filesystem can never erase a watchdog expiry.
            current.watchdogDeadline = Date().addingTimeInterval(current.watchdogTTL)
            sentinel = current
            watchdogDeadline = .now() + current.watchdogTTL
            let status = currentStatus()
            let result = HelperReply(ok: true, status: status)
            guard SleepOverrideSafety.isArmProven(result) else {
                log.critical("heartbeat could not prove the live override — restoring")
                performRestore(current, reason: "heartbeat proof failed")
                reply(replyData(ok: false, error: "the live override could not be verified; normal sleep recovery started"))
                return
            }
            reply(IPCCoding.encode(result))
        }
    }

    fileprivate func handleDisarm(_ optionsJSON: Data, reply: @escaping @Sendable (Data) -> Void) {
        queue.async { [self] in
            lastActivity = Date()
            guard let options = IPCCoding.decode(HelperDisarmOptions.self, from: optionsJSON) else {
                reply(replyData(ok: false, error: "malformed disarm options"))
                return
            }
            let forceSleepClientAllowed = !options.forceSleep
                || HelperClientAdmissionSafety.allows(
                    .forceSleep,
                    identity: options.clientIdentity
                )
            guard HelperClientAdmissionSafety.allows(
                .restoreNormalSleep,
                identity: options.clientIdentity
            ) else {
                // Kept as an explicit invariant even though de-risking restore
                // currently accepts every identity, including missing legacy
                // metadata.
                reply(replyData(ok: false, error: "normal-sleep restoration is unavailable"))
                return
            }
            advanceLifecycle()

            if let record = sentinel ?? restorePending {
                performRestore(record, reason: "disarm: \(options.reason)")
            }
            let status = currentStatus()
            let restored = SleepOverrideSafety.isRestoreProven(status)
            let forceSleepRefused = options.forceSleep && !forceSleepClientAllowed
            let replyError: String?
            if !restored {
                replyError = "normal sleep is not yet verified; helper is retrying"
            } else if !forceSleepClientAllowed {
                replyError = "normal sleep is restored; forced sleep was refused because the client safety revision is not current"
            } else {
                replyError = nil
            }
            reply(IPCCoding.encode(HelperReply(
                ok: restored && !forceSleepRefused,
                error: replyError,
                status: status
            )))

            if options.forceSleep,
               forceSleepClientAllowed,
               restored {
                // Give the app a moment to post its notification/sound, and
                // skip if any newer lifecycle intent crossed the delay.
                let forceSleepGeneration = lifecycleGeneration
                let forceSleepCreatedAt = DispatchTime.now().uptimeNanoseconds
                queue.asyncAfter(deadline: .now() + 3) { [self] in
                    let observedClamshellClosed = PowerRegistry.clamshellClosed()
                    let observedSleepDisabled = PMSet.readSleepDisabled()
                    let authorizationCheckedAt = DispatchTime.now().uptimeNanoseconds
                    guard DelayedSleepSafety.allowsForceSleep(
                        capturedGeneration: forceSleepGeneration,
                        currentGeneration: lifecycleGeneration,
                        requestCreatedAtNanoseconds: forceSleepCreatedAt,
                        currentNanoseconds: authorizationCheckedAt,
                        hasActiveSentinel: sentinel != nil,
                        hasPendingRestore: restorePending != nil,
                        powerObservationAvailable: powerObservationAvailable,
                        observedClamshellClosed: observedClamshellClosed,
                        observedSleepDisabled: observedSleepDisabled
                    ),
                    HelperTerminationSafety.allows(.forceSleep, whileTerminationRequested: terminationRequested),
                    !durableMutationMarkerRequiresRecovery
                    else { return }
                    log.info("forcing sleep (\(options.reason))")
                    do {
                        try performTrackedMutation(.forceSleep) {
                            try PMSet.sleepNow()
                        }
                    } catch {
                        _ = registerUnresolvedMutation(from: error)
                        log.error("sleepnow failed: \(error)")
                    }
                }
            }
        }
    }

    fileprivate func handleRepairOverride(reply: @escaping @Sendable (Data) -> Void) {
        queue.async { [self] in
            lastActivity = Date()
            advanceLifecycle()
            guard HelperTerminationSafety.allows(.repairOverride, whileTerminationRequested: terminationRequested) else {
                reply(replyData(ok: false, error: "helper termination is pending; refusing override repair"))
                return
            }
            let record: OverrideSentinel
            if let existing = sentinel ?? restorePending {
                record = existing
            } else {
                let now = Date()
                record = OverrideSentinel(
                    armedAt: now,
                    watchdogTTL: HelperArmOptions.defaultWatchdogTTL,
                    watchdogDeadline: now,
                    priorSleepDisabled: false
                )
                do {
                    try writeSentinel(record)
                    sentinel = record
                    watchdogDeadline = .now()
                } catch {
                    reconcileSentinelPersistenceFailure(
                        reason: "override-repair sentinel persistence failed"
                    )
                    reply(replyData(ok: false, error: "could not persist repair recovery sentinel: \(error.localizedDescription)"))
                    return
                }
            }

            performRestore(record, reason: "repair requested")
            let status = currentStatus()
            let restored = SleepOverrideSafety.isRestoreProven(status)
            reply(IPCCoding.encode(HelperReply(
                ok: restored,
                error: restored ? nil : "normal sleep is not yet verified; helper is retrying",
                status: status
            )))
        }
    }

    fileprivate func handleScheduleWake(
        _ request: HelperScheduleWakeRequest,
        reply: @escaping @Sendable (Data) -> Void
    ) {
        queue.async { [self] in
            lastActivity = Date()
            let clientOperation: HelperClientOperation = request.desiredDate == nil
                ? .cancelWake
                : .scheduleWake
            guard HelperClientAdmissionSafety.allows(
                clientOperation,
                identity: request.clientIdentity
            ) else {
                reply(replyData(
                    ok: false,
                    error: "client protocol or safety revision is not current; refusing wake scheduling"
                ))
                return
            }
            guard !unresolvedMutationRemains() else {
                reply(replyData(
                    ok: false,
                    error: "a prior power command has not been observed to exit; refusing wake work"
                ))
                return
            }
            guard !durableMutationMarkerRequiresRecovery else {
                reply(replyData(
                    ok: false,
                    error: "a durable prior-command uncertainty requires reviewed recovery; refusing wake work"
                ))
                return
            }
            guard HelperTerminationSafety.allows(.scheduleWake, whileTerminationRequested: terminationRequested) else {
                reply(replyData(ok: false, error: "helper termination is pending; refusing wake work"))
                return
            }
            // Wake scheduling is not safety-critical and may require two
            // blocking pmset calls. Never let it sit ahead of watchdog or
            // connection-invalidation work for an active/recovering override;
            // the app retries after the session completes.
            guard sentinel == nil, restorePending == nil else {
                reply(replyData(ok: false, error: "wake scheduling is deferred while sleep-override supervision is active"))
                return
            }
            do {
                if !scheduledWakeReconciliationMarkerLoaded {
                    try loadScheduledWakeReconciliationMarker()
                }
                if !scheduledWakeLedgerLoaded {
                    try loadScheduledWakeLedger()
                }
                // Resolve every prior uncertain transaction before accepting
                // another intent. A parser or persistence failure remains an
                // explicit refusal, never an invented empty ledger.
                let progress = try reconcileScheduledWakeLedger(
                    reason: "client request preflight",
                    maximumActions: 64
                )
                guard case .settled(let observedEvents) = progress else {
                    throw ScheduledWakeAdapterError(
                        message: "scheduled-wake preflight exceeded its bounded recovery work"
                    )
                }
                try finishScheduledWakeReconciliation(
                    observedEvents: observedEvents
                )
            } catch {
                recordScheduledWakeLedgerFailure(
                    "scheduled-wake preflight failed: \(error.localizedDescription)"
                )
                reply(replyData(
                    ok: false,
                    error: "scheduled-wake recovery is incomplete: \(error.localizedDescription)"
                ))
                return
            }

            if let date = request.desiredDate {
                let horizon = Date().addingTimeInterval(14 * 24 * 3600)
                guard date > Date(), date < horizon else {
                    reply(replyData(ok: false, error: "wake date out of range"))
                    return
                }

                do {
                    var candidate = scheduledWakeLedger
                    let event = try candidate.beginScheduling(
                        rendered: PMSet.renderedWakeDate(for: date),
                        date: date
                    )
                    // Intent is durable before the external mutation. For an
                    // idempotent retry, beginScheduling returns the already
                    // committed event and the mutation is skipped.
                    try ensureScheduledWakeReconciliationMarker()
                    try commitScheduledWakeLedger(candidate)
                    if event.phase == .pendingSchedule {
                        try performTrackedMutation(.scheduleWake) {
                            try PMSet.scheduleWake(rendered: event.rendered)
                        }
                    }
                    let observedEvents = try PMSet.readScheduledWakes()
                    candidate = scheduledWakeLedger
                    try candidate.confirmScheduled(
                        event.id,
                        observedEvents: observedEvents
                    )
                    try commitScheduledWakeLedger(candidate)

                    // confirmScheduled atomically retains every predecessor
                    // as pending cancellation. Complete those obligations and
                    // prove the final desired event before reporting success.
                    let progress = try reconcileScheduledWakeLedger(
                        reason: "new wake committed",
                        maximumActions: 64
                    )
                    guard case .settled(let finalObservedEvents) = progress else {
                        throw ScheduledWakeAdapterError(
                            message: "scheduled-wake transaction exceeded its bounded recovery work"
                        )
                    }
                    try finishScheduledWakeReconciliation(
                        observedEvents: finalObservedEvents,
                        expectedScheduledEventID: event.id
                    )
                    log.info("scheduled and verified wake at \(date)")
                } catch {
                    _ = registerUnresolvedMutation(from: error)
                    recordScheduledWakeLedgerFailure(
                        "scheduled-wake transaction failed: \(error.localizedDescription)"
                    )
                    reply(replyData(
                        ok: false,
                        error: "scheduled wake was not durably verified: \(error.localizedDescription)"
                    ))
                    return
                }
            } else {
                do {
                    var candidate = scheduledWakeLedger
                    for eventID in candidate.events.map(\.id) {
                        try candidate.prepareCancellation(eventID)
                    }
                    try ensureScheduledWakeReconciliationMarker()
                    try commitScheduledWakeLedger(candidate)
                    let progress = try reconcileScheduledWakeLedger(
                        reason: "client cancellation",
                        maximumActions: 64
                    )
                    guard case .settled(let observedEvents) = progress else {
                        throw ScheduledWakeAdapterError(
                            message: "scheduled-wake cancellation exceeded its bounded recovery work"
                        )
                    }
                    guard scheduledWakeLedger.events.isEmpty else {
                        throw ScheduledWakeAdapterError(
                            message: "scheduled-wake cancellation obligations remain"
                        )
                    }
                    try finishScheduledWakeReconciliation(
                        observedEvents: observedEvents
                    )
                    log.info("cancelled and verified all Lidless scheduled wakes")
                } catch {
                    _ = registerUnresolvedMutation(from: error)
                    recordScheduledWakeLedgerFailure(
                        "scheduled-wake cancellation failed: \(error.localizedDescription)"
                    )
                    reply(replyData(
                        ok: false,
                        error: "scheduled wake cancellation is incomplete: \(error.localizedDescription)"
                    ))
                    return
                }
            }
            reply(replyData(ok: true))
        }
    }

    /// Protocol-v6 compatibility selector. It may still cancel a wake because
    /// cancellation reduces risk, but it cannot schedule one without the
    /// structured current-client identity introduced by safety revision 8.
    fileprivate func handleLegacyScheduleWake(
        _ epoch: Double,
        reply: @escaping @Sendable (Data) -> Void
    ) {
        guard epoch <= 0 else {
            queue.async { [self] in
                lastActivity = Date()
                reply(replyData(
                    ok: false,
                    error: "legacy wake scheduling is unavailable; update Lidless"
                ))
            }
            return
        }
        handleScheduleWake(
            HelperScheduleWakeRequest(
                desiredDate: nil,
                clientIdentity: nil
            ),
            reply: reply
        )
    }

    fileprivate func enqueueScheduleWake(
        _ requestJSON: Data,
        reply: @escaping @Sendable (Data) -> Void
    ) {
        guard let request = IPCCoding.decode(
            HelperScheduleWakeRequest.self,
            from: requestJSON
        ) else {
            queue.async { [self] in
                reply(replyData(
                    ok: false,
                    error: "malformed scheduled-wake request"
                ))
            }
            return
        }
        handleScheduleWake(request, reply: reply)
    }

    fileprivate func handlePrepareUninstall(
        reply: @escaping @Sendable (Data) -> Void
    ) {
        queue.async { [self] in
            lastActivity = Date()
            reply(IPCCoding.encode(HelperCleanupPreparation(
                ok: false,
                error: "automatic helper cleanup is disabled; a reviewed removal procedure is required",
                status: currentStatus()
            )))
        }
    }

    fileprivate func handleUninstall(
        _ authorizationJSON: Data,
        reply: @escaping @Sendable (Data) -> Void
    ) {
        queue.async { [self] in
            lastActivity = Date()
            _ = authorizationJSON
            reply(IPCCoding.encode(HelperReply(
                ok: false,
                error: "automatic helper cleanup is disabled; a reviewed removal procedure is required",
                status: currentStatus()
            )))
        }
    }

    fileprivate func handleLegacyUninstall(
        reply: @escaping @Sendable (Data) -> Void
    ) {
        queue.async { [self] in
            lastActivity = Date()
            reply(IPCCoding.encode(HelperReply(
                ok: false,
                error: "automatic helper cleanup is disabled; a reviewed removal procedure is required",
                status: currentStatus()
            )))
        }
    }

    private func currentStatus() -> HelperStatus {
        let observedSleepDisabled = PMSet.readSleepDisabled()
        let recoveryPending = restorePending != nil
            || durableMutationMarkerRequiresRecovery
        return HelperStatus(
            helperVersion: LidlessIDs.helperVersion,
            helperSafetyRevision: Self.implementedSafetyRevision,
            armed: sentinel != nil,
            // On an unreadable registry, report the conservative possibility:
            // the override may still be on whenever a live or recovering
            // session exists. The separate verification bit prevents callers
            // from mistaking this fallback for measured truth.
            sleepDisabled: observedSleepDisabled ?? (sentinel != nil || recoveryPending),
            sleepStateVerified: observedSleepDisabled != nil,
            restorePending: recoveryPending,
            armedSince: sentinel?.armedAt,
            watchdogDeadline: sentinel?.watchdogDeadline,
            scheduledWake: scheduledWakeLedger.events.first(where: {
                $0.phase == .scheduled
            })?.date
        )
    }

    private func replyData(ok: Bool, error: String? = nil) -> Data {
        IPCCoding.encode(HelperReply(ok: ok, error: error, status: currentStatus()))
    }

    private var scheduledWakeLedgerNeedsRecovery: Bool {
        !scheduledWakeReconciliationMarkerLoaded
            || scheduledWakeReconciliationMarker != nil
            || scheduledWakeReconciliationMarkerFailure != nil
            || !scheduledWakeLedgerLoaded
            || scheduledWakeLedgerFailure != nil
            || durableMutationMarker?.operation.concernsScheduledWake == true
            || scheduledWakeLedger.events.contains(where: {
                $0.phase != .scheduled
            })
    }

    private func recordScheduledWakeLedgerFailure(_ message: String) {
        scheduledWakeLedgerFailure = message
        nextScheduledWakeReconciliation = .now() + 30
        log.error(message)
    }

    /// Reconcile one external action at a time. Every cancel intent is fully
    /// synchronized before the command, and a record is removed only after a
    /// fresh authoritative read proves the exact rendering absent. Duplicate
    /// renderings remain visible and require repeated cancellation attempts.
    private func reconcileScheduledWakeLedger(
        reason: String,
        maximumActions: Int
    ) throws -> ScheduledWakeReconciliationProgress {
        guard scheduledWakeLedgerLoaded else {
            throw ScheduledWakeAdapterError(
                message: "the scheduled-wake ledger has not been loaded from trusted storage"
            )
        }
        guard maximumActions > 0 else {
            return .needsMoreWork
        }

        for _ in 0..<maximumActions {
            let observedEvents = try PMSet.readScheduledWakes()
            guard let action = try scheduledWakeLedger.nextAction(observedEvents: observedEvents) else {
                return .settled(observedEvents: observedEvents)
            }
            try ensureScheduledWakeReconciliationMarker()

            switch action {
            case .cancel(let event):
                var candidate = scheduledWakeLedger
                try candidate.prepareCancellation(event.id)
                try commitScheduledWakeLedger(candidate)

                var cancellationFailure: Error?
                do {
                    try performTrackedMutation(.cancelWake, allowsExistingMarker: true) {
                        try PMSet.cancelWake(rendered: event.rendered)
                    }
                } catch {
                    if registerUnresolvedMutation(from: error) {
                        throw error
                    }
                    cancellationFailure = error
                }

                let observedAfterCancellation = try PMSet.readScheduledWakes()
                if observedAfterCancellation.contains(event.rendered) {
                    if let cancellationFailure { throw cancellationFailure }
                    // More than one exact event may exist. The parser keeps
                    // duplicates, so retain the obligation and cancel again.
                    continue
                }

                guard !durableMutationMarkerBlocksWakeAbsenceProof else {
                    throw ScheduledWakeAdapterError(
                        message: "wake absence cannot resolve a command inherited from a prior helper process"
                    )
                }

                candidate = scheduledWakeLedger
                try candidate.completeCancellation(
                    event.id,
                    observedEvents: observedAfterCancellation
                )
                try commitScheduledWakeLedger(candidate)
                if let cancellationFailure {
                    log.info(
                        "scheduled wake became absent despite cancellation error (\(reason)): \(cancellationFailure.localizedDescription)"
                    )
                }

            case .removeUnobserved(let event):
                guard !durableMutationMarkerBlocksWakeAbsenceProof else {
                    throw ScheduledWakeAdapterError(
                        message: "wake absence cannot resolve a command inherited from a prior helper process"
                    )
                }
                var candidate = scheduledWakeLedger
                try candidate.removeUnobserved(
                    event.id,
                    observedEvents: observedEvents
                )
                try commitScheduledWakeLedger(candidate)
            }
        }

        log.info("scheduled-wake reconciliation yielded after bounded work (\(reason))")
        return .needsMoreWork
    }

    /// Clears durable recovery evidence only when the exact authoritative
    /// observation has no next ledger action. A requested scheduled event adds
    /// an explicit identity check before the transaction marker is removed.
    private func finishScheduledWakeReconciliation(
        observedEvents: [String],
        expectedScheduledEventID: UUID? = nil
    ) throws {
        guard scheduledWakeLedgerLoaded else {
            throw ScheduledWakeAdapterError(
                message: "scheduled-wake final proof has no trusted ledger"
            )
        }
        guard try scheduledWakeLedger.nextAction(
            observedEvents: observedEvents
        ) == nil,
        !scheduledWakeLedger.events.contains(where: { $0.phase != .scheduled }) else {
            throw ScheduledWakeAdapterError(
                message: "scheduled-wake final proof still has a recovery action"
            )
        }

        if let expectedScheduledEventID {
            guard let event = scheduledWakeLedger.events.first(where: {
                $0.id == expectedScheduledEventID && $0.phase == .scheduled
            }), observedEvents.lazy.filter({ $0 == event.rendered }).count == 1 else {
                throw ScheduledWakeAdapterError(
                    message: "the exact scheduled wake was not uniquely proven"
                )
            }
        }

        if durableMutationMarker?.operation.concernsScheduledWake == true {
            guard !durableMutationMarkerBlocksWakeAbsenceProof else {
                throw ScheduledWakeAdapterError(
                    message: "same-boot prior-command child exit is unproven; retaining wake recovery until the reviewed reboot boundary"
                )
            }
            try clearDurableMutationMarkerAfterObservedExit()
        }
        try clearScheduledWakeReconciliationMarkerAfterProof()
        scheduledWakeLedgerFailure = nil
        nextScheduledWakeReconciliation = .now() + 30
    }

    /// Assign in-memory truth only after the exact candidate is durably
    /// published. A write with an ambiguous outcome invalidates memory; the
    /// next attempt must reopen and decode the authoritative path.
    private func commitScheduledWakeLedger(
        _ candidate: ScheduledWakeLedger
    ) throws {
        do {
            try persistScheduledWakeLedger(candidate)
        } catch {
            scheduledWakeLedgerLoaded = false
            throw error
        }
        scheduledWakeLedger = candidate
        scheduledWakeLedgerLoaded = true
    }

    /// Atomic, fully synchronized replacement in the already proven
    /// root-owned directory. Keeping an encoded empty ledger avoids a
    /// deletion boundary that could otherwise be mistaken for lost intent.
    private func persistScheduledWakeLedger(
        _ candidate: ScheduledWakeLedger
    ) throws {
        let data = try IPCCoding.encoder().encode(candidate)
        guard data.count <= Self.maximumScheduledWakeLedgerBytes else {
            throw StorageError(
                operation: "encoded scheduled-wake ledger exceeds the maximum reviewed size",
                code: nil
            )
        }

        var directoryDescriptor = try openSecureWorkDirectory()
        defer {
            if directoryDescriptor >= 0 {
                _ = Darwin.close(directoryDescriptor)
            }
        }

        let temporaryFilename = ".scheduled-wake-\(UUID().uuidString).tmp"
        var temporaryPublished = false
        defer {
            if !temporaryPublished, directoryDescriptor >= 0 {
                _ = unlinkat(directoryDescriptor, temporaryFilename, 0)
            }
        }

        var fileDescriptor = openat(
            directoryDescriptor,
            temporaryFilename,
            O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC,
            mode_t(0o600)
        )
        guard fileDescriptor >= 0 else {
            throw StorageError(
                operation: "exclusively create scheduled-wake ledger candidate",
                code: errno
            )
        }
        defer {
            if fileDescriptor >= 0 {
                _ = Darwin.close(fileDescriptor)
            }
        }

        guard fchown(fileDescriptor, 0, 0) == 0 else {
            throw StorageError(
                operation: "set scheduled-wake ledger owner",
                code: errno
            )
        }
        guard fchmod(fileDescriptor, mode_t(0o600)) == 0 else {
            throw StorageError(
                operation: "set scheduled-wake ledger mode",
                code: errno
            )
        }

        let directoryMetadata = try storageMetadata(for: directoryDescriptor)
        let initialFileMetadata = try storageMetadata(for: fileDescriptor)
        guard HelperStorageSafety.isTrustedSentinel(
            workDirectory: directoryMetadata,
            sentinel: initialFileMetadata
        ) else {
            throw StorageError(
                operation: "new scheduled-wake ledger metadata is not trusted",
                code: nil
            )
        }

        try data.withUnsafeBytes { bytes in
            var offset = 0
            while offset < bytes.count {
                let byteCount = Darwin.write(
                    fileDescriptor,
                    bytes.baseAddress?.advanced(by: offset),
                    bytes.count - offset
                )
                if byteCount < 0 {
                    let writeErrno = errno
                    if writeErrno == EINTR { continue }
                    throw StorageError(
                        operation: "write scheduled-wake ledger candidate",
                        code: writeErrno
                    )
                }
                guard byteCount > 0 else {
                    throw StorageError(
                        operation: "write scheduled-wake ledger candidate made no progress",
                        code: nil
                    )
                }
                offset += byteCount
            }
        }

        try fullySynchronize(
            fileDescriptor,
            operation: "fully synchronize scheduled-wake ledger candidate"
        )
        let finalFileMetadata = try storageMetadata(for: fileDescriptor)
        guard HelperStorageSafety.isTrustedSentinel(
            workDirectory: directoryMetadata,
            sentinel: finalFileMetadata
        ) else {
            throw StorageError(
                operation: "scheduled-wake ledger metadata changed before publication",
                code: nil
            )
        }
        try closeStorageDescriptor(
            &fileDescriptor,
            operation: "close fully synchronized scheduled-wake ledger candidate"
        )

        guard renameat(
            directoryDescriptor,
            temporaryFilename,
            directoryDescriptor,
            HelperPaths.scheduledWakeLedgerFilename
        ) == 0 else {
            throw StorageError(
                operation: "atomically publish scheduled-wake ledger",
                code: errno
            )
        }
        temporaryPublished = true
        try fullySynchronize(
            directoryDescriptor,
            operation: "fully synchronize scheduled-wake ledger directory entry"
        )
        try closeStorageDescriptor(
            &directoryDescriptor,
            operation: "close fully synchronized scheduled-wake ledger directory"
        )
    }

    private struct ScheduledWakeRecordRead {
        let data: Data
        let needsPermissionHardening: Bool
    }

    /// Load only through descriptor-relative, no-follow storage. Revision 7's
    /// root-owned 0644 atomic file is accepted for integrity-preserving
    /// migration, then immediately rewritten as the current exact 0600 file.
    private func readScheduledWakeLedgerRecord() throws -> ScheduledWakeRecordRead? {
        var directoryDescriptor = try openSecureWorkDirectory()
        defer {
            if directoryDescriptor >= 0 {
                _ = Darwin.close(directoryDescriptor)
            }
        }

        var fileDescriptor = openat(
            directoryDescriptor,
            HelperPaths.scheduledWakeLedgerFilename,
            O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC
        )
        if fileDescriptor < 0 {
            let openErrno = errno
            if openErrno == ENOENT {
                try closeStorageDescriptor(
                    &directoryDescriptor,
                    operation: "close helper work directory after absent scheduled-wake ledger"
                )
                return nil
            }
            throw StorageError(
                operation: "open scheduled-wake ledger without following links",
                code: openErrno
            )
        }
        defer {
            if fileDescriptor >= 0 {
                _ = Darwin.close(fileDescriptor)
            }
        }

        let directoryMetadata = try storageMetadata(for: directoryDescriptor)
        let fileMetadata = try storageMetadata(for: fileDescriptor)
        let acceptedPermission = fileMetadata.permissions == 0o600
            || fileMetadata.permissions == 0o644
        guard HelperStorageSafety.isSecureWorkDirectory(directoryMetadata),
              fileMetadata.kind == .regularFile,
              fileMetadata.ownerUID == 0,
              fileMetadata.ownerGID == 0,
              acceptedPermission,
              fileMetadata.linkCount == 1,
              !fileMetadata.hasExtendedACL else {
            throw StorageError(
                operation: "scheduled-wake ledger is not a trusted root-owned single-link regular file",
                code: nil
            )
        }

        let data = try readStorageRecordData(
            from: fileDescriptor,
            maximumBytes: Self.maximumScheduledWakeLedgerBytes,
            operation: "read scheduled-wake ledger"
        )
        try closeStorageDescriptor(
            &fileDescriptor,
            operation: "close scheduled-wake ledger after trusted read"
        )
        try closeStorageDescriptor(
            &directoryDescriptor,
            operation: "close helper work directory after scheduled-wake ledger read"
        )
        return ScheduledWakeRecordRead(
            data: data,
            needsPermissionHardening: fileMetadata.permissions != 0o600
        )
    }

    private func readStorageRecordData(
        from fileDescriptor: Int32,
        maximumBytes: Int,
        operation: String
    ) throws -> Data {
        var result = Data()
        var buffer = [UInt8](repeating: 0, count: 4 * 1024)
        while true {
            let byteCount = buffer.withUnsafeMutableBytes { bytes in
                Darwin.read(fileDescriptor, bytes.baseAddress, bytes.count)
            }
            if byteCount == 0 { return result }
            if byteCount < 0 {
                let readErrno = errno
                if readErrno == EINTR { continue }
                throw StorageError(operation: operation, code: readErrno)
            }
            let count = Int(byteCount)
            guard result.count <= maximumBytes - count else {
                throw StorageError(
                    operation: "\(operation) exceeds the maximum reviewed size",
                    code: nil
                )
            }
            result.append(contentsOf: buffer.prefix(count))
        }
    }

    private func loadScheduledWakeLedger() throws {
        if !scheduledWakeReconciliationMarkerLoaded {
            try loadScheduledWakeReconciliationMarker()
        }
        if let markerFailure = scheduledWakeReconciliationMarkerFailure {
            throw ScheduledWakeAdapterError(
                message: "scheduled-wake reconciliation marker is untrusted: \(markerFailure)"
            )
        }
        guard let record = try readScheduledWakeLedgerRecord() else {
            if durableMutationMarkerRequiresRecovery {
                throw ScheduledWakeAdapterError(
                    message: "a durable command marker exists without its required ledger"
                )
            }
            scheduledWakeLedger = ScheduledWakeLedger()
            scheduledWakeLedgerLoaded = true
            scheduledWakeLedgerFailure = nil
            // Marker publication precedes the first ledger commit. Trusted
            // ledger absence plus no command-in-flight evidence therefore
            // proves that no wake mutation belonging to this transaction ran.
            try clearScheduledWakeReconciliationMarkerAfterProof()
            return
        }

        let decoder = IPCCoding.decoder()
        if let decoded = try? decoder.decode(
            ScheduledWakeLedger.self,
            from: record.data
        ) {
            if decoded.events.contains(where: { $0.phase != .scheduled }) {
                try ensureScheduledWakeReconciliationMarker()
            }
            if record.needsPermissionHardening {
                try persistScheduledWakeLedger(decoded)
            }
            scheduledWakeLedger = decoded
            scheduledWakeLedgerLoaded = true
            scheduledWakeLedgerFailure = nil
            return
        }

        guard let legacy = try? decoder.decode(
            LegacyStoredWake.self,
            from: record.data
        ) else {
            throw ScheduledWakeAdapterError(
                message: "scheduled-wake ledger contents or version are unsupported"
            )
        }

        var migrated = ScheduledWakeLedger()
        let event = try migrated.beginScheduling(
            rendered: legacy.rendered,
            date: legacy.date
        )
        try migrated.prepareCancellation(event.id)
        try ensureScheduledWakeReconciliationMarker()
        try persistScheduledWakeLedger(migrated)
        scheduledWakeLedger = migrated
        scheduledWakeLedgerLoaded = true
        scheduledWakeLedgerFailure = nil
        log.info("migrated legacy scheduled-wake record into a cancellation obligation")
    }

    // MARK: - NSXPCListenerDelegate

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        // Only the same-team Lidless app may talk to this root daemon. A
        // bundle identifier alone is locally spoofable, so ad-hoc helpers
        // fail closed and must be installed from a properly signed build.
        guard let requirement = peerCodeSigningRequirement else {
            log.critical("rejecting connection: helper identity could not be validated at startup")
            return false
        }
        newConnection.setCodeSigningRequirement(requirement)

        let connectionID = UUID()
        newConnection.exportedInterface = NSXPCInterface(with: LidlessHelperXPC.self)
        newConnection.exportedObject = HelperXPCBridge(daemon: self, connectionID: connectionID)
        newConnection.interruptionHandler = { [weak self, weak newConnection] in
            // Interruption is terminal for a safety-owning connection even
            // though Foundation may otherwise allow it to reconnect.
            newConnection?.invalidate()
            self?.connectionEnded(connectionID)
        }
        newConnection.invalidationHandler = { [weak self] in
            self?.connectionEnded(connectionID)
        }
        // Register synchronously before resume so even an immediate
        // interruption/invalidation can only remove a live identity.
        let registered = queue.sync { [self] in
            let inserted = connectionSupervision.register(connectionID)
            if inserted { lastActivity = Date() }
            return inserted
        }
        guard registered else {
            // A rejected connection must not retain callbacks carrying the
            // colliding identity: its later invalidation could otherwise end
            // the already-registered connection that owns that identity.
            newConnection.interruptionHandler = nil
            newConnection.invalidationHandler = nil
            log.critical("rejecting connection: process-local identity collision")
            return false
        }
        newConnection.resume()
        return true
    }

    private func connectionEnded(_ connectionID: UUID) {
        queue.async { [self] in
            let disposition = connectionSupervision.end(
                connectionID,
                owner: armedConnectionID,
                hasActiveSession: sentinel != nil
            )
            guard disposition != .ignoreDuplicate else { return }
            lastActivity = Date()
            switch disposition {
            case .ignoreDuplicate:
                break
            case .connectionEnded:
                break
            case .restoreOwnedSession:
                guard let sentinel else { return }
                log.critical("supervising app connection ended while armed — restoring normal sleep")
                performRestore(sentinel, reason: "supervising app connection ended")
            }
        }
    }

}

// MARK: - Per-connection XPC facade

/// Thin bridge so the daemon can associate each call with its connection's
/// identity (for supervision) without touching `NSXPCConnection.current`.
final class HelperXPCBridge: NSObject, LidlessHelperXPC {
    private let daemon: HelperDaemon
    private let connectionID: UUID

    init(daemon: HelperDaemon, connectionID: UUID) {
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
        daemon.handleHeartbeat(connectionID: connectionID, reply: reply)
    }

    func disarm(_ optionsJSON: Data, reply: @escaping @Sendable (Data) -> Void) {
        daemon.handleDisarm(optionsJSON, reply: reply)
    }

    func repairOverride(_ reply: @escaping @Sendable (Data) -> Void) {
        daemon.handleRepairOverride(reply: reply)
    }

    func scheduleWake(_ epoch: Double, reply: @escaping @Sendable (Data) -> Void) {
        daemon.handleLegacyScheduleWake(epoch, reply: reply)
    }

    func scheduleWakeRequest(
        _ requestJSON: Data,
        reply: @escaping @Sendable (Data) -> Void
    ) {
        daemon.enqueueScheduleWake(requestJSON, reply: reply)
    }

    func prepareUninstall(_ reply: @escaping @Sendable (Data) -> Void) {
        daemon.handlePrepareUninstall(reply: reply)
    }

    func commitUninstall(
        _ authorizationJSON: Data,
        reply: @escaping @Sendable (Data) -> Void
    ) {
        daemon.handleUninstall(authorizationJSON, reply: reply)
    }

    func uninstall(_ reply: @escaping @Sendable (Data) -> Void) {
        daemon.handleLegacyUninstall(reply: reply)
    }
}
