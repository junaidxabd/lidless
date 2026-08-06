/// Queue-owned lifecycle state for authenticated helper XPC connections.
///
/// Foundation may report both interruption and invalidation for one
/// connection, in either order. A fresh, process-local token identifies each
/// accepted connection; only the first terminal callback removes it and may
/// authorize restoration of an owned sleep override.
public struct HelperConnectionSupervisionSafety<ConnectionID>: Sendable
where ConnectionID: Hashable & Sendable {
    public enum EndDisposition: Sendable, Equatable {
        /// This connection already delivered its terminal event.
        case ignoreDuplicate
        /// A live connection ended, but it did not own an active session.
        case connectionEnded
        /// The first terminal event belongs to the active session owner.
        case restoreOwnedSession
    }

    private var activeConnections: Set<ConnectionID> = []

    public init() {}

    /// Registers one freshly generated identity before the XPC connection is
    /// resumed. Returning false identifies accidental identity reuse.
    @discardableResult
    public mutating func register(_ connectionID: ConnectionID) -> Bool {
        activeConnections.insert(connectionID).inserted
    }

    public func contains(_ connectionID: ConnectionID) -> Bool {
        activeConnections.contains(connectionID)
    }

    public var isEmpty: Bool {
        activeConnections.isEmpty
    }

    public var activeCount: Int {
        activeConnections.count
    }

    /// Commits connection loss exactly once. The caller must execute this on
    /// the same serial state queue used for arm ownership and restoration.
    public mutating func end(
        _ connectionID: ConnectionID,
        owner: ConnectionID?,
        hasActiveSession: Bool
    ) -> EndDisposition {
        guard activeConnections.remove(connectionID) != nil else {
            return .ignoreDuplicate
        }
        guard hasActiveSession, owner == connectionID else {
            return .connectionEnded
        }
        return .restoreOwnedSession
    }
}
