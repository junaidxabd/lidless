/// Fail-closed authorization for acting on helper status obtained during app
/// launch. An XPC reply can resume after unrelated MainActor work has changed
/// the active session, helper lifecycle, or sleep generation; that late reply
/// must not be allowed to start a restore for obsolete state.
public enum LaunchReconciliationSafety {
    public struct Context: Sendable, Equatable {
        public var isDisarmed: Bool
        public var hasCurrentSession: Bool
        public var hasQueuedArmIntent: Bool
        public var hasPendingRestore: Bool
        public var armRequestsInFlight: Int
        public var terminationPending: Bool
        public var uninstallInProgress: Bool
        public var sleepTerminationInProgress: Bool
        public var helperReachable: Bool
        public var helperProofEpoch: UInt64
        public var helperLifecycleEpoch: UInt64
        public var helperLifecycleOperationsInFlight: Int
        public var sleepGeneration: UInt64

        public init(
            isDisarmed: Bool,
            hasCurrentSession: Bool,
            hasQueuedArmIntent: Bool,
            hasPendingRestore: Bool,
            armRequestsInFlight: Int,
            terminationPending: Bool,
            uninstallInProgress: Bool,
            sleepTerminationInProgress: Bool,
            helperReachable: Bool,
            helperProofEpoch: UInt64,
            helperLifecycleEpoch: UInt64,
            helperLifecycleOperationsInFlight: Int,
            sleepGeneration: UInt64
        ) {
            self.isDisarmed = isDisarmed
            self.hasCurrentSession = hasCurrentSession
            self.hasQueuedArmIntent = hasQueuedArmIntent
            self.hasPendingRestore = hasPendingRestore
            self.armRequestsInFlight = armRequestsInFlight
            self.terminationPending = terminationPending
            self.uninstallInProgress = uninstallInProgress
            self.sleepTerminationInProgress = sleepTerminationInProgress
            self.helperReachable = helperReachable
            self.helperProofEpoch = helperProofEpoch
            self.helperLifecycleEpoch = helperLifecycleEpoch
            self.helperLifecycleOperationsInFlight = helperLifecycleOperationsInFlight
            self.sleepGeneration = sleepGeneration
        }
    }

    public enum Action: Sendable, Equatable {
        /// Local state changed while status was suspended; discard the reply.
        case abandon
        /// The stable reply contains no orphaned helper recovery evidence.
        case none
        /// Enter verified restoration, cancelling only an arm intent that has
        /// not yet dispatched a privileged mutation.
        case restore(cancelQueuedArmIntent: Bool)
    }

    public static func canQuery(_ context: Context) -> Bool {
        isQuiescent(context)
    }

    /// Separates late-reply ownership from status interpretation. Callers may
    /// synchronously retire cached wake authority from an accepted live status
    /// before deciding whether that status proves orphaned recovery work.
    public static func responseBelongsToContext(
        initial: Context,
        current: Context,
        helperStateUnchanged: Bool
    ) -> Bool {
        isQuiescent(initial)
            && isQuiescent(current)
            && helperStateUnchanged
            && initial.helperProofEpoch == current.helperProofEpoch
            && initial.helperLifecycleEpoch == current.helperLifecycleEpoch
            && initial.sleepGeneration == current.sleepGeneration
    }

    public static func decide(
        initial: Context,
        current: Context,
        helperStateUnchanged: Bool,
        status: HelperStatus
    ) -> Action {
        guard responseBelongsToContext(
            initial: initial,
            current: current,
            helperStateUnchanged: helperStateUnchanged
        ) else {
            return .abandon
        }

        // Automatic launch recovery may use a same-wire stale revision for
        // two-source normal-sleep restoration, but it must never dispatch an
        // unsupported request to a different wire protocol. Recheck the live
        // reply as well as the pre-query app state to close the await race.
        guard SleepOverrideSafety.isRecoveryCompatibleHelper(status) else {
            return .abandon
        }

        if status.armed || status.restorePending == true {
            return .restore(cancelQueuedArmIntent: current.hasQueuedArmIntent)
        }

        // A queued intent is harmless while it has not dispatched, but a
        // change during this query means the launch task no longer owns the
        // no-orphan follow-up work.
        guard initial.hasQueuedArmIntent == current.hasQueuedArmIntent else {
            return .abandon
        }
        return .none
    }

    private static func isQuiescent(_ context: Context) -> Bool {
        context.isDisarmed
            && !context.hasCurrentSession
            && !context.hasPendingRestore
            && context.armRequestsInFlight == 0
            && !context.terminationPending
            && !context.uninstallInProgress
            && !context.sleepTerminationInProgress
            && context.helperReachable
            && context.helperLifecycleOperationsInFlight == 0
    }
}
