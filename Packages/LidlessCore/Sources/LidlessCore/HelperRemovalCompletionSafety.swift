/// Pure final evidence gate for a helper-removal attempt.
///
/// Pre-deregistration restoration proof authorizes an attempt; it is not a
/// completion receipt. Success may be reported only when ServiceManagement
/// explicitly reports no registration and a fresh independent registry read
/// still proves normal sleep.
public enum HelperRemovalCompletionSafety {
    /// Simulation has no ServiceManagement or registry evidence and therefore
    /// cannot enter a flow that reports verified helper deregistration.
    public static func canAttemptVerifiedRemoval(isSimulation: Bool) -> Bool {
        !isSimulation
    }

    public static func isUnregisterCompletionProven(
        registrationState: HelperRemovalSafety.RegistrationState,
        independentlyObserved: Bool?
    ) -> Bool {
        registrationState == .inactive && independentlyObserved == false
    }
}
