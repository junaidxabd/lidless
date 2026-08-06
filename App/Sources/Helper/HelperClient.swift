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
    /// Restores all managed state, removes helper data, deregisters the daemon.
    func uninstall() async throws

    func status() async throws -> HelperStatus
    func arm(_ options: HelperArmOptions) async throws -> HelperReply
    func heartbeat() async throws -> HelperReply
    func disarm(_ options: HelperDisarmOptions) async throws -> HelperReply
    func repairOverride() async throws -> HelperReply
    func scheduleWake(_ date: Date?) async throws
}

private struct HelperCleanupTarget: Equatable {
    let helperVersion: Int
    let helperSafetyRevision: Int?

    func matches(_ status: HelperStatus) -> Bool {
        status.helperVersion == helperVersion
            && status.helperSafetyRevision == helperSafetyRevision
            && SleepOverrideSafety.isReviewedStaleReplacementCompatible(
                helperVersion: status.helperVersion,
                helperSafetyRevision: status.helperSafetyRevision
            )
    }
}

private enum HelperCleanupOutcome: Equatable {
    case removed
    case replacementNoLongerNeeded
}

/// Removal failures split into two kinds, and the user-facing guidance must
/// match. Most stop before any remote mutation and can say so definitely; a
/// few leave the remote outcome genuinely unresolved. Telling a user to
/// disbelieve a proven "nothing was removed" pushes them toward manual removal,
/// which is exactly what strips launchd's KeepAlive/RunAtLoad supervision.
enum HelperRemovalFailureInfo {
    /// Present and `true` when this failure provably requested neither cleanup
    /// nor deregistration, so the helper is still installed and supervised.
    static let didNotStartKey = "LidlessRemovalDidNotStart"
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
    /// Once remote cleanup is dispatched, a missing or malformed reply cannot
    /// distinguish "nothing happened" from "the daemon committed removal."
    /// Keep risk-increasing work fail-closed until final inactive-registration
    /// and normal-sleep evidence jointly resolve that ambiguity. Recovery-only
    /// restoration and cancellation remain available.
    private var removalFence: HelperRemovalClientSafety.Fence = .open
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
        if !HelperRemovalClientSafety.allows(.install, while: removalFence) {
            await refreshInstallState()
            guard HelperRemovalClientSafety.allows(.install, while: removalFence) else {
                throw HelperClientError.rejected(
                    "A previous helper cleanup attempt is still unresolved. Verify inactive registration and normal sleep before reinstalling."
                )
            }
        }

        // Installation is user-invoked, but the setup screen may have been
        // open while launchd or the responder changed. Reclassify from live
        // ServiceManagement and XPC evidence; never replace from cached UI
        // state alone.
        await refreshInstallState()
        var replacedStaleHelper = false
        switch installState {
        case .notInstalled:
            break
        case .requiresApproval:
            openApprovalSettings()
            return
        case .ready, .simulated:
            return
        case .stale(let helperVersion, let helperSafetyRevision):
            guard SleepOverrideSafety.isReviewedStaleReplacementCompatible(
                helperVersion: helperVersion,
                helperSafetyRevision: helperSafetyRevision
            ) else {
                let revision = helperSafetyRevision.map(String.init) ?? "missing"
                throw HelperClientError.rejected(
                    "The registered helper reports protocol v\(helperVersion), safety revision \(revision). Automatic cleanup is unavailable because this app has not reviewed that helper's complete removal behavior. Emergency sleep recovery only: run \(LidlessIDs.manualFallbackCommand) and verify normal sleep. That command does not cancel helper-managed wakes, restore other settings, delete helper data, or remove its registration. Keep the helper registered and contact Lidless support for a separately reviewed, revision-specific removal procedure."
                )
            }
            // `uninstall()` owns the reviewed two-phase cleanup, independent
            // registry-OFF proof, asynchronous unregister, and final inactive
            // registration proof. Register only after that entire boundary
            // reports `.notInstalled`.
            let cleanupOutcome = try await uninstall(
                expectedCleanupTarget: HelperCleanupTarget(
                    helperVersion: helperVersion,
                    helperSafetyRevision: helperSafetyRevision
                )
            )
            switch cleanupOutcome {
            case .removed:
                break
            case .replacementNoLongerNeeded:
                return
            }
            guard installState == .notInstalled else {
                throw HelperClientError.rejected(
                    "The stale helper replacement did not reach a verified inactive registration. Lidless did not register another helper. Emergency sleep recovery only: run \(LidlessIDs.manualFallbackCommand) and verify normal sleep. That command does not remove the helper or complete replacement. Keep the helper registered and contact Lidless support for a separately reviewed resolution."
                )
            }
            replacedStaleHelper = true
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
            if replacedStaleHelper, installState == .notInstalled {
                throw HelperClientError.rejected(
                    "The stale helper was safely removed, but the new helper could not be registered (\(error.localizedDescription)). Normal sleep is verified and no helper is registered; retry installation from Setup."
                )
            }
            if replacedStaleHelper, installState == .unknown {
                throw HelperClientError.rejected(
                    "The stale helper removal completed, but the new registration attempt returned an error and ServiceManagement could not classify its final state (\(error.localizedDescription)). Lidless will not claim the helper is absent. Do not retry installation until registration and normal sleep are independently verified; contact Lidless support."
                )
            }
            throw error
        }
        await refreshInstallState()
        switch installState {
        case .ready, .simulated:
            return
        case .requiresApproval:
            openApprovalSettings()
        case .notInstalled where replacedStaleHelper:
            throw HelperClientError.rejected(
                "The stale helper was safely removed, but the new helper is not registered. Normal sleep is verified; retry installation from Setup."
            )
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
        _ = try await uninstall(expectedCleanupTarget: nil)
    }

    private func uninstall(
        expectedCleanupTarget: HelperCleanupTarget?
    ) async throws -> HelperCleanupOutcome {
        // Order is safety-critical: deregistering removes launchd's
        // KeepAlive/RunAtLoad supervision, so it must never happen while the
        // helper reports (or the registry shows) the override might still be
        // active. Gate on launchd's own status, not our cached installState —
        // a wedged helper reads as .notResponding but was fully able to arm.
        let registrationState = removalRegistrationState()
        let removalAction: HelperRemovalSafety.RegistrationRemovalAction
        switch registrationState {
        case .enabled:
            // Cleanup is itself a privileged mutation. An older helper may
            // have weaker restoration semantics, so rejecting its reply after
            // cleanup is too late: it may already have discarded the only
            // recovery record. Invalidate cached readiness first, then obtain
            // a process-bound authorization from a responder whose cleanup
            // behavior is explicitly reviewed: the current safety revision or
            // the pinned predecessor revision. Other revision-mismatched
            // responders remain ineligible to arm or clean up; cleanup
            // completion additionally needs structural helper proof and a
            // fresh independent registry-OFF read.
            installState = .unknown
            let cleanupPreparation: HelperCleanupPreparation
            do {
                cleanupPreparation = try await prepareUninstall()
            } catch {
                installState = .notResponding(error.localizedDescription)
                invalidateConnection()
                throw NSError(domain: "Lidless", code: 10, userInfo: [
                    HelperRemovalFailureInfo.didNotStartKey: true,
                    NSLocalizedDescriptionKey: "The registered helper could not be verified before cleanup (\(error.localizedDescription)). Lidless did not request cleanup or deregistration. Keep the helper registered. Emergency sleep recovery only: if normal sleep is not explicitly verified, run \(LidlessIDs.manualFallbackCommand) and verify it. That command does not remove the helper or complete replacement. Contact Lidless support for a separately reviewed removal procedure for the installed helper.",
                ])
            }
            let cleanupTargetAccepted: Bool
            if let expectedCleanupTarget {
                if SleepOverrideSafety.isCurrentHelper(cleanupPreparation.status) {
                    // The selected predecessor was replaced while preparation
                    // was suspended. The enabled responder is already current,
                    // so replacement is complete without cleanup or register.
                    if removalRegistrationState() != registrationState {
                        installState = .unknown
                        invalidateConnection()
                        throw NSError(domain: "Lidless", code: 12, userInfo: [
                            HelperRemovalFailureInfo.didNotStartKey: true,
                            NSLocalizedDescriptionKey: "The helper registration changed during cleanup verification. Lidless did not request cleanup or deregistration; try again from a fresh state.",
                        ])
                    }
                    installState = .ready(
                        helperVersion: cleanupPreparation.status.helperVersion
                    )
                    return .replacementNoLongerNeeded
                }
                // Automatic stale replacement is bound to the exact reviewed
                // predecessor observed before this suspension. A responder
                // that became current (or changed to anything else) must not
                // inherit permission for destructive replacement cleanup.
                cleanupTargetAccepted = expectedCleanupTarget.matches(cleanupPreparation.status)
            } else {
                cleanupTargetAccepted = SleepOverrideSafety.isReviewedCleanupCompatibleHelper(
                    cleanupPreparation.status
                )
            }
            guard cleanupTargetAccepted else {
                installState = classifiedInstallState(for: cleanupPreparation.status)
                let revision = cleanupPreparation.status.helperSafetyRevision
                    .map(String.init) ?? "missing"
                let reason = expectedCleanupTarget == nil
                    ? "whose complete cleanup behavior is not reviewed by this app"
                    : "which no longer matches the exact reviewed predecessor selected for replacement"
                throw NSError(domain: "Lidless", code: 11, userInfo: [
                    HelperRemovalFailureInfo.didNotStartKey: true,
                    NSLocalizedDescriptionKey: "The registered helper reports protocol v\(cleanupPreparation.status.helperVersion), safety revision \(revision), \(reason). Lidless did not request cleanup or deregistration. Keep the helper registered. Emergency sleep recovery only: run \(LidlessIDs.manualFallbackCommand) and verify normal sleep. That command does not complete helper removal. Contact Lidless support for a separately reviewed, revision-specific removal procedure.",
                ])
            }
            guard cleanupPreparation.ok,
                  let cleanupAuthorization = cleanupPreparation.authorization
            else {
                let reason = cleanupPreparation.error
                    ?? "the helper did not issue a cleanup authorization"
                // The helper did respond, but the result cannot represent a
                // usable installation or a completed cleanup preparation.
                installState = .unknown
                throw NSError(domain: "Lidless", code: 13, userInfo: [
                    HelperRemovalFailureInfo.didNotStartKey: true,
                    NSLocalizedDescriptionKey: "The registered helper refused cleanup preparation (\(reason)). Lidless did not request cleanup or deregistration. Keep the helper registered and verify normal sleep before retrying.",
                ])
            }
            // Bind the authorization and reviewed responder classification to
            // the same enabled registration immediately before committing the
            // destructive remote cleanup fence. Executable identity/ABA remains
            // a separately documented runtime gate.
            guard removalRegistrationState() == registrationState else {
                installState = .unknown
                invalidateConnection()
                throw NSError(domain: "Lidless", code: 12, userInfo: [
                    HelperRemovalFailureInfo.didNotStartKey: true,
                    NSLocalizedDescriptionKey: "The helper registration changed during cleanup verification. Lidless did not request cleanup or deregistration; try again from a fresh state.",
                ])
            }
            // Commit the local fence before suspension. XPC may mutate the
            // daemon and then lose or corrupt its reply; such an outcome must
            // never leave this client eligible to install, arm, heartbeat,
            // force sleep, or schedule a new wake.
            removalFence = HelperRemovalClientSafety.beginRemoteCleanup()
            installState = .unknown
            let reply: HelperReply
            do {
                reply = try await callForReply { proxy, done in
                    proxy.commitUninstall(
                        IPCCoding.encode(cleanupAuthorization),
                        reply: done
                    )
                }
            } catch {
                throw NSError(domain: "Lidless", code: 3, userInfo: [
                    NSLocalizedDescriptionKey: "The helper cleanup outcome is unresolved (\(error.localizedDescription)). Lidless will not start risk-increasing privileged work. Emergency sleep recovery only: if normal sleep is not explicitly verified, run \(LidlessIDs.manualFallbackCommand) and verify it. That command does not determine registration or finish removal; check registration before retrying.",
                ])
            }

            let independentlyObserved = PowerRegistry.sleepDisabled()
            guard let authorized = HelperRemovalSafety.removalAction(
                .enabled,
                helperReply: reply,
                independentlyObserved: independentlyObserved
            ) else {
                throw NSError(domain: "Lidless", code: 4, userInfo: [
                    NSLocalizedDescriptionKey: "Normal sleep was not independently verified after helper cleanup (\(reply.error ?? "incomplete proof")). The helper remains installed. Emergency sleep recovery only: run \(LidlessIDs.manualFallbackCommand) and verify normal sleep. That command does not remove the helper; retry removal from Setup only after normal sleep is verified.",
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
                    HelperRemovalFailureInfo.didNotStartKey: true,
                    NSLocalizedDescriptionKey: "Normal sleep could not be verified while the helper registration is inactive. Emergency sleep recovery only: run \(LidlessIDs.manualFallbackCommand) and verify normal sleep, then retry verification. The command does not establish registration state.",
                ])
            }
            removalAction = authorized
        case .unknown:
            throw NSError(domain: "Lidless", code: 6, userInfo: [
                    HelperRemovalFailureInfo.didNotStartKey: true,
                NSLocalizedDescriptionKey: "The helper registration state is unknown. Lidless will not remove supervision until the state can be classified.",
            ])
        }

        // A registration-state transition during the proof window invalidates
        // that evidence. Retry from a fresh classification instead of
        // unregistering a service different from the one just verified.
        guard removalRegistrationState() == registrationState else {
            throw NSError(domain: "Lidless", code: 7, userInfo: [
                    HelperRemovalFailureInfo.didNotStartKey: true,
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
                    NSLocalizedDescriptionKey: "Helper deregistration returned an error (\(error.localizedDescription)), so its final state is unknown. The helper may already be unregistered. Emergency sleep recovery only: if normal sleep is not explicitly verified, run \(LidlessIDs.manualFallbackCommand) and verify it. That command does not establish registration state; check registration before retrying.",
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
                NSLocalizedDescriptionKey: "Helper removal could not be fully verified. The helper may already be unregistered, but Lidless could not prove both inactive registration and normal sleep. Emergency sleep recovery only: if normal sleep is not explicitly verified, run \(LidlessIDs.manualFallbackCommand) and verify it. That command does not establish registration state; check registration before retrying.",
            ])
        }
        removalFence = HelperRemovalClientSafety.resolve(
            removalFence,
            registrationState: finalRegistrationState,
            independentlyObserved: finalSleepDisabled
        )
        installState = .notInstalled
        return .removed
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
        try await call(HelperStatus.self) { proxy, done in
            proxy.ping(done)
        }
    }

    private func prepareUninstall() async throws -> HelperCleanupPreparation {
        try await call(HelperCleanupPreparation.self) { proxy, done in
            proxy.prepareUninstall(done)
        }
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
