import Foundation

/// Pure authorization for a delayed `pmset sleepnow` follow-up.
///
/// The helper deliberately waits before forcing sleep so the app can publish
/// its terminal state. A nil sentinel at the end of that delay is not enough:
/// another session can arm and disarm in the meantime, returning the helper to
/// the same apparent state. The generation makes that ABA transition visible.
public enum DelayedSleepSafety {
    /// The follow-up is nominally scheduled after three seconds. A bounded
    /// two-second dispatch tolerance prevents queue stalls from reviving an
    /// old request materially after its user-visible cutoff transition.
    public static let maximumRequestAgeNanoseconds: UInt64 = 5_000_000_000

    public static func allowsForceSleep(
        capturedGeneration: UUID,
        currentGeneration: UUID,
        requestCreatedAtNanoseconds: UInt64,
        currentNanoseconds: UInt64,
        hasActiveSentinel: Bool,
        hasPendingRestore: Bool,
        powerObservationAvailable: Bool,
        observedClamshellClosed: Bool?,
        observedSleepDisabled: Bool?
    ) -> Bool {
        guard currentNanoseconds >= requestCreatedAtNanoseconds,
              currentNanoseconds - requestCreatedAtNanoseconds <= maximumRequestAgeNanoseconds
        else { return false }

        return capturedGeneration == currentGeneration
            && !hasActiveSentinel
            && !hasPendingRestore
            && powerObservationAvailable
            && observedClamshellClosed == true
            && observedSleepDisabled == false
    }
}
