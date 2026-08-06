import Foundation

/// Unforgeable identity for one non-sleep restoration attempt.
///
/// UUID identity prevents a late suspended operation from ever aliasing a
/// newer restore generation, including across integer wraparound.
public struct NonSleepRestoreGeneration: Hashable, Sendable {
    fileprivate let rawValue: UUID

    fileprivate init() {
        rawValue = UUID()
    }
}

/// Pure state machine for app-side restoration ownership and proof ordering.
///
/// The app owns the asynchronous work; this gate owns the safety decisions:
/// stale generations are ignored, completion requires helper and independent
/// registry proof with no arm request in flight, an optional sleep request is
/// authorized at most once and only from an exact-current helper proof, and
/// quit can require a second proof immediately before committing termination.
public struct NonSleepRestoreGate: Sendable {
    public enum Action: Sendable, Equatable {
        case ignore
        case retry
        /// The responder changed to an unsupported wire protocol. End this
        /// automatic generation instead of retrying incompatible mutations.
        case manualRecoveryRequired
        case dispatchForceSleep
        case awaitFinalProof
        case complete
    }

    private struct ActiveRestore: Sendable {
        let generation: NonSleepRestoreGeneration
        let forceSleepRequested: Bool
        let requiresFinalProof: Bool
        var forceSleepDispatched = false
        var awaitingFinalProof = false
    }

    private var active: ActiveRestore?
    private var completed: Set<NonSleepRestoreGeneration> = []

    public init() {}

    /// Cached presentation alone can never authorize process termination.
    /// The final app-side registry observation must itself be readable and
    /// exactly OFF, with no session or restoration still owned by the app.
    public static func allowsImmediateTermination(
        isDisarmed: Bool,
        hasActiveSession: Bool,
        hasPendingRestore: Bool,
        independentlyObserved: Bool?,
        presentation: SleepPresentationState
    ) -> Bool {
        isDisarmed
            && !hasActiveSession
            && !hasPendingRestore
            && independentlyObserved == false
            && presentation == .verifiedNormal
    }

    /// Starts a generation, or returns the currently active generation. A
    /// caller cannot change the semantics of work that is already in flight.
    public mutating func begin(
        forceSleepRequested: Bool = false,
        requiresFinalProof: Bool = false
    ) -> NonSleepRestoreGeneration {
        if let active {
            return active.generation
        }

        let generation = NonSleepRestoreGeneration()
        active = ActiveRestore(
            generation: generation,
            forceSleepRequested: forceSleepRequested,
            requiresFinalProof: requiresFinalProof
        )
        return generation
    }

    public func owns(_ generation: NonSleepRestoreGeneration) -> Bool {
        active?.generation == generation
    }

    public func isAwaitingFinalProof(_ generation: NonSleepRestoreGeneration) -> Bool {
        active?.generation == generation && active?.awaitingFinalProof == true
    }

    public func isCompleted(_ generation: NonSleepRestoreGeneration) -> Bool {
        completed.contains(generation)
    }

    /// Ends a caller-authorized, never-established arm request only when an
    /// exact current helper proves it owns no session or retry and the app
    /// independently observes an outside override. An established session,
    /// ordinary restore, and quit must not use this: ownership after proof
    /// loss is ambiguous and normal sleep has not been restored.
    public mutating func completeUnownedExternalOverride(
        generation: NonSleepRestoreGeneration,
        helperReply: HelperReply,
        independentlyObserved: Bool?,
        armRequestsInFlight: Int,
        establishedSessionExists: Bool
    ) -> Action {
        guard let current = active,
              current.generation == generation
        else { return .ignore }
        guard !establishedSessionExists,
              armRequestsInFlight == 0,
              SleepOverrideSafety.isUnownedExternalOverride(
                  helperReply.status,
                  independentlyObserved: independentlyObserved
              )
        else { return .retry }

        return complete(current)
    }

    /// Completion stays latched by generation until its waiter consumes it;
    /// a later restore can never overwrite an earlier waiter's result.
    @discardableResult
    public mutating func consumeCompletion(_ generation: NonSleepRestoreGeneration) -> Bool {
        completed.remove(generation) != nil
    }

    public mutating func cancel(_ generation: NonSleepRestoreGeneration) {
        guard active?.generation == generation else { return }
        active = nil
    }

    public mutating func evaluateBaseProof(
        generation: NonSleepRestoreGeneration,
        helperReply: HelperReply,
        independentlyObserved: Bool?,
        armRequestsInFlight: Int
    ) -> Action {
        guard var current = active,
              current.generation == generation
        else { return .ignore }
        // A late arm can re-enable the override after this reply. Preserve the
        // generation until every dispatched arm has settled, even when the
        // responder has changed to an incompatible wire protocol.
        guard armRequestsInFlight == 0 else {
            current.awaitingFinalProof = false
            active = current
            return .retry
        }
        guard SleepOverrideSafety.isRecoveryCompatibleHelper(
            helperReply.status
        ) else {
            active = nil
            return .manualRecoveryRequired
        }
        guard proofIsComplete(
            helperReply: helperReply,
            independentlyObserved: independentlyObserved,
            armRequestsInFlight: armRequestsInFlight
        ) else {
            current.awaitingFinalProof = false
            active = current
            return .retry
        }

        if current.forceSleepRequested, !current.forceSleepDispatched {
            // Broad same-wire proof may complete only de-risking normal-sleep
            // restoration. `sleepnow` is a separate power mutation and keeps
            // the exact-current behavior-revision boundary.
            guard SleepOverrideSafety.isCurrentHelper(helperReply.status) else {
                return advanceAfterRestoreProof(current)
            }
            // Commit the one-shot decision before the caller suspends in XPC.
            current.forceSleepDispatched = true
            active = current
            return .dispatchForceSleep
        }

        return advanceAfterRestoreProof(current)
    }

    public mutating func evaluateFollowUpProof(
        generation: NonSleepRestoreGeneration,
        helperReply: HelperReply,
        independentlyObserved: Bool?,
        armRequestsInFlight: Int
    ) -> Action {
        guard let current = active,
              current.generation == generation,
              current.forceSleepDispatched
        else { return .ignore }
        guard armRequestsInFlight == 0 else { return .retry }
        guard SleepOverrideSafety.isRecoveryCompatibleHelper(
            helperReply.status
        ) else {
            active = nil
            return .manualRecoveryRequired
        }
        guard proofIsComplete(
            helperReply: helperReply,
            independentlyObserved: independentlyObserved,
            armRequestsInFlight: armRequestsInFlight
        ) else {
            return .retry
        }

        return advanceAfterRestoreProof(current)
    }

    public mutating func evaluateFinalProof(
        generation: NonSleepRestoreGeneration,
        helperReply: HelperReply,
        independentlyObserved: Bool?,
        armRequestsInFlight: Int
    ) -> Action {
        guard var current = active,
              current.generation == generation,
              current.requiresFinalProof,
              current.awaitingFinalProof
        else { return .ignore }
        guard armRequestsInFlight == 0 else {
            current.awaitingFinalProof = false
            active = current
            return .retry
        }
        guard SleepOverrideSafety.isRecoveryCompatibleHelper(
            helperReply.status
        ) else {
            active = nil
            return .manualRecoveryRequired
        }
        guard proofIsComplete(
            helperReply: helperReply,
            independentlyObserved: independentlyObserved,
            armRequestsInFlight: armRequestsInFlight
        ) else {
            current.awaitingFinalProof = false
            active = current
            return .retry
        }

        return complete(current)
    }

    /// A thrown or otherwise missing final reply is unknown evidence. Return
    /// to the base restore loop without completing or abandoning ownership.
    public mutating func rejectFinalProof(
        _ generation: NonSleepRestoreGeneration
    ) -> Action {
        guard var current = active,
              current.generation == generation,
              current.requiresFinalProof,
              current.awaitingFinalProof
        else { return .ignore }
        current.awaitingFinalProof = false
        active = current
        return .retry
    }

    private func proofIsComplete(
        helperReply: HelperReply,
        independentlyObserved: Bool?,
        armRequestsInFlight: Int
    ) -> Bool {
        armRequestsInFlight == 0
            && SleepOverrideSafety.isRestoreProven(
                helperReply,
                independentlyObserved: independentlyObserved
            )
    }

    private mutating func advanceAfterRestoreProof(_ current: ActiveRestore) -> Action {
        if current.requiresFinalProof {
            var awaiting = current
            awaiting.awaitingFinalProof = true
            active = awaiting
            return .awaitFinalProof
        }
        return complete(current)
    }

    private mutating func complete(_ current: ActiveRestore) -> Action {
        completed.insert(current.generation)
        active = nil
        return .complete
    }
}
