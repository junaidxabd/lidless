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
    /// Helper responds with a protocol version incompatible with this app.
    case stale(helperVersion: Int)
    /// launchd says enabled, but XPC calls fail.
    case notResponding(String)
    case simulated

    var isUsable: Bool {
        switch self {
        case .ready, .simulated: true
        default: false
        }
    }

    /// A protocol-incompatible helper must never arm under this app's safety
    /// policy, but remains reachable for inspection and recovery.
    var isReachable: Bool {
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
    /// Fired when the XPC connection to a live helper is interrupted. AppState
    /// terminally recovers the active request and requires a fresh arm.
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
    case rejected(String)

    var errorDescription: String? {
        switch self {
        case .notInstalled: "The privileged helper is not installed."
        case .badProxy: "Could not create a connection to the helper."
        case .malformedReply: "The helper sent a malformed reply."
        case .rejected(let message): message
        }
    }
}

@MainActor
@Observable
final class HelperClient: HelperControlling {
    private(set) var installState: HelperInstallState = .unknown
    var onInterruption: (@MainActor () -> Void)?

    private var connection: NSXPCConnection?
    /// Once remote cleanup is dispatched, a missing or malformed reply cannot
    /// distinguish "nothing happened" from "the daemon committed removal."
    /// Keep risk-increasing work fail-closed until final inactive-registration
    /// and normal-sleep evidence jointly resolve that ambiguity. Recovery-only
    /// restoration and cancellation remain available.
    private var removalFence: HelperRemovalClientSafety.Fence = .open

    private var service: SMAppService {
        SMAppService.daemon(plistName: LidlessIDs.helperPlistName)
    }

    // MARK: - Install lifecycle

    func refreshInstallState() async {
        let registrationStatus = service.status
        if removalFence == .outcomeUnresolved {
            if registrationStatus == .notRegistered {
                let independentlyObserved = PowerRegistry.sleepDisabled()
                removalFence = HelperRemovalClientSafety.resolve(
                    removalFence,
                    registrationState: .inactive,
                    independentlyObserved: independentlyObserved
                )
            }
            guard HelperRemovalClientSafety.allows(.install, while: removalFence) else {
                // Registration may be inactive, approval-pending, missing, or
                // enabled here. Do not present an invented registration state.
                installState = .unknown
                return
            }
            invalidateConnection()
            installState = .notInstalled
            return
        }

        switch registrationStatus {
        case .notRegistered, .notFound:
            installState = .notInstalled
        case .requiresApproval:
            installState = .requiresApproval
        case .enabled:
            do {
                let status = try await status()
                installState = status.helperVersion == LidlessIDs.helperVersion
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
        if !HelperRemovalClientSafety.allows(.install, while: removalFence) {
            await refreshInstallState()
            guard HelperRemovalClientSafety.allows(.install, while: removalFence) else {
                throw HelperClientError.rejected(
                    "A previous helper cleanup attempt is still unresolved. Verify inactive registration and normal sleep before reinstalling."
                )
            }
        }
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
        let registrationState = removalRegistrationState()
        let removalAction: HelperRemovalSafety.RegistrationRemovalAction
        switch registrationState {
        case .enabled:
            // Commit the local fence before suspension. XPC may mutate the
            // daemon and then lose or corrupt its reply; such an outcome must
            // never leave this client eligible to install, arm, heartbeat,
            // force sleep, or schedule a new wake.
            removalFence = HelperRemovalClientSafety.beginRemoteCleanup()
            installState = .unknown
            let reply: HelperReply
            do {
                reply = try await callForReply { proxy, done in proxy.uninstall(done) }
            } catch {
                throw NSError(domain: "Lidless", code: 3, userInfo: [
                    NSLocalizedDescriptionKey: "The helper cleanup outcome is unresolved (\(error.localizedDescription)). Lidless will not start risk-increasing privileged work. If normal sleep is not explicitly verified, run \(LidlessIDs.manualFallbackCommand), then check registration before retrying.",
                ])
            }

            let independentlyObserved = PowerRegistry.sleepDisabled()
            guard let authorized = HelperRemovalSafety.removalAction(
                .enabled,
                helperReply: reply,
                independentlyObserved: independentlyObserved
            ) else {
                throw NSError(domain: "Lidless", code: 4, userInfo: [
                    NSLocalizedDescriptionKey: "Normal sleep was not independently verified after helper cleanup (\(reply.error ?? "incomplete proof")). The helper remains installed. Run \(LidlessIDs.manualFallbackCommand), then try again.",
                ])
            }
            removalAction = authorized
        case .inactive:
            let independentlyObserved = PowerRegistry.sleepDisabled()
            guard let authorized = HelperRemovalSafety.removalAction(
                .inactive,
                helperReply: nil,
                independentlyObserved: independentlyObserved
            ) else {
                throw NSError(domain: "Lidless", code: 5, userInfo: [
                    NSLocalizedDescriptionKey: "Normal sleep could not be verified while the helper registration is inactive. Run \(LidlessIDs.manualFallbackCommand), then try again.",
                ])
            }
            removalAction = authorized
        case .unknown:
            throw NSError(domain: "Lidless", code: 6, userInfo: [
                NSLocalizedDescriptionKey: "The helper registration state is unknown. Lidless will not remove supervision until the state can be classified.",
            ])
        }

        // A registration-state transition during the proof window invalidates
        // that evidence. Retry from a fresh classification instead of
        // unregistering a service different from the one just verified.
        guard removalRegistrationState() == registrationState else {
            throw NSError(domain: "Lidless", code: 7, userInfo: [
                NSLocalizedDescriptionKey: "The helper registration changed during removal. Lidless did not request deregistration; try again.",
            ])
        }
        switch removalAction {
        case .alreadyInactive:
            break
        case .unregister:
            do {
                try await Self.unregisterDaemon()
            } catch {
                invalidateConnection()
                installState = .unknown
                throw NSError(domain: "Lidless", code: 8, userInfo: [
                    NSLocalizedDescriptionKey: "Helper deregistration returned an error (\(error.localizedDescription)), so its final state is unknown. The helper may already be unregistered. If normal sleep is not explicitly verified, run \(LidlessIDs.manualFallbackCommand), then try again.",
                ])
            }
        }

        // The pre-action proof authorizes an attempt; it cannot prove the
        // result. Keep the final boundary synchronous so no later registration
        // or registry observation can cross an await and still inherit success.
        invalidateConnection()
        let finalRegistrationState = removalRegistrationState()
        let finalSleepDisabled = PowerRegistry.sleepDisabled()
        let completionProven = HelperRemovalCompletionSafety.isUnregisterCompletionProven(
            registrationState: finalRegistrationState,
            independentlyObserved: finalSleepDisabled
        )
        guard completionProven else {
            installState = .unknown
            throw NSError(domain: "Lidless", code: 9, userInfo: [
                NSLocalizedDescriptionKey: "Helper removal could not be fully verified. The helper may already be unregistered, but Lidless could not prove both inactive registration and normal sleep. If normal sleep is not explicitly verified, run \(LidlessIDs.manualFallbackCommand), then try again.",
            ])
        }
        removalFence = HelperRemovalClientSafety.resolve(
            removalFence,
            registrationState: finalRegistrationState,
            independentlyObserved: finalSleepDisabled
        )
        installState = .notInstalled
    }

    private func removalRegistrationState() -> HelperRemovalSafety.RegistrationState {
        switch service.status {
        case .enabled:
            .enabled
        case .notRegistered:
            .inactive
        case .notFound, .requiresApproval:
            .unknown
        @unknown default:
            .unknown
        }
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
        try ensureOperationAllowed(.arm)
        return try await callForReply { proxy, done in
            proxy.arm(IPCCoding.encode(options), reply: done)
        }
    }

    func heartbeat() async throws -> HelperReply {
        try ensureOperationAllowed(.heartbeat)
        return try await callForReply { proxy, done in proxy.heartbeat(done) }
    }

    func disarm(_ options: HelperDisarmOptions) async throws -> HelperReply {
        try ensureOperationAllowed(
            options.forceSleep ? .forceSleep : .restoreNormalSleep
        )
        return try await callForReply { proxy, done in
            proxy.disarm(IPCCoding.encode(options), reply: done)
        }
    }

    func repairOverride() async throws -> HelperReply {
        try ensureOperationAllowed(.restoreNormalSleep)
        return try await callForReply { proxy, done in proxy.repairOverride(done) }
    }

    func scheduleWake(_ date: Date?) async throws {
        try ensureOperationAllowed(date == nil ? .cancelWake : .scheduleWake)
        let epoch = date?.timeIntervalSince1970 ?? 0
        let reply = try await callForReply { proxy, done in
            proxy.scheduleWake(epoch, reply: done)
        }
        guard reply.ok else {
            throw HelperClientError.rejected(
                reply.error ?? "The helper rejected scheduled-wake reconciliation."
            )
        }
    }

    private func ensureOperationAllowed(
        _ operation: HelperRemovalClientSafety.Operation
    ) throws {
        guard HelperRemovalClientSafety.allows(operation, while: removalFence) else {
            throw HelperClientError.rejected(
                "A helper cleanup attempt has an unresolved outcome; this privileged operation is blocked until inactive registration and normal sleep are verified."
            )
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
