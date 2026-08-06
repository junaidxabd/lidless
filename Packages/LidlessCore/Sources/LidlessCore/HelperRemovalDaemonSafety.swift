/// Process-local admission policy for the daemon's helper-removal handoff.
///
/// `cleanupStarted` is latched before the first fallible cleanup side effect.
/// From that queue-serialized point forward, work that could recreate or extend
/// privileged state is refused even if cleanup fails or its reply is lost.
/// Observation, already-owned restoration, wake cancellation, and cleanup retry
/// remain available; beginning a new repair transaction does not.
///
/// This fence deliberately makes no persistence, cross-process, registration,
/// cleanup-completeness, timeout, or executable-freshness claim. A daemon
/// restart resets it; those are separate protocol and ServiceManagement gates.
public enum HelperRemovalDaemonSafety {
    public enum Fence: Sendable, Equatable {
        case open
        case cleanupStarted
    }

    public enum Operation: Sendable, Equatable, CaseIterable {
        case arm
        case heartbeat
        case forceSleep
        case scheduleWake
        case beginOverrideRepair
        case observe
        case restoreOwnedState
        case cancelWake
        case retryCleanup
    }

    public static func allows(_ operation: Operation, while fence: Fence) -> Bool {
        guard fence == .cleanupStarted else { return true }
        return switch operation {
        case .observe, .restoreOwnedState, .cancelWake, .retryCleanup:
            true
        case .arm, .heartbeat, .forceSleep, .scheduleWake, .beginOverrideRepair:
            false
        }
    }
}
