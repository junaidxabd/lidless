/// Pure admission policy for the helper connection that owns an active
/// sleep-override session.
///
/// Recovery operations remain intentionally available to every authenticated
/// app connection, but no second connection may acquire or prolong an active
/// override. A fresh arm establishes one owner; only that exact owner may
/// renew its watchdog with a heartbeat.
public enum HelperSessionOwnershipSafety {
    public enum ArmDisposition: Sendable, Equatable {
        case beginFreshSession
        case rejectActiveSession
    }

    public enum HeartbeatDisposition: Sendable, Equatable {
        case renew
        case rejectNoSession
        case rejectNonOwner
    }

    public static func armDisposition(
        hasActiveSession: Bool
    ) -> ArmDisposition {
        hasActiveSession ? .rejectActiveSession : .beginFreshSession
    }

    public static func heartbeatDisposition<ConnectionID: Equatable>(
        hasActiveSession: Bool,
        owner: ConnectionID?,
        requester: ConnectionID
    ) -> HeartbeatDisposition {
        guard hasActiveSession else { return .rejectNoSession }
        guard owner == requester else { return .rejectNonOwner }
        return .renew
    }
}
