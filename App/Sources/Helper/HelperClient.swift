import Foundation
import ServiceManagement
import LidlessCore

enum HelperInstallState: Equatable {
    case unknown
    /// Not registered with launchd yet (fresh install, or unregistered).
    case notInstalled
    /// Registered; waiting for the user's one-time approval in System Settings.
    case requiresApproval
    case ready(helperVersion: Int)
    /// Helper responds but predates this app build; re-registration needed.
    case stale(helperVersion: Int)
    /// launchd says enabled, but XPC calls fail.
    case notResponding(String)
    case simulated

    var isUsable: Bool {
        switch self {
        case .ready, .stale, .simulated: true
        default: false
        }
    }
}

/// Everything the app needs from the privileged side, as a protocol so the
/// dry-run simulator can stand in for the real daemon.
@MainActor
protocol HelperControlling: AnyObject {
    var installState: HelperInstallState { get }
    /// Fired when the XPC connection to a live helper is interrupted (helper
    /// crash/restart). AppState re-arms if a session is active.
    var onInterruption: (@MainActor () -> Void)? { get set }

    func refreshInstallState() async
    func install() async throws
    func openApprovalSettings()
    /// Restores all managed state, removes helper data, deregisters the daemon.
    func uninstall() async throws

    func status() async throws -> HelperStatus
    func arm(_ options: HelperArmOptions) async throws -> HelperReply
    func heartbeat() async throws -> HelperReply
    func disarm(_ options: HelperDisarmOptions) async throws -> HelperReply
    func repairOverride() async throws -> HelperReply
    func scheduleWake(_ date: Date?) async throws
}

enum HelperClientError: LocalizedError {
    case notInstalled
    case badProxy
    case malformedReply

    var errorDescription: String? {
        switch self {
        case .notInstalled: "The privileged helper is not installed."
        case .badProxy: "Could not create a connection to the helper."
        case .malformedReply: "The helper sent a malformed reply."
        }
    }
}

@MainActor
@Observable
final class HelperClient: HelperControlling {
    private(set) var installState: HelperInstallState = .unknown
    var onInterruption: (@MainActor () -> Void)?

    private var connection: NSXPCConnection?

    private var service: SMAppService {
        SMAppService.daemon(plistName: LidlessIDs.helperPlistName)
    }

    // MARK: - Install lifecycle

    func refreshInstallState() async {
        switch service.status {
        case .notRegistered, .notFound:
            installState = .notInstalled
        case .requiresApproval:
            installState = .requiresApproval
        case .enabled:
            do {
                let status = try await status()
                installState = status.helperVersion >= LidlessIDs.helperVersion
                    ? .ready(helperVersion: status.helperVersion)
                    : .stale(helperVersion: status.helperVersion)
            } catch {
                installState = .notResponding(error.localizedDescription)
            }
        @unknown default:
            installState = .unknown
        }
    }

    func install() async throws {
        do {
            try service.register()
        } catch {
            // Approval-pending registration surfaces as a throw; only treat
            // it as fatal if the status doesn't show the approval path.
            await refreshInstallState()
            if installState == .requiresApproval {
                openApprovalSettings()
                return
            }
            throw error
        }
        await refreshInstallState()
        if installState == .requiresApproval {
            openApprovalSettings()
        }
    }

    func openApprovalSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    func uninstall() async throws {
        // Order is safety-critical: deregistering removes launchd's
        // KeepAlive/RunAtLoad supervision, so it must never happen while the
        // helper reports (or the registry shows) the override might still be
        // active. Gate on launchd's own status, not our cached installState —
        // a wedged helper reads as .notResponding but was fully able to arm.
        if service.status == .enabled {
            do {
                let reply = try await callForReply { proxy, done in proxy.uninstall(done) }
                guard reply.ok else {
                    throw NSError(domain: "Lidless", code: 3, userInfo: [
                        NSLocalizedDescriptionKey: "The helper could not restore normal sleep (\(reply.error ?? "unknown error")). It stays installed so its watchdog can keep retrying — try again in a minute, or run: \(LidlessIDs.manualFallbackCommand)",
                    ])
                }
            } catch let error as NSError where error.domain == "Lidless" {
                throw error
            } catch {
                // Helper unreachable, but it was enabled and could have
                // armed. Proceed only if the override verifiably reads OFF —
                // an unreadable registry is not evidence of safety.
                guard PowerRegistry.sleepDisabled() == false else {
                    throw NSError(domain: "Lidless", code: 4, userInfo: [
                        NSLocalizedDescriptionKey: "The helper is unreachable and the sleep override can't be verified off. Not removing it. Run \(LidlessIDs.manualFallbackCommand), then try again.",
                    ])
                }
            }
        } else {
            // Never-approved / never-registered helpers can't have armed;
            // block only on positive evidence of a live override.
            guard PowerRegistry.sleepDisabled() != true else {
                throw NSError(domain: "Lidless", code: 5, userInfo: [
                    NSLocalizedDescriptionKey: "The system sleep override is active. Run \(LidlessIDs.manualFallbackCommand) first, then uninstall.",
                ])
            }
        }
        try await Self.unregisterDaemon()
        invalidateConnection()
        await refreshInstallState()
    }

    /// SMAppService is not Sendable; constructing and unregistering it in one
    /// nonisolated frame keeps it inside a single isolation region (older
    /// Swift 6 compilers reject sending `self.service` into async work).
    private nonisolated static func unregisterDaemon() async throws {
        try await SMAppService.daemon(plistName: LidlessIDs.helperPlistName).unregister()
    }

    // MARK: - XPC surface

    func status() async throws -> HelperStatus {
        let data = try await call { proxy, done in proxy.ping(done) }
        guard let status = IPCCoding.decode(HelperStatus.self, from: data) else {
            throw HelperClientError.malformedReply
        }
        return status
    }

    func arm(_ options: HelperArmOptions) async throws -> HelperReply {
        try await callForReply { proxy, done in
            proxy.arm(IPCCoding.encode(options), reply: done)
        }
    }

    func heartbeat() async throws -> HelperReply {
        try await callForReply { proxy, done in proxy.heartbeat(done) }
    }

    func disarm(_ options: HelperDisarmOptions) async throws -> HelperReply {
        try await callForReply { proxy, done in
            proxy.disarm(IPCCoding.encode(options), reply: done)
        }
    }

    func repairOverride() async throws -> HelperReply {
        try await callForReply { proxy, done in proxy.repairOverride(done) }
    }

    func scheduleWake(_ date: Date?) async throws {
        let epoch = date?.timeIntervalSince1970 ?? 0
        _ = try await callForReply { proxy, done in
            proxy.scheduleWake(epoch, reply: done)
        }
    }

    // MARK: - Connection plumbing

    private func ensureConnection() -> NSXPCConnection {
        if let connection { return connection }
        let fresh = NSXPCConnection(machServiceName: LidlessIDs.helperMachService, options: .privileged)
        fresh.remoteObjectInterface = NSXPCInterface(with: LidlessHelperXPC.self)
        fresh.interruptionHandler = { [weak self] in
            Task { @MainActor [weak self] in self?.onInterruption?() }
        }
        fresh.invalidationHandler = { [weak self] in
            Task { @MainActor [weak self] in self?.connection = nil }
        }
        fresh.resume()
        connection = fresh
        return fresh
    }

    private func invalidateConnection() {
        connection?.invalidate()
        connection = nil
    }

    /// One XPC round trip with exactly-once continuation semantics.
    private func call(
        _ body: @escaping @Sendable (LidlessHelperXPC, @escaping @Sendable (Data) -> Void) -> Void
    ) async throws -> Data {
        let connection = ensureConnection()
        let once = ResumeOnce()
        return try await withCheckedThrowingContinuation { continuation in
            let anyProxy = connection.remoteObjectProxyWithErrorHandler { error in
                if once.claim() { continuation.resume(throwing: error) }
            }
            guard let proxy = anyProxy as? LidlessHelperXPC else {
                if once.claim() { continuation.resume(throwing: HelperClientError.badProxy) }
                return
            }
            body(proxy) { data in
                if once.claim() { continuation.resume(returning: data) }
            }
        }
    }

    private func callForReply(
        _ body: @escaping @Sendable (LidlessHelperXPC, @escaping @Sendable (Data) -> Void) -> Void
    ) async throws -> HelperReply {
        let data = try await call(body)
        guard let reply = IPCCoding.decode(HelperReply.self, from: data) else {
            throw HelperClientError.malformedReply
        }
        return reply
    }
}

/// XPC promises a single response per call, but the error handler and reply
/// paths race in edge cases; this makes resuming idempotent.
private final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var used = false

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if used { return false }
        used = true
        return true
    }
}
