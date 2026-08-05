/// Pure admission decisions for the app side of helper removal.
///
/// These checks serialize only work routed through one `AppState` instance.
/// They do not prove daemon cleanup, deregistration, cross-process exclusion,
/// restart durability, or successful restoration of privileged state.
public enum HelperRemovalAppSafety {
    /// Removal must acquire its app-local latch before its first suspension,
    /// and only while no competing app-routed helper lifecycle or termination
    /// operation owns the same state.
    public static func canStartRemoval(
        isSimulation: Bool,
        removalInProgress: Bool,
        terminationPending: Bool,
        helperLifecycleOperationsInFlight: Int
    ) -> Bool {
        !isSimulation
            && !removalInProgress
            && !terminationPending
            && helperLifecycleOperationsInFlight == 0
    }

    /// After any active arm has been restored, removal may contact the helper
    /// only when these selected arm/restore fields are locally quiescent. This
    /// does not account for an already-dispatched wake, status, or heartbeat
    /// request. Exact equality deliberately makes an impossible negative arm
    /// request count fail closed.
    public static func canProceedRemoval(
        isDisarmed: Bool,
        hasCurrentSession: Bool,
        hasPendingArm: Bool,
        hasPendingRestore: Bool,
        armRequestsInFlight: Int,
        sleepTerminationInProgress: Bool
    ) -> Bool {
        isDisarmed
            && !hasCurrentSession
            && !hasPendingArm
            && !hasPendingRestore
            && armRequestsInFlight == 0
            && !sleepTerminationInProgress
    }
}
