/// Safety policy for the system-wide `pmset disablesleep` override.
///
/// The registry read is optional because IOKit can fail or temporarily omit
/// the property. `nil` is therefore an unknown state, never proof of success.
public enum SleepOverrideSafety {
    public enum Preflight: Sendable, Equatable {
        case safeToArm
        case externalOverrideActive
        case stateUnverified
    }

    public enum FailedArmDisposition: Sendable, Equatable {
        /// The failed request nevertheless returned complete proof that normal
        /// sleep is already restored, so no compensating mutation is needed.
        case alreadyRestored
        /// No helper-owned or recovering session exists, while the app's own
        /// fresh registry read shows an active outside override. Lidless must
        /// not seize that other owner's setting merely because its arm failed.
        case externalOverride
        /// Ownership or final state is still possible or unknown. Keep the
        /// recovery path visible and retry an idempotent restore.
        case recoveryRequired
    }

    /// A fresh session may take ownership only when the registry proves the
    /// override is currently inactive. This prevents Lidless from inheriting
    /// another tool's override and later claiming it restored normal sleep.
    public static func preflight(observed: Bool?) -> Preflight {
        switch observed {
        case false: .safeToArm
        case true: .externalOverrideActive
        case nil: .stateUnverified
        }
    }

    /// Product recovery always means ordinary macOS sleep is enabled. The
    /// recorded prior remains in the sentinel for backward decoding, but a
    /// legacy `true` can never keep the machine forced awake after recovery.
    public static func restoreTarget(recordedPrior _: Bool) -> Bool {
        false
    }

    /// A mutation is verified only by an exact, readable registry match.
    public static func isVerified(expected: Bool, observed: Bool?) -> Bool {
        observed == expected
    }

    /// Wire-version equality is insufficient: an already registered helper
    /// can retain the same protocol while predating a safety-critical behavior
    /// repair. Missing, older, and future revisions all fail closed.
    public static func isCurrentHelper(_ status: HelperStatus) -> Bool {
        status.helperVersion == LidlessIDs.helperVersion
            && status.helperSafetyRevision == LidlessIDs.helperSafetyRevision
    }

    /// The app may expose an armed session only when the helper confirms it
    /// owns a live session and a readable registry shows the override on.
    public static func isArmProven(_ reply: HelperReply) -> Bool {
        reply.ok
            && isArmProven(reply.status)
    }

    /// Status-only probes can renew presentation proof, but only for the
    /// current safety protocol and an exact readable armed state.
    public static func isArmProven(_ status: HelperStatus) -> Bool {
        isCurrentHelper(status)
            && status.armed
            && status.sleepStateVerified == true
            && status.sleepDisabled
            && status.restorePending == false
    }

    /// The app may end a session and announce normal sleep only when the
    /// helper reply and its registry evidence agree that recovery is complete.
    /// Missing fields from an older helper are deliberately not proof.
    public static func isRestoreProven(_ reply: HelperReply) -> Bool {
        reply.ok && isRestoreProven(reply.status)
    }

    /// App-level completion requires two independent observations of the
    /// global sleep state: the helper's fresh readback and a separately
    /// refreshed registry read in the unprivileged app. A disagreement or an
    /// unreadable app-side value keeps recovery pending.
    public static func isRestoreProven(
        _ reply: HelperReply,
        independentlyObserved: Bool?
    ) -> Bool {
        isRestoreProven(reply)
            && isVerified(expected: false, observed: independentlyObserved)
    }

    /// Status polling proves restoration only when the helper owns no live
    /// session, the registry read succeeded and reports normal sleep, and no
    /// retry remains pending. Missing fields from an older helper are unknown.
    public static func isRestoreProven(_ status: HelperStatus) -> Bool {
        isCurrentHelper(status)
            && !status.armed
            && status.sleepStateVerified == true
            && status.sleepDisabled == false
            && status.restorePending == false
    }

    /// Status polling follows the same two-source completion rule as an
    /// operation reply. This overload is intentionally app-facing; the helper
    /// itself has only its own registry readback and uses the overload above.
    public static func isRestoreProven(
        _ status: HelperStatus,
        independentlyObserved: Bool?
    ) -> Bool {
        isRestoreProven(status)
            && isVerified(expected: false, observed: independentlyObserved)
    }

    /// Proves that the current helper owns no live or recovering Lidless
    /// session while the app independently observes an active override. This
    /// is not restore proof: it only authorizes a terminal recovery path to
    /// stop retrying mutations that would belong to another actor.
    public static func isUnownedExternalOverride(
        _ status: HelperStatus,
        independentlyObserved: Bool?
    ) -> Bool {
        isCurrentHelper(status)
            && !status.armed
            && status.restorePending == false
            && independentlyObserved == true
    }

    /// Classifies a completed arm reply that did not prove a live arm. The
    /// only non-restoring ON case is fresh evidence that the helper owns no
    /// session or retry and the app independently observes an outside
    /// override. Contradictory or incomplete evidence remains recovery work.
    public static func failedArmDisposition(
        _ reply: HelperReply,
        independentlyObserved: Bool?
    ) -> FailedArmDisposition {
        if isRestoreProven(
            reply.status,
            independentlyObserved: independentlyObserved
        ) {
            return .alreadyRestored
        }

        if isUnownedExternalOverride(
            reply.status,
            independentlyObserved: independentlyObserved
        ) {
            return .externalOverride
        }

        return .recoveryRequired
    }
}
