import Foundation

/// Durable, pure transaction state for helper-owned one-shot wake events.
///
/// The helper persists this value before every external mutation. A pending
/// schedule loaded after a crash is never promoted from ledger state alone: an
/// observed event is conservatively cancelled, while exact absence permits the
/// record to be removed. Likewise, cancellation never drops an event until a
/// read-only observation proves its exact rendered identity is absent.
public struct ScheduledWakeLedger: Codable, Sendable, Equatable {
    public static let currentVersion = 1

    public enum Phase: String, Codable, Sendable {
        case pendingSchedule
        case scheduled
        case pendingCancel
    }

    public struct Event: Codable, Sendable, Equatable, Identifiable {
        public var id: UUID
        public var date: Date
        public var rendered: String
        public var phase: Phase

        public init(
            rendered: String,
            date: Date,
            phase: Phase,
            id: UUID = UUID()
        ) {
            self.id = id
            self.date = date
            self.rendered = rendered
            self.phase = phase
        }
    }

    /// The next recovery operation. The adapter must persist
    /// `prepareCancellation` before performing `.cancel`, then prove exact
    /// absence with `completeCancellation`. `.removeUnobserved` is already
    /// backed by the observation supplied to `nextAction`, but the transition
    /// repeats that proof before changing state.
    public enum Action: Sendable, Equatable {
        case cancel(Event)
        case removeUnobserved(Event)
    }

    public enum LedgerError: Error, Sendable, Equatable {
        case unsupportedVersion(Int)
        case emptyRenderedIdentity(UUID)
        case nonFiniteDate(UUID)
        case duplicateEventID(UUID)
        case duplicateRenderedIdentity(String)
        case duplicateDesiredDate(Date)
        case multipleScheduledEvents
        case multiplePendingSchedules
        case eventNotFound(UUID)
        case eventNotObserved(UUID)
        case eventObservedMultipleTimes(UUID, Int)
        case eventStillObserved(UUID)
        case invalidTransition(UUID, Phase)
        case desiredEventPendingCancellation(UUID)
        case anotherScheduleIsPending(UUID)
    }

    public private(set) var version: Int
    public private(set) var events: [Event]

    public init(version: Int = Self.currentVersion, events: [Event] = []) {
        self.version = version
        self.events = events
    }

    /// Adds durable intent before a schedule command. Repeating the same
    /// absolute desired date is idempotent and returns the existing exact
    /// rendering, which remains usable after a timezone change.
    @discardableResult
    public mutating func beginScheduling(
        rendered: String,
        date: Date,
        id: UUID = UUID()
    ) throws -> Event {
        try validate()

        if let existing = events.first(where: { $0.date == date }) {
            guard existing.phase != .pendingCancel else {
                throw LedgerError.desiredEventPendingCancellation(existing.id)
            }
            return existing
        }
        if let pending = events.first(where: { $0.phase == .pendingSchedule }) {
            throw LedgerError.anotherScheduleIsPending(pending.id)
        }

        let event = Event(
            rendered: rendered,
            date: date,
            phase: .pendingSchedule,
            id: id
        )
        var candidate = self
        candidate.events.append(event)
        try candidate.validate()
        self = candidate
        return event
    }

    /// Commits a newly programmed event only after exact readback. Replacement
    /// is one atomic ledger transition: every prior committed event becomes a
    /// retained cancellation obligation in the same state that commits the new
    /// event. There is therefore no persisted crash boundary with two committed
    /// events and no record of which old event must be cancelled.
    public mutating func confirmScheduled(
        _ eventID: UUID,
        observedEvents: [String]
    ) throws {
        try validate()
        guard let index = events.firstIndex(where: { $0.id == eventID }) else {
            throw LedgerError.eventNotFound(eventID)
        }
        let observationCount = observedEvents.reduce(into: 0) { count, observed in
            if observed == events[index].rendered {
                count += 1
            }
        }
        guard observationCount > 0 else {
            throw LedgerError.eventNotObserved(eventID)
        }
        guard observationCount == 1 else {
            throw LedgerError.eventObservedMultipleTimes(eventID, observationCount)
        }

        switch events[index].phase {
        case .pendingSchedule:
            var candidate = self
            for otherIndex in candidate.events.indices
            where otherIndex != index && candidate.events[otherIndex].phase == .scheduled {
                candidate.events[otherIndex].phase = .pendingCancel
            }
            candidate.events[index].phase = .scheduled
            try candidate.validate()
            self = candidate
        case .scheduled:
            return
        case .pendingCancel:
            throw LedgerError.invalidTransition(eventID, .pendingCancel)
        }
    }

    /// Creates or refreshes the durable cancellation intent that must be
    /// persisted before the adapter invokes a cancellation command.
    @discardableResult
    public mutating func prepareCancellation(_ eventID: UUID) throws -> Event {
        try validate()
        guard let index = events.firstIndex(where: { $0.id == eventID }) else {
            throw LedgerError.eventNotFound(eventID)
        }
        if events[index].phase != .pendingCancel {
            events[index].phase = .pendingCancel
        }
        try validate()
        return events[index]
    }

    /// Removes a cancellation obligation only after exact absence proof.
    public mutating func completeCancellation(
        _ eventID: UUID,
        observedEvents: [String]
    ) throws {
        try validate()
        guard let index = events.firstIndex(where: { $0.id == eventID }) else {
            throw LedgerError.eventNotFound(eventID)
        }
        guard events[index].phase == .pendingCancel else {
            throw LedgerError.invalidTransition(eventID, events[index].phase)
        }
        try remove(at: index, eventID: eventID, observedEvents: observedEvents)
    }

    /// Reconciles an event that authoritative output already proved absent.
    /// This is used for a command that never ran, an externally removed event,
    /// or an event whose cancellation completed before a crash.
    public mutating func removeUnobserved(
        _ eventID: UUID,
        observedEvents: [String]
    ) throws {
        try validate()
        guard let index = events.firstIndex(where: { $0.id == eventID }) else {
            throw LedgerError.eventNotFound(eventID)
        }
        try remove(at: index, eventID: eventID, observedEvents: observedEvents)
    }

    /// Selects one deterministic recovery step from an authoritative parser
    /// result. Cancellation work is prioritized over ledger-only cleanup, and
    /// already-pending cancellations precede uncertain pending schedules.
    public func nextAction(observedEvents: [String]) throws -> Action? {
        try validate()
        let observed = Set(observedEvents)

        if let event = ordered(events.filter {
            $0.phase == .pendingCancel && observed.contains($0.rendered)
        }).first {
            return .cancel(event)
        }
        if let event = ordered(events.filter {
            $0.phase == .pendingSchedule && observed.contains($0.rendered)
        }).first {
            return .cancel(event)
        }
        if let event = ordered(events.filter { event in
            event.phase == .scheduled
                && observedEvents.lazy.filter { $0 == event.rendered }.count > 1
        }).first {
            return .cancel(event)
        }

        let absent = events.filter { !observed.contains($0.rendered) }
        if let event = absent.sorted(by: recoveryRemovalOrder).first {
            return .removeUnobserved(event)
        }
        return nil
    }

    private mutating func remove(
        at index: Int,
        eventID: UUID,
        observedEvents: [String]
    ) throws {
        guard !observedEvents.contains(events[index].rendered) else {
            throw LedgerError.eventStillObserved(eventID)
        }
        var candidate = self
        candidate.events.remove(at: index)
        try candidate.validate()
        self = candidate
    }

    private func validate() throws {
        guard version == Self.currentVersion else {
            throw LedgerError.unsupportedVersion(version)
        }

        var ids: Set<UUID> = []
        var renderings: Set<String> = []
        var dates: Set<Date> = []
        var scheduledCount = 0
        var pendingScheduleCount = 0

        for event in events {
            guard !event.rendered.isEmpty,
                  !event.rendered.contains("\n"),
                  !event.rendered.contains("\r") else {
                throw LedgerError.emptyRenderedIdentity(event.id)
            }
            guard event.date.timeIntervalSinceReferenceDate.isFinite else {
                throw LedgerError.nonFiniteDate(event.id)
            }
            guard ids.insert(event.id).inserted else {
                throw LedgerError.duplicateEventID(event.id)
            }
            guard renderings.insert(event.rendered).inserted else {
                throw LedgerError.duplicateRenderedIdentity(event.rendered)
            }
            guard dates.insert(event.date).inserted else {
                throw LedgerError.duplicateDesiredDate(event.date)
            }
            if event.phase == .scheduled { scheduledCount += 1 }
            if event.phase == .pendingSchedule { pendingScheduleCount += 1 }
        }

        guard scheduledCount <= 1 else {
            throw LedgerError.multipleScheduledEvents
        }
        guard pendingScheduleCount <= 1 else {
            throw LedgerError.multiplePendingSchedules
        }
    }

    private func ordered(_ candidates: [Event]) -> [Event] {
        candidates.sorted(by: eventOrder)
    }

    private func eventOrder(_ lhs: Event, _ rhs: Event) -> Bool {
        if lhs.date != rhs.date { return lhs.date < rhs.date }
        if lhs.rendered != rhs.rendered { return lhs.rendered < rhs.rendered }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private func recoveryRemovalOrder(_ lhs: Event, _ rhs: Event) -> Bool {
        let lhsPriority = removalPriority(lhs.phase)
        let rhsPriority = removalPriority(rhs.phase)
        if lhsPriority != rhsPriority { return lhsPriority < rhsPriority }
        return eventOrder(lhs, rhs)
    }

    private func removalPriority(_ phase: Phase) -> Int {
        switch phase {
        case .pendingCancel: 0
        case .pendingSchedule: 1
        case .scheduled: 2
        }
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case events
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(Int.self, forKey: .version)
        let events = try container.decode([Event].self, forKey: .events)
        let decoded = Self(version: version, events: events)
        try decoded.validate()
        self = decoded
    }

    public func encode(to encoder: Encoder) throws {
        try validate()
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(events, forKey: .events)
    }
}
