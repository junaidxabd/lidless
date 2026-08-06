import Foundation

/// Pure fail-closed decisions for a helper process that has received a
/// termination signal while it may still own sleep-override recovery work.
///
/// This governs only voluntary process exit and queue admission. The operating
/// system can still force termination, and no offline policy can prove how long
/// launchd will allow a signalled process to keep retrying.
public enum HelperTerminationSafety {
    public enum Operation: CaseIterable, Sendable, Equatable {
        case arm
        case repairOverride
        case scheduleWake
        case forceSleep
        case observe
        case restoreNormalSleep
    }

    /// A termination request closes operations that can establish or extend
    /// new non-normal state or delay the safety retry queue. Observation and
    /// owned-state restoration through disarm remain available so recovery can
    /// converge.
    public static func allows(
        _ operation: Operation,
        whileTerminationRequested terminationRequested: Bool
    ) -> Bool {
        guard terminationRequested else { return true }
        return switch operation {
        case .observe, .restoreNormalSleep:
            true
        case .arm, .repairOverride, .scheduleWake, .forceSleep:
            false
        }
    }

    /// The helper may voluntarily leave only after a signal requested
    /// termination and no helper-owned recovery state remains. When either
    /// field was populated, clearing both requires exact sleep readback and
    /// sentinel deletion. An initially empty record set does not prove the
    /// global sleep state or claim ownership of an external override.
    public static func canVoluntarilyExit(
        terminationRequested: Bool,
        hasSentinel: Bool,
        hasPendingRestore: Bool
    ) -> Bool {
        terminationRequested && !hasSentinel && !hasPendingRestore
    }

    /// Ordinary restore failures retain the existing 30-second cadence. Once
    /// termination is requested, the next timer tick should retry immediately
    /// rather than voluntarily exiting or waiting out the ordinary delay.
    public static func restoreRetryDelay(
        terminationRequested: Bool
    ) -> TimeInterval {
        terminationRequested ? 0 : 30
    }
}
