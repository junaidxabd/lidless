import Foundation

/// Tracks process-local reconciliation evidence from scheduled-wake replies.
///
/// The app must not treat dispatch as success: XPC can reject the request or
/// fail after it was sent. Only a matching successful reply can advance the
/// confirmed state, and unresolved older calls keep that success provisional.
/// Invalidation drops cached evidence while retaining outstanding identities.
/// A late reply from an older local generation can never confirm the
/// current desired state and may force another reconciliation.
public struct ScheduledWakeReconciliation: Sendable {
    public enum Outcome: Sendable {
        /// The helper returned an explicit successful reply.
        case confirmed
        /// The helper returned an explicit negative reply.
        case rejected
        /// No definitive helper reply arrived, so remote mutation is unknown.
        case uncertain
    }

    public struct Request: Sendable, Equatable {
        public let id: UUID
        public let desired: Date?

        fileprivate init(id: UUID, desired: Date?) {
            self.id = id
            self.desired = desired
        }
    }

    private enum ConfirmedState: Sendable {
        case unknown
        case known(Date?)
        /// A matching success arrived while an ordering hazard remains.
        /// Suppress duplicate attempts, but do not treat this as confirmation.
        case provisional(Date?)
    }

    private struct InFlight: Sendable {
        let request: Request
        var taintedByStaleReply = false
    }

    private var confirmed: ConfirmedState = .unknown
    private var inFlight: InFlight?
    private var staleOutstanding: Set<UUID> = []
    /// Sticky, bounded marker for a completed client call whose remote effect
    /// cannot be determined. It prevents false confirmation without retaining
    /// one UUID per transport failure.
    private var hasIndeterminateRemoteOutcome = false

    public init() {}

    /// Begins one reconciliation when the desired value is not already proven
    /// or provisionally attempted. A changed desired value supersedes the
    /// current local request so an older hung call cannot prevent app-side
    /// dispatch of changed intent. Callers retry after a failed completion.
    public mutating func begin(desired: Date?) -> Request? {
        if let current = inFlight {
            guard current.request.desired != desired else { return nil }
            staleOutstanding.insert(current.request.id)
            confirmed = .unknown
        }
        if case .known(let current) = confirmed, current == desired {
            return nil
        }
        if case .provisional(let current) = confirmed,
           current == desired {
            return nil
        }

        let request = Request(id: UUID(), desired: desired)
        inFlight = InFlight(request: request)
        return request
    }

    /// Accepts only the current request's outcome. Rejection returns the cache
    /// to unknown so the desired state remains retryable. Transport uncertainty
    /// leaves a sticky ordering hazard because remote mutation may have occurred.
    /// A stale outcome taints concurrent or completed newer work because reply
    /// delivery order does not prove remote mutation order.
    public mutating func complete(_ requestID: UUID, outcome: Outcome) {
        if let current = inFlight, current.request.id == requestID {
            inFlight = nil
            if case .uncertain = outcome {
                hasIndeterminateRemoteOutcome = true
                confirmed = .unknown
            } else if case .confirmed = outcome,
                      !current.taintedByStaleReply {
                confirmed = staleOutstanding.isEmpty && !hasIndeterminateRemoteOutcome
                    ? .known(current.request.desired)
                    : .provisional(current.request.desired)
            } else {
                confirmed = .unknown
            }
            return
        }

        guard staleOutstanding.contains(requestID) else { return }
        if case .uncertain = outcome {
            hasIndeterminateRemoteOutcome = true
        }
        // ResumeOnce guarantees this completed call cannot later resolve a
        // second time, regardless of whether its remote effect was knowable.
        staleOutstanding.remove(requestID)
        if inFlight != nil {
            inFlight?.taintedByStaleReply = true
        } else {
            confirmed = .unknown
        }
    }

    /// Checked on the app actor immediately before entering the async client
    /// call. This suppresses work already observed stale; it is not atomic
    /// with XPC delivery and cannot cancel a call that was already dispatched.
    public func isCurrent(_ requestID: UUID) -> Bool {
        inFlight?.request.id == requestID
    }

    /// Removes a superseded request that the caller proved never entered the
    /// async client call. If no possibly-dispatched older work remains, a
    /// provisional matching success becomes confirmed.
    public mutating func discardUndispatched(_ requestID: UUID) {
        guard staleOutstanding.remove(requestID) != nil else { return }
        if staleOutstanding.isEmpty,
           !hasIndeterminateRemoteOutcome,
           case .provisional(let desired) = confirmed {
            confirmed = .known(desired)
        }
    }

    /// Exposes whether the local cache has non-provisional matching evidence.
    /// This does not assert authoritative helper or RTC readback.
    func isConfirmed(desired: Date?) -> Bool {
        if case .known(let current) = confirmed {
            return current == desired
        }
        return false
    }

    var hasUnresolvedOrderingHazard: Bool {
        hasIndeterminateRemoteOutcome || !staleOutstanding.isEmpty
    }

    var outstandingRequestCount: Int {
        staleOutstanding.count
    }

    /// Starts a new local reconciliation generation and drops cached proof.
    /// Any current request remains tracked until its late completion arrives.
    public mutating func invalidate() {
        if let current = inFlight {
            staleOutstanding.insert(current.request.id)
        }
        inFlight = nil
        confirmed = .unknown
    }
}
