import Foundation
import Testing
@testable import LidlessCore

@Suite("Scheduled wake durable ledger")
struct ScheduledWakeLedgerTests {
    private static let oldID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private static let newID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    private static let laterID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!

    private static let oldDate = Date(timeIntervalSince1970: 1_786_150_800)
    private static let newDate = Date(timeIntervalSince1970: 1_786_154_400)
    private static let laterDate = Date(timeIntervalSince1970: 1_786_158_000)

    private static let oldRendered = "08/08/26 07:00:00"
    private static let newRendered = "08/08/26 08:00:00"
    private static let laterRendered = "08/08/26 09:00:00"

    @Test func newScheduleRequiresExactObservedPostconditionBeforeCommit() throws {
        var ledger = ScheduledWakeLedger()
        let pending = try ledger.beginScheduling(
            rendered: Self.newRendered,
            date: Self.newDate,
            id: Self.newID
        )

        #expect(pending.phase == .pendingSchedule)
        #expect(ledger.events == [pending])

        do {
            try ledger.confirmScheduled(
                Self.newID,
                observedEvents: [Self.newRendered + " UTC"]
            )
            #expect(Bool(false), "A near-match must not commit a scheduled wake")
        } catch let error as ScheduledWakeLedger.LedgerError {
            #expect(error == .eventNotObserved(Self.newID))
        }
        #expect(ledger.events == [pending])

        try ledger.confirmScheduled(Self.newID, observedEvents: [Self.newRendered])
        #expect(ledger.events == [Self.event(
            id: Self.newID,
            date: Self.newDate,
            rendered: Self.newRendered,
            phase: .scheduled
        )])
    }

    @Test func scheduleConfirmationRequiresExactlyOneMatchingObservation() throws {
        var ledger = ScheduledWakeLedger()
        let pending = try ledger.beginScheduling(
            rendered: Self.newRendered,
            date: Self.newDate,
            id: Self.newID
        )

        do {
            try ledger.confirmScheduled(
                Self.newID,
                observedEvents: [Self.newRendered, Self.oldRendered, Self.newRendered]
            )
            #expect(Bool(false), "Duplicate observations must not commit a wake")
        } catch let error as ScheduledWakeLedger.LedgerError {
            #expect(error == .eventObservedMultipleTimes(Self.newID, 2))
        }
        #expect(ledger.events == [pending])

        try ledger.confirmScheduled(
            Self.newID,
            observedEvents: [Self.oldRendered, Self.newRendered]
        )
        let committed = ledger

        do {
            try ledger.confirmScheduled(
                Self.newID,
                observedEvents: [Self.newRendered, Self.newRendered]
            )
            #expect(Bool(false), "Idempotent confirmation still needs unique proof")
        } catch let error as ScheduledWakeLedger.LedgerError {
            #expect(error == .eventObservedMultipleTimes(Self.newID, 2))
        }
        #expect(ledger == committed)
    }

    @Test func committedDuplicateObservationBecomesRestartCancellationWork() throws {
        let committed = Self.event(
            id: Self.newID,
            date: Self.newDate,
            rendered: Self.newRendered,
            phase: .scheduled
        )
        let restarted = try Self.roundTrip(ScheduledWakeLedger(events: [committed]))

        #expect(
            try restarted.nextAction(observedEvents: [
                Self.newRendered,
                Self.oldRendered,
                Self.newRendered,
            ]) == .cancel(committed)
        )
    }

    @Test func replacementAtomicallyCommitsNewAndRetainsOldCancellationObligation() throws {
        let old = Self.event(
            id: Self.oldID,
            date: Self.oldDate,
            rendered: Self.oldRendered,
            phase: .scheduled
        )
        var ledger = ScheduledWakeLedger(events: [old])

        _ = try ledger.beginScheduling(
            rendered: Self.newRendered,
            date: Self.newDate,
            id: Self.newID
        )
        let beforeMutation = try Self.roundTrip(ledger)
        #expect(beforeMutation.events.map(\.phase) == [.scheduled, .pendingSchedule])

        try ledger.confirmScheduled(
            Self.newID,
            observedEvents: [Self.oldRendered, Self.newRendered]
        )
        let committedBoundary = try Self.roundTrip(ledger)

        #expect(committedBoundary.events == [
            Self.event(
                id: Self.oldID,
                date: Self.oldDate,
                rendered: Self.oldRendered,
                phase: .pendingCancel
            ),
            Self.event(
                id: Self.newID,
                date: Self.newDate,
                rendered: Self.newRendered,
                phase: .scheduled
            )
        ])
        #expect(
            try committedBoundary.nextAction(
                observedEvents: [Self.oldRendered, Self.newRendered]
            ) == .cancel(committedBoundary.events[0])
        )

        var afterCancellation = committedBoundary
        do {
            try afterCancellation.completeCancellation(
                Self.oldID,
                observedEvents: [Self.oldRendered, Self.newRendered]
            )
            #expect(Bool(false), "The old event must survive while it is still observed")
        } catch let error as ScheduledWakeLedger.LedgerError {
            #expect(error == .eventStillObserved(Self.oldID))
        }
        #expect(afterCancellation == committedBoundary)

        try afterCancellation.completeCancellation(
            Self.oldID,
            observedEvents: [Self.newRendered]
        )
        #expect(afterCancellation.events == [Self.event(
            id: Self.newID,
            date: Self.newDate,
            rendered: Self.newRendered,
            phase: .scheduled
        )])
    }

    @Test func everyReplacementCrashBoundaryRetainsEnoughInformationToRecover() throws {
        let old = Self.event(
            id: Self.oldID,
            date: Self.oldDate,
            rendered: Self.oldRendered,
            phase: .scheduled
        )
        var ledger = ScheduledWakeLedger(events: [old])

        _ = try ledger.beginScheduling(
            rendered: Self.newRendered,
            date: Self.newDate,
            id: Self.newID
        )
        let persistedPending = try Self.roundTrip(ledger)

        // Crash before the schedule command: authoritative absence permits only
        // removal of the pending record; the old committed wake remains.
        #expect(
            try persistedPending.nextAction(observedEvents: [Self.oldRendered])
                == .removeUnobserved(persistedPending.events[1])
        )

        // Crash after the command but before commit: the newly observed pending
        // wake is conservatively cancelled, never invented as a success.
        #expect(
            try persistedPending.nextAction(
                observedEvents: [Self.oldRendered, Self.newRendered]
            ) == .cancel(persistedPending.events[1])
        )

        try ledger.confirmScheduled(
            Self.newID,
            observedEvents: [Self.oldRendered, Self.newRendered]
        )
        let persistedCommit = try Self.roundTrip(ledger)

        // There is no encodable boundary where the new event is committed but
        // the still-observed old event has lost its cancellation obligation.
        let committedNew = try #require(persistedCommit.events.first {
            $0.id == Self.newID
        })
        let retainedOld = try #require(persistedCommit.events.first {
            $0.id == Self.oldID
        })
        #expect(committedNew.phase == .scheduled)
        #expect(retainedOld.phase == .pendingCancel)
        #expect(
            try persistedCommit.nextAction(
                observedEvents: [Self.oldRendered, Self.newRendered]
            ) == .cancel(retainedOld)
        )

        // Crash after cancellation but before the final ledger write: absence
        // is the proof that permits the old record to be removed.
        #expect(
            try persistedCommit.nextAction(observedEvents: [Self.newRendered])
                == .removeUnobserved(retainedOld)
        )
        var final = persistedCommit
        try final.completeCancellation(Self.oldID, observedEvents: [Self.newRendered])
        let persistedFinal = try Self.roundTrip(final)
        #expect(persistedFinal.events == [committedNew])
        #expect(try persistedFinal.nextAction(observedEvents: [Self.newRendered]) == nil)
    }

    @Test func directCancellationPersistsPendingUntilExactAbsenceProof() throws {
        let committed = Self.event(
            id: Self.oldID,
            date: Self.oldDate,
            rendered: Self.oldRendered,
            phase: .scheduled
        )
        var ledger = ScheduledWakeLedger(events: [committed])

        let pending = try ledger.prepareCancellation(Self.oldID)
        #expect(pending.phase == .pendingCancel)
        #expect(try Self.roundTrip(ledger).events == [pending])
        #expect(
            try ledger.nextAction(observedEvents: [Self.oldRendered]) == .cancel(pending)
        )

        do {
            try ledger.completeCancellation(Self.oldID, observedEvents: [Self.oldRendered])
            #expect(Bool(false), "Observed wake cannot be discarded")
        } catch let error as ScheduledWakeLedger.LedgerError {
            #expect(error == .eventStillObserved(Self.oldID))
        }
        #expect(ledger.events == [pending])

        try ledger.completeCancellation(Self.oldID, observedEvents: [])
        #expect(ledger.events.isEmpty)
    }

    @Test func pendingScheduleAndPendingCancelRestartPathsAreConservative() throws {
        let pendingSchedule = Self.event(
            id: Self.newID,
            date: Self.newDate,
            rendered: Self.newRendered,
            phase: .pendingSchedule
        )
        let pendingCancel = Self.event(
            id: Self.oldID,
            date: Self.oldDate,
            rendered: Self.oldRendered,
            phase: .pendingCancel
        )
        let ledger = try Self.roundTrip(ScheduledWakeLedger(events: [
            pendingSchedule,
            pendingCancel
        ]))

        // An already-pending cancellation is the first de-risking action,
        // independent of insertion order.
        #expect(
            try ledger.nextAction(
                observedEvents: [Self.newRendered, Self.oldRendered]
            ) == .cancel(pendingCancel)
        )
        #expect(
            try ledger.nextAction(observedEvents: [Self.newRendered])
                == .cancel(pendingSchedule)
        )
        #expect(
            try ledger.nextAction(observedEvents: [])
                == .removeUnobserved(pendingCancel)
        )
    }

    @Test func duplicateDesiredWakeDoesNotCreateASecondLedgerEvent() throws {
        let committed = Self.event(
            id: Self.oldID,
            date: Self.oldDate,
            rendered: Self.oldRendered,
            phase: .scheduled
        )
        var ledger = ScheduledWakeLedger(events: [committed])

        let duplicate = try ledger.beginScheduling(
            rendered: "08/08/26 07:00:00 after-timezone-change",
            date: Self.oldDate,
            id: Self.newID
        )

        #expect(duplicate == committed)
        #expect(ledger.events == [committed])
    }

    @Test func nextActionIsDeterministicAcrossInputAndObservationOrder() throws {
        let first = Self.event(
            id: Self.oldID,
            date: Self.oldDate,
            rendered: Self.oldRendered,
            phase: .pendingCancel
        )
        let second = Self.event(
            id: Self.newID,
            date: Self.newDate,
            rendered: Self.newRendered,
            phase: .pendingCancel
        )
        let third = Self.event(
            id: Self.laterID,
            date: Self.laterDate,
            rendered: Self.laterRendered,
            phase: .pendingSchedule
        )

        let forward = ScheduledWakeLedger(events: [third, second, first])
        let reverse = ScheduledWakeLedger(events: [first, second, third])
        let observedForward = [Self.laterRendered, Self.newRendered, Self.oldRendered]
        let observedReverse = observedForward.reversed()

        #expect(try forward.nextAction(observedEvents: observedForward) == .cancel(first))
        #expect(
            try reverse.nextAction(observedEvents: Array(observedReverse)) == .cancel(first)
        )
    }

    @Test func corruptPhaseAndUnsupportedVersionFailClosedDuringDecode() throws {
        let corruptPhase = Data("""
            {
              "version": 1,
              "events": [{
                "id": "00000000-0000-0000-0000-000000000001",
                "date": 0,
                "rendered": "08/08/26 07:00:00",
                "phase": "committed-ish"
              }]
            }
            """.utf8)
        let futureVersion = Data("""
            {"version": 2, "events": []}
            """.utf8)

        do {
            _ = try JSONDecoder().decode(ScheduledWakeLedger.self, from: corruptPhase)
            #expect(Bool(false), "Unknown persisted phase must not decode as no wake")
        } catch {
            #expect(error is DecodingError)
        }

        do {
            _ = try JSONDecoder().decode(ScheduledWakeLedger.self, from: futureVersion)
            #expect(Bool(false), "Unknown ledger versions must fail closed")
        } catch let error as ScheduledWakeLedger.LedgerError {
            #expect(error == .unsupportedVersion(2))
        }
    }

    private static func event(
        id: UUID,
        date: Date,
        rendered: String,
        phase: ScheduledWakeLedger.Phase
    ) -> ScheduledWakeLedger.Event {
        ScheduledWakeLedger.Event(
            rendered: rendered,
            date: date,
            phase: phase,
            id: id
        )
    }

    private static func roundTrip(_ ledger: ScheduledWakeLedger) throws -> ScheduledWakeLedger {
        let encoded = try JSONEncoder().encode(ledger)
        return try JSONDecoder().decode(ScheduledWakeLedger.self, from: encoded)
    }
}
