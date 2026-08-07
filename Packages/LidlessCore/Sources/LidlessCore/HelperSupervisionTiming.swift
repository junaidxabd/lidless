import Foundation

/// Hard timing budget for blocking `pmset` work on the helper's serial state
/// queue. Safety callbacks share that queue, so bounded child-process waits are
/// part of the supervision invariant rather than a performance preference.
public enum HelperSupervisionTiming {
    /// Availability is deliberately secondary to supervision. A slow `pmset`
    /// operation fails closed instead of occupying the state queue for the
    /// helper's 45-second minimum watchdog lifetime.
    public static let pmsetCommandTimeout: TimeInterval = 3

    /// Additional time allowed for a timed-out child to acknowledge SIGKILL.
    public static let forcedTerminationGrace: TimeInterval = 1

    /// Conservative upper bound for one invocation, including forced reaping.
    public static let maximumCommandInterval =
        pmsetCommandTimeout + forcedTerminationGrace

    /// Worst case after the sentinel exists: enable, freshly prove the
    /// captured managed-setting priors, activate each supported scope, read
    /// activation, then a complete fail-safe sleep/settings restoration and
    /// readback. At three scopes this is eleven bounded child waits
    /// (44 seconds), strictly below the 45-second minimum watchdog.
    public static let maximumArmTransactionCommandCount =
        5 + (2 * ManagedSettingRestorationSafety.maximumScopeCommandCount)

    public static func maximumBlockingInterval(commandCount: Int) -> TimeInterval {
        maximumCommandInterval * Double(max(0, commandCount))
    }

    /// A sequence is permitted only when its entire worst-case blocking time
    /// is strictly below the active watchdog TTL. Equality leaves no time for
    /// the queued watchdog/connection callback to execute.
    public static func isWithinWatchdogBudget(
        commandCount: Int,
        watchdogTTL: TimeInterval
    ) -> Bool {
        maximumBlockingInterval(commandCount: commandCount) < watchdogTTL
    }
}
