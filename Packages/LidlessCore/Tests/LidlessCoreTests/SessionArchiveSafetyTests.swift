import Foundation
import Testing
@testable import LidlessCore

@Suite("Session archive persistence safety")
struct SessionArchiveSafetyTests {
    @Test func durableFinalizedHistoryWinsOverAStaleActiveJournal() throws {
        let id = UUID()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(600)
        let unresolved = KeepAwakeSession(
            id: id,
            startedAt: start,
            source: .manual,
            startPercent: 80,
            samples: [BatterySample(time: start, percent: 80, isDischarging: true)]
        )
        let durable = KeepAwakeSession(
            id: id,
            startedAt: start,
            endedAt: end,
            endReason: .manual,
            source: .manual,
            startPercent: 80,
            endPercent: 78,
            samples: [
                BatterySample(time: start, percent: 80, isDischarging: true),
                BatterySample(time: end, percent: 78, isDischarging: true),
            ]
        )

        let resolved = SessionArchiveSafety.recordForArchive(
            unresolved: unresolved,
            durableHistoryMatch: durable,
            proposedEndReason: .appQuit
        )

        #expect(resolved == durable)
        #expect(resolved.endReason == .manual)
    }

    @Test func unfinishedHistoryCannotOverrideTheReconciledEndReason() {
        let id = UUID()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let sampleTime = start.addingTimeInterval(300)
        let unresolved = KeepAwakeSession(
            id: id,
            startedAt: start,
            source: .manual,
            startPercent: 80,
            samples: [
                BatterySample(
                    time: sampleTime,
                    percent: 77.6,
                    isDischarging: true
                ),
            ]
        )
        let unfinished = KeepAwakeSession(
            id: id,
            startedAt: start,
            source: .manual
        )

        let resolved = SessionArchiveSafety.recordForArchive(
            unresolved: unresolved,
            durableHistoryMatch: unfinished,
            proposedEndReason: .appQuit
        )

        #expect(resolved.id == id)
        #expect(resolved.endedAt == sampleTime)
        #expect(resolved.endReason == .appQuit)
        #expect(resolved.endPercent == 78)
    }

    @Test func unrelatedFinalizedHistoryCannotReplaceTheOrphan() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let unresolved = KeepAwakeSession(
            id: UUID(),
            startedAt: start,
            source: .manual
        )
        let unrelated = KeepAwakeSession(
            id: UUID(),
            startedAt: start,
            endedAt: start,
            endReason: .manual,
            source: .manual
        )

        let resolved = SessionArchiveSafety.recordForArchive(
            unresolved: unresolved,
            durableHistoryMatch: unrelated,
            proposedEndReason: .helperRestored
        )

        #expect(resolved.id == unresolved.id)
        #expect(resolved.endReason == .helperRestored)
    }
}
