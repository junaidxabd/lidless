import Foundation
import ServiceManagement
import LidlessCore

enum HelperInstallState: Equatable {
    /// No classification has been attempted yet in this process. This is the
    /// pre-refresh value only — never the result of live evidence — so it must
    /// be rendered as work in progress, never as a verdict about the installed
    /// helper. `.unknown` is the opposite: a classification that concluded the
    /// helper cannot be verified.
    case checking
    case unknown
    /// Not registered with launchd yet (fresh install, or unregistered).
    case notInstalled
    /// Registered; waiting for the user's one-time approval in System Settings.
    case requiresApproval
    case ready(helperVersion: Int)
    /// Helper responds with a protocol or safety revision incompatible with
    /// this app. Preserve both self-reported values so policy and user-facing
    /// recovery instructions can distinguish the reviewed predecessor.
    case stale(helperVersion: Int, helperSafetyRevision: Int?)
    /// launchd says enabled, but XPC calls fail.
    case notResponding(String)
    case simulated

    var isUsable: Bool {
        switch self {
        case .ready, .simulated: true
        default: false
        }
    }

    /// De-risking restore is available to the exact current wire protocol
    /// even when its safety behavior revision is stale. This must never be
    /// used for arming or another risk-increasing operation.
    var isRecoveryUsable: Bool {
        switch self {
        case .ready, .simulated:
            true
        case .stale(let helperVersion, _):
            SleepOverrideSafety.isRecoveryCompatibleHelperVersion(helperVersion)
        default:
            false
        }
    }

    /// An incompatible helper must never arm under this app's safety policy,
    /// but remains reachable for inspection and de-risking recovery requests.
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
    /// Synchronously retire cached readiness when a fresh recovery reply says
    /// the responder is not the exact current safety revision. This method
    /// may demote readiness, never promote it.
    func recordRecoveryOnlyStatus(_ status: HelperStatus)
    func install() async throws
    func openApprovalSettings()
    /// Compatibility surface only. Automatic cleanup is deliberately disabled
    /// because removing launchd supervision needs a separately reviewed flow.
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
    case timedOut(TimeInterval)
    /// The helper returned an explicit negative reply. The requested mutation
    /// did not happen.
    case rejected(String)
    /// The call completed, but this app refused the responder's evidence after
    /// the request was already delivered. The remote effect is unknown — never
    /// classify this as a negative reply.
    case outcomeUnknown(String)

    var errorDescription: String? {
        switch self {
        case .notInstalled: "The privileged helper is not installed."
        case .badProxy: "Could not create a connection to the helper."
        case .malformedReply: "The helper sent a malformed reply."
        case .timedOut(let timeout):
            "The helper request timed out after \(Int(timeout)) seconds; its remote outcome is unknown."
        case .rejected(let message): message
        case .outcomeUnknown(let message): message
        }
    }
}

@MainActor
@Observable
final class HelperClient: HelperControlling {
    private(set) var installState: HelperInstallState = .checking
    var onInterruption: (@MainActor () -> Void)?

    private var connection: NSXPCConnection?
    /// Every install-state refresh owns an epoch across its XPC suspension.
    /// A synchronous stale-status demotion advances the epoch so an older
    /// refresh cannot later overwrite it with cached-ready evidence.
    private var installStateEpoch: UInt64 = 0

    private var service: SMAppService {
        SMAppService.daemon(plistName: LidlessIDs.helperPlistName)
    }

    // MARK: - Install lifecycle

    func refreshInstallState() async {
        installStateEpoch &+= 1
        let epoch = installStateEpoch
        let registrationStatus = service.status
        switch registrationStatus {
        case .notRegistered:
            installState = .notInstalled
        // ServiceManagement documents `.notFound` as an error, not proof that
        // registration is inactive. Never let it mint install eligibility or
        // the safe-but-uninstalled post-replacement state.
        case .notFound:
            installState = .unknown
        case .requiresApproval:
            installState = .requiresApproval
        case .enabled:
            do {
                let status = try await status()
                guard epoch == installStateEpoch else { return }
                installState = classifiedInstallState(for: status)
            } catch {
                guard epoch == installStateEpoch else { return }
                installState = .notResponding(error.localizedDescription)
            }
        @unknown default:
            installState = .unknown
        }
    }

    func recordRecoveryOnlyStatus(_ status: HelperStatus) {
        guard !SleepOverrideSafety.isCurrentHelper(status) else { return }
        installStateEpoch &+= 1
        installState = SleepOverrideSafety.isRecoveryCompatibleHelper(status)
            ? .stale(
                helperVersion: status.helperVersion,
                helperSafetyRevision: status.helperSafetyRevision
            )
            : .unknown
    }

    private func classifiedInstallState(
        for status: HelperStatus
    ) -> HelperInstallState {
        SleepOverrideSafety.isCurrentHelper(status)
            ? .ready(helperVersion: status.helperVersion)
            : .stale(
                helperVersion: status.helperVersion,
                helperSafetyRevision: status.helperSafetyRevision
            )
    }

    func install() async throws {
        // Installation is user-invoked, but the setup screen may have been
        // open while launchd or the responder changed. Reclassify from live
        // ServiceManagement and XPC evidence; never replace from cached UI
        // state alone.
        await refreshInstallState()
        switch installState {
        case .notInstalled:
            break
        case .requiresApproval:
            openApprovalSettings()
            return
        case .ready, .simulated:
            return
        case .stale(let helperVersion, let helperSafetyRevision):
            let revision = helperSafetyRevision.map(String.init) ?? "missing"
            throw HelperClientError.rejected(
                "The registered helper reports protocol v\(helperVersion), safety revision \(revision). Automatic replacement and cleanup are disabled; a reviewed removal procedure is required. Emergency sleep recovery only: run \(LidlessIDs.manualFallbackCommand) and verify normal sleep. That command does not cancel helper-managed wakes, restore other settings, delete helper data, or remove its registration. Keep the helper registered and contact Lidless support."
            )
        case .notResponding(let detail):
            throw HelperClientError.rejected(
                "The registered helper did not provide a compatible live status (\(detail)). Automatic replacement is unavailable. Emergency sleep recovery only: run \(LidlessIDs.manualFallbackCommand) and verify normal sleep. That command does not remove the helper or complete replacement. Keep the helper registered and contact Lidless support for a separately reviewed removal procedure for the installed helper."
            )
        case .unknown:
            throw HelperClientError.rejected(
                "The helper registration could not be classified. Automatic replacement is unavailable. Emergency sleep recovery only: run \(LidlessIDs.manualFallbackCommand) and verify normal sleep. That command does not remove the helper or complete replacement. Keep the helper registered and contact Lidless support for a separately reviewed removal procedure for the installed helper."
            )
        // A concurrent refresh superseded this one, so no classification is
        // available to act on. Nothing has been mutated; fail closed rather
        // than install or replace from absent evidence.
        case .checking:
            throw HelperClientError.rejected(
                "Lidless has not finished classifying the installed helper, so it did not install, replace, or remove anything. Re-check helper status in Setup, then try again."
            )
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
        switch installState {
        case .ready, .simulated:
            return
        case .requiresApproval:
            openApprovalSettings()
        case .stale(let helperVersion, let helperSafetyRevision):
            let revision = helperSafetyRevision.map(String.init) ?? "missing"
            throw HelperClientError.rejected(
                "The registered responder still reports protocol v\(helperVersion), safety revision \(revision). Lidless will not retry replacement automatically. Emergency sleep recovery only: run \(LidlessIDs.manualFallbackCommand) and verify normal sleep. Keep the helper registered and contact Lidless support for a separately reviewed, revision-specific resolution."
            )
        case .notResponding(let detail):
            throw HelperClientError.rejected(
                "The new helper registration could not be verified (\(detail)). Lidless will not retry automatically. Verify normal sleep before taking manual action."
            )
        case .notInstalled:
            throw HelperClientError.rejected(
                "The new helper registration could not be verified. Lidless will not claim installation success; verify registration and normal sleep before retrying."
            )
        case .unknown:
            throw HelperClientError.rejected(
                "ServiceManagement could not classify the helper after registration. Lidless will not claim the helper is absent or retry automatically. Do not retry installation until registration and normal sleep are independently verified; contact Lidless support."
            )
        // The register call returned, but a concurrent refresh superseded the
        // verification. Registration state is genuinely unresolved here, so
        // this must never read as success or as proof the helper is absent.
        case .checking:
            throw HelperClientError.rejected(
                "The registration attempt completed, but Lidless did not finish classifying the result, so it will not claim installation succeeded or that the helper is absent. Re-check helper status in Setup and verify normal sleep before retrying."
            )
        }
    }

    func openApprovalSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    func uninstall() async throws {
        throw HelperClientError.rejected(
            "Automatic helper cleanup is disabled; a reviewed removal procedure is required. Keep the helper registered so launchd recovery supervision remains available."
        )
    }

    // MARK: - XPC surface

    func status() async throws -> HelperStatus {
        try await call(HelperStatus.self) { proxy, done in
            proxy.ping(done)
        }
    }

    func arm(_ options: HelperArmOptions) async throws -> HelperReply {
        return try await callForReply { proxy, done in
            proxy.arm(IPCCoding.encode(options), reply: done)
        }
    }

    func heartbeat() async throws -> HelperReply {
        return try await callForReply { proxy, done in proxy.heartbeat(done) }
    }

    func disarm(_ options: HelperDisarmOptions) async throws -> HelperReply {
        return try await callForReply { proxy, done in
            proxy.disarm(IPCCoding.encode(options), reply: done)
        }
    }

    func repairOverride() async throws -> HelperReply {
        return try await callForReply { proxy, done in proxy.repairOverride(done) }
    }

    func scheduleWake(_ date: Date?) async throws {
        let request = HelperScheduleWakeRequest(desiredDate: date)
        let reply = try await callForReply { proxy, done in
            proxy.scheduleWakeRequest(IPCCoding.encode(request), reply: done)
        }
        recordRecoveryOnlyStatus(reply.status)
        guard reply.ok else {
            throw HelperClientError.rejected(
                reply.error
                    ?? "The helper rejected scheduled-wake reconciliation."
            )
        }
        // The responder reported success but is not the exact current safety
        // revision, so this app refuses its evidence. It may still have applied
        // the RTC wake, which is an indeterminate remote outcome rather than an
        // explicit negative reply: only that classification records the
        // ordering hazard that prevents a later false confirmation.
        guard SleepOverrideSafety.isCurrentHelper(reply.status) else {
            throw HelperClientError.outcomeUnknown(
                "The scheduled-wake responder no longer matches this app's safety revision, so its remote effect is unknown."
            )
        }
    }

    // MARK: - Connection plumbing

    private func ensureConnection() -> NSXPCConnection {
        if let connection { return connection }
        let fresh = NSXPCConnection(machServiceName: LidlessIDs.helperMachService, options: .privileged)
        fresh.remoteObjectInterface = NSXPCInterface(with: LidlessHelperXPC.self)
        fresh.interruptionHandler = { [weak self, weak fresh] in
            Task { @MainActor [weak self, weak fresh] in
                guard let self, let fresh else { return }
                self.handleConnectionLoss(fresh)
            }
        }
        fresh.invalidationHandler = { [weak self, weak fresh] in
            Task { @MainActor [weak self, weak fresh] in
                guard let self, let fresh else { return }
                self.handleConnectionLoss(fresh)
            }
        }
        fresh.resume()
        connection = fresh
        return fresh
    }

    private func invalidateConnection() {
        connection?.invalidate()
        connection = nil
    }

    /// Retire every lost connection, then clear and report loss only for the
    /// currently cached one. Both XPC loss handlers and timeout retirement
    /// converge here because XPC does not guarantee callback ordering. The
    /// identity guard makes their
    /// race exactly once and prevents an old connection from clearing a newer
    /// one or invalidating its helper proof.
    private func handleConnectionLoss(_ lostConnection: NSXPCConnection) {
        lostConnection.invalidate()
        guard connection === lostConnection else { return }
        connection = nil
        onInterruption?()
    }

    /// Retire the exact connection used by a failed request. Always
    /// invalidate that captured connection, but never clear a newer cached
    /// connection that may have replaced it while this request was suspended.
    /// Losing the current connection also invalidates the app's active helper
    /// proof immediately; local invalidation does not reliably deliver the
    /// interruption handler that normally performs that recovery.
    private func retireConnection(_ requestConnection: NSXPCConnection) {
        handleConnectionLoss(requestConnection)
    }

    /// One decoded XPC round trip with a finite, exactly-once local completion.
    /// Every failure retires the request's connection so helper-side
    /// connection supervision can restore an owned override. A transport
    /// error, timeout, or malformed reply cannot retract a request the helper
    /// already received, so callers treat each as an outcome-unknown failure
    /// and reconcile conservatively.
    private func call<Response: Decodable & Sendable>(
        _ responseType: Response.Type,
        _ body: @escaping @Sendable (LidlessHelperXPC, @escaping @Sendable (Data) -> Void) -> Void
    ) async throws -> Response {
        let requestConnection = ensureConnection()
        let completion = HelperXPCRequestSafety.CompletionGate()
        let timeout = HelperXPCRequestSafety.replyTimeout
        do {
            let data: Data = try await withCheckedThrowingContinuation { continuation in
                // Schedule the finite boundary before asking XPC for a proxy
                // or dispatching the remote call. No synchronous setup branch
                // may escape without a completion path.
                DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                    if completion.claim(.timeout) {
                        continuation.resume(throwing: HelperClientError.timedOut(timeout))
                    }
                }
                let anyProxy = requestConnection.remoteObjectProxyWithErrorHandler { error in
                    if completion.claim(.transportFailure) {
                        continuation.resume(throwing: error)
                    }
                }
                guard let proxy = anyProxy as? LidlessHelperXPC else {
                    if completion.claim(.transportFailure) {
                        continuation.resume(throwing: HelperClientError.badProxy)
                    }
                    return
                }
                body(proxy) { data in
                    if completion.claim(.reply) {
                        continuation.resume(returning: data)
                    }
                }
            }
            guard let response = IPCCoding.decode(responseType, from: data) else {
                throw HelperClientError.malformedReply
            }
            return response
        } catch {
            retireConnection(requestConnection)
            throw error
        }
    }

    private func callForReply(
        _ body: @escaping @Sendable (LidlessHelperXPC, @escaping @Sendable (Data) -> Void) -> Void
    ) async throws -> HelperReply {
        try await call(HelperReply.self, body)
    }
}
