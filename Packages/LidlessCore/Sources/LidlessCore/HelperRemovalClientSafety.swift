/// Process-local fail-closed state for a helper cleanup request whose remote
/// outcome may be delayed, malformed, or otherwise ambiguous.
///
/// Dispatching cleanup can mutate the daemon even when the app never receives
/// a usable reply. The client must therefore stop authorizing risk-increasing
/// work at the dispatch boundary, not after a successful decode. Observation
/// and operations that only restore or cancel remain available. Only the same
/// final two-source proof used for deregistration completion may reopen all
/// operations. This fence is intentionally not represented as restart-durable
/// and cannot cancel a cleanup already dispatched to the daemon; those remain
/// separate protocol requirements.
public enum HelperRemovalClientSafety {
    public enum Fence: Sendable, Equatable {
        case open
        case outcomeUnresolved
    }

    public enum Operation: Sendable, Equatable {
        case install
        case arm
        case heartbeat
        case forceSleep
        case scheduleWake
        case observe
        case restoreNormalSleep
        case cancelWake
        case retryCleanup
    }

    public static func beginRemoteCleanup() -> Fence {
        .outcomeUnresolved
    }

    public static func resolve(
        _ fence: Fence,
        registrationState: HelperRemovalSafety.RegistrationState,
        independentlyObserved: Bool?
    ) -> Fence {
        guard fence == .outcomeUnresolved else { return fence }
        return HelperRemovalCompletionSafety.isUnregisterCompletionProven(
            registrationState: registrationState,
            independentlyObserved: independentlyObserved
        ) ? .open : .outcomeUnresolved
    }

    public static func allows(_ operation: Operation, while fence: Fence) -> Bool {
        guard fence == .outcomeUnresolved else { return true }
        return switch operation {
        case .observe, .restoreNormalSleep, .cancelWake, .retryCleanup:
            true
        case .install, .arm, .heartbeat, .forceSleep, .scheduleWake:
            false
        }
    }
}
