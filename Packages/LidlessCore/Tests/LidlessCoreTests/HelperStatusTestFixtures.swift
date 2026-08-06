import Foundation
@testable import LidlessCore

/// Test-only convenience for legacy fixtures that model the current helper.
/// Production constructors must declare a revision explicitly; raw decoding
/// tests remain responsible for exercising missing and mismatched revisions.
extension HelperStatus {
    init(
        helperVersion: Int,
        armed: Bool,
        sleepDisabled: Bool,
        sleepStateVerified: Bool? = nil,
        restorePending: Bool? = nil,
        armedSince: Date? = nil,
        watchdogDeadline: Date? = nil,
        scheduledWake: Date? = nil
    ) {
        self.init(
            helperVersion: helperVersion,
            helperSafetyRevision: LidlessIDs.helperSafetyRevision,
            armed: armed,
            sleepDisabled: sleepDisabled,
            sleepStateVerified: sleepStateVerified,
            restorePending: restorePending,
            armedSince: armedSince,
            watchdogDeadline: watchdogDeadline,
            scheduledWake: scheduledWake
        )
    }
}
