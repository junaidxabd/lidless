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
    private static let implementedSafetyRevision = 7
    private static let maximumSentinelBytes = 64 * 1024

    private struct StorageError: LocalizedError {
        let operation: String
        let code: Int32?

        var errorDescription: String? {
            guard let code else { return operation }
            return "\(operation): \(String(cString: strerror(code)))"
        }
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
    /// Invalidates delayed force-sleep follow-ups whenever any later helper or
    /// system lifecycle intent arrives. This closes the nil -> active -> nil
    /// ABA window that a sentinel-only guard cannot detect.
    private var lifecycleGeneration = UUID()
    /// Queue-local handoff fence latched before cleanup's first fallible side
    /// effect. It closes risk-increasing work in this daemon process even when
    /// cleanup fails or its reply is lost, without blocking already-owned
    /// restoration.
    private var helperRemovalFence: HelperRemovalDaemonSafety.Fence = .open
    /// Random for this process lifetime. Cleanup preparation returns this as
    /// an opaque authorization, and commit validates it before any cleanup
    /// mutation. A reconnect to a restarted/replaced helper cannot reuse it.
    private let cleanupInstanceID = UUID()

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
        // Finish queue-owned recovery setup before the XPC listener is exposed.
        // Signal sources are installed first: a signal delivered during a
        // blocking recovery pass queues behind that pass instead of taking the
        // default process-termination path or observing uninitialized state.
        queue.sync { [self] in
            installSignalHandlers()
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
            recoveryPass(storageFailure: storageFailure)
            log.info("LidlessHelper v\(LidlessIDs.helperVersion) started (pid \(ProcessInfo.processInfo.processIdentifier), uid \(getuid()))")
            if storageFailure == nil {
                loadScheduledWake()
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

        if terminationRequested {
            finishTerminationIfSafe()
        }

        // Idle exit: nothing armed, nothing pending, nobody connected.
        // launchd restarts us on the next XPC lookup or at boot.
        if sentinel == nil, restorePending == nil, connectionSupervision.isEmpty,
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
        advanceLifecycle()
        guard HelperTerminationSafety.allows(.arm, whileTerminationRequested: terminationRequested) else {
            reply(replyData(ok: false, error: "helper termination is pending; refusing to arm"))
            return
        }
        guard HelperRemovalDaemonSafety.allows(.arm, while: helperRemovalFence) else {
            reply(replyData(ok: false, error: "helper cleanup has started; refusing to arm"))
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

        // The largest bounded child-wait budget is either enable + fail-safe
        // rollback before success, or one grouped optional command for each
        // supported power-source scope after success. Process launch and
        // other queue work have no real-time bound.
        let maximumBlockingCommandCount = max(
            2,
            ManagedSettingRestorationSafety.maximumScopeCommandCount
        )
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

        let armReadback = PMSet.readSleepDisabled()
        if !SleepOverrideSafety.isVerified(expected: true, observed: armReadback) {
            log.error("disablesleep readback is not verifiably 1 after set — reverting")
            abortFreshArm(record, reply: reply, error: "system did not verifiably accept the sleep override")
            return
        }

        // Rebase the in-memory watchdog at the exact proof point and reply
        // before optional commands. The disk sentinel already contains all
        // unconditional recovery data and is never rewritten while active.
        // The app can begin its heartbeat while at most three best-effort
        // per-scope calls occupy the queue. Their child-process wait budgets
        // total less than the minimum TTL; process launch and other queue work
        // do not have a real-time bound.
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

        // Best-effort extras; never delay the success reply or fail the arm.
        // Only scopes with captured priors are touched, and the sentinel owns
        // those priors before any optional command begins.
        do { try PMSet.apply(managedActivationPlan) }
        catch { log.error("could not apply all managed settings: \(error)") }
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
        try? PMSet.setSleepDisabled(restoreTarget)
        if SleepOverrideSafety.isVerified(
            expected: restoreTarget,
            observed: PMSet.readSleepDisabled()
        ) {
            do {
                try removeSentinelFile()
            } catch {
                log.error("aborted arm restored sleep but sentinel cleanup failed — retrying")
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
        let restoreTarget = SleepOverrideSafety.restoreTarget(recordedPrior: record.priorSleepDisabled)
        do {
            try PMSet.setSleepDisabled(restoreTarget)
        } catch {
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
            try PMSet.apply(managedRestorationPlan)
        } catch {
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

        do {
            try removeSentinelFile()
        } catch {
            parkRestore(
                record,
                message: "RESTORE verified all managed state but sentinel cleanup failed (\(reason)) — will retry"
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
            guard HelperRemovalDaemonSafety.allows(.heartbeat, while: helperRemovalFence) else {
                reply(replyData(ok: false, error: "helper cleanup has started; refusing heartbeat"))
                return
            }
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
            advanceLifecycle()
            if options.forceSleep,
               !HelperRemovalDaemonSafety.allows(.forceSleep, while: helperRemovalFence) {
                reply(replyData(ok: false, error: "helper cleanup has started; refusing forced sleep"))
                return
            }

            if let record = sentinel ?? restorePending {
                performRestore(record, reason: "disarm: \(options.reason)")
            }
            let status = currentStatus()
            let restored = SleepOverrideSafety.isRestoreProven(status)
            reply(IPCCoding.encode(HelperReply(
                ok: restored,
                error: restored ? nil : "normal sleep is not yet verified; helper is retrying",
                status: status
            )))

            if options.forceSleep, restored {
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
                    HelperRemovalDaemonSafety.allows(.forceSleep, while: helperRemovalFence),
                    HelperTerminationSafety.allows(.forceSleep, whileTerminationRequested: terminationRequested)
                    else { return }
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
            advanceLifecycle()
            guard HelperTerminationSafety.allows(.repairOverride, whileTerminationRequested: terminationRequested) else {
                reply(replyData(ok: false, error: "helper termination is pending; refusing override repair"))
                return
            }
            let removalOperation: HelperRemovalDaemonSafety.Operation =
                sentinel != nil || restorePending != nil ? .restoreOwnedState : .beginOverrideRepair
            guard HelperRemovalDaemonSafety.allows(removalOperation, while: helperRemovalFence) else {
                reply(replyData(ok: false, error: "helper cleanup has started; refusing a new override-repair transaction"))
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

    fileprivate func handleScheduleWake(_ epoch: Double, reply: @escaping @Sendable (Data) -> Void) {
        queue.async { [self] in
            lastActivity = Date()
            guard HelperTerminationSafety.allows(.scheduleWake, whileTerminationRequested: terminationRequested) else {
                reply(replyData(ok: false, error: "helper termination is pending; refusing wake work"))
                return
            }
            let removalOperation: HelperRemovalDaemonSafety.Operation = epoch > 0 ? .scheduleWake : .cancelWake
            guard HelperRemovalDaemonSafety.allows(removalOperation, while: helperRemovalFence) else {
                reply(replyData(ok: false, error: "helper cleanup has started; refusing wake scheduling"))
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
                do {
                    try PMSet.cancelWake(rendered: existing.rendered)
                } catch {
                    reply(replyData(ok: false, error: "scheduled wake cancellation failed: \(error)"))
                    return
                }
                scheduledWake = nil
                persistScheduledWake()
            }
            reply(replyData(ok: true))
        }
    }

    fileprivate func handlePrepareUninstall(
        reply: @escaping @Sendable (Data) -> Void
    ) {
        queue.async { [self] in
            lastActivity = Date()
            let authorization = HelperCleanupAuthorization(
                helperInstanceID: cleanupInstanceID
            )
            reply(IPCCoding.encode(HelperCleanupPreparation(
                ok: true,
                authorization: authorization,
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
            guard let authorization = IPCCoding.decode(
                HelperCleanupAuthorization.self,
                from: authorizationJSON
            ), HelperCleanupHandshakeSafety.authorizes(
                authorization,
                issuedBy: cleanupInstanceID
            ) else {
                reply(IPCCoding.encode(HelperReply(
                    ok: false,
                    error: "cleanup authorization was not issued by this helper process; no cleanup was attempted",
                    status: currentStatus()
                )))
                return
            }
            advanceLifecycle()
            // Monotonic for this process: any partial or ambiguous cleanup
            // outcome keeps new risk-increasing work closed. Recovery and a
            // cleanup retry remain admitted by the pure operation policy.
            helperRemovalFence = .cleanupStarted
            if let record = sentinel ?? restorePending {
                performRestore(record, reason: "uninstall")
            }
            let restoredStatus = currentStatus()
            guard SleepOverrideSafety.isRestoreProven(restoredStatus) else {
                reply(IPCCoding.encode(HelperReply(
                    ok: false,
                    error: "normal sleep is not verified; not removing helper data while the override may be active",
                    status: restoredStatus
                )))
                return
            }
            if let existing = scheduledWake {
                do {
                    try PMSet.cancelWake(rendered: existing.rendered)
                } catch {
                    let failureStatus = currentStatus()
                    reply(IPCCoding.encode(HelperReply(
                        ok: false,
                        error: "scheduled wake cleanup failed; helper cleanup remains incomplete: \(error)",
                        status: failureStatus
                    )))
                    return
                }
            }
            // Best-effort reconciliation may previously have cleared memory
            // even when deleting the on-disk record failed. Strict cleanup
            // must therefore run unconditionally, including when no wake is
            // currently known in memory.
            do {
                try removeScheduledWakeRecordForCleanup()
            } catch {
                // Keep any exact in-memory intent. Even when none is known, a
                // stale or unreadable ledger has not been ruled out, so fail
                // before authorizing the client to deregister this helper.
                let failureStatus = currentStatus()
                reply(IPCCoding.encode(HelperReply(
                    ok: false,
                    error: "scheduled wake record cleanup failed; helper cleanup remains incomplete: \(error.localizedDescription)",
                    status: failureStatus
                )))
                return
            }
            scheduledWake = nil
            log.info("uninstalling: removing \(HelperPaths.workDirectory)")
            // Any later log line would recreate the directory we just
            // removed; from here on, log to the unified log only.
            log.disableFileSink()
            do {
                try FileManager.default.removeItem(atPath: HelperPaths.workDirectory)
            } catch let error as CocoaError where error.code == .fileNoSuchFile &&
                                                   error.filePath == HelperPaths.workDirectory {
                // An exact-target "not found" proves this cleanup step was
                // already complete. A missing descendant is still a failure.
            } catch {
                log.enableFileSink()
                log.error("helper data cleanup failed during uninstall: \(error.localizedDescription)")
                let failureStatus = currentStatus()
                reply(IPCCoding.encode(HelperReply(
                    ok: false,
                    error: "helper data cleanup failed; deregistration is not authorized: \(error.localizedDescription)",
                    status: failureStatus
                )))
                return
            }
            let finalStatus = currentStatus()
            guard SleepOverrideSafety.isRestoreProven(finalStatus) else {
                log.enableFileSink()
                log.error("normal sleep could not be reverified after helper cleanup")
                reply(IPCCoding.encode(HelperReply(
                    ok: false,
                    error: "normal sleep could not be reverified after helper cleanup; not authorizing deregistration",
                    status: finalStatus
                )))
                return
            }
            reply(IPCCoding.encode(HelperReply(ok: true, status: finalStatus)))
        }
    }

    fileprivate func handleLegacyUninstall(
        reply: @escaping @Sendable (Data) -> Void
    ) {
        queue.async { [self] in
            lastActivity = Date()
            reply(IPCCoding.encode(HelperReply(
                ok: false,
                error: "legacy cleanup requests are not process-bound; no cleanup was attempted",
                status: currentStatus()
            )))
        }
    }

    private func currentStatus() -> HelperStatus {
        let observedSleepDisabled = PMSet.readSleepDisabled()
        let recoveryPending = restorePending != nil
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
            scheduledWake: scheduledWake?.date
        )
    }

    private func replyData(ok: Bool, error: String? = nil) -> Data {
        IPCCoding.encode(HelperReply(ok: ok, error: error, status: currentStatus()))
    }

    /// Uninstall cannot rely on the best-effort persistence used by ordinary
    /// wake reconciliation: a surviving ledger would be loaded as live intent
    /// after a later cleanup failure or helper restart. Exact-target absence is
    /// already the required postcondition; every other filesystem error keeps
    /// removal incomplete.
    private func removeScheduledWakeRecordForCleanup() throws {
        do {
            try FileManager.default.removeItem(at: scheduledWakeURL)
        } catch let error as CocoaError where error.code == .fileNoSuchFile &&
                                               error.filePath == scheduledWakeURL.path {
            // The exact record is already absent.
        }
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
        daemon.handleScheduleWake(epoch, reply: reply)
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
