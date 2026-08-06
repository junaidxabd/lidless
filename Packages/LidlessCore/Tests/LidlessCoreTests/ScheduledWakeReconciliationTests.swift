import Foundation
import Testing
@testable import LidlessCore

@Suite("Scheduled wake reconciliation safety")
struct ScheduledWakeReconciliationTests {
    @Test func rejectedRequestRemainsRetryableWithoutDuplicatingInFlightWork() throws {
        var reconciliation = ScheduledWakeReconciliation()
        let desired = Date(timeIntervalSince1970: 1_700_000_000)

        let firstCandidate = reconciliation.begin(desired: desired)
        let first = try #require(firstCandidate)
        let duplicate = reconciliation.begin(desired: desired)
        #expect(duplicate == nil)

        reconciliation.complete(first.id, outcome: .rejected)
        let retryCandidate = reconciliation.begin(desired: desired)
        let retry = try #require(retryCandidate)
        #expect(retry.id != first.id)
        #expect(retry.desired == desired)
    }

    @Test func onlyAConfirmedReplySuppressesEquivalentFutureWork() throws {
        var reconciliation = ScheduledWakeReconciliation()
        let firstDate = Date(timeIntervalSince1970: 1_700_000_000)
        let secondDate = firstDate.addingTimeInterval(3_600)

        let firstCandidate = reconciliation.begin(desired: firstDate)
        let first = try #require(firstCandidate)
        reconciliation.complete(first.id, outcome: .confirmed)
        #expect(reconciliation.isConfirmed(desired: firstDate))
        let redundant = reconciliation.begin(desired: firstDate)
        #expect(redundant == nil)

        let replacementCandidate = reconciliation.begin(desired: secondDate)
        let replacement = try #require(replacementCandidate)
        #expect(replacement.desired == secondDate)
        reconciliation.complete(replacement.id, outcome: .confirmed)

        let cancellationCandidate = reconciliation.begin(desired: nil)
        let cancellation = try #require(cancellationCandidate)
        #expect(cancellation.desired == nil)
        reconciliation.complete(cancellation.id, outcome: .confirmed)
        #expect(reconciliation.isConfirmed(desired: nil))
        let redundantCancellation = reconciliation.begin(desired: nil)
        #expect(redundantCancellation == nil)
    }

    @Test func changedIntentSupersedesAHungRequestWithoutConfirmingIt() throws {
        var reconciliation = ScheduledWakeReconciliation()
        let scheduled = Date(timeIntervalSince1970: 1_700_000_000)

        let wakeCandidate = reconciliation.begin(desired: scheduled)
        let wake = try #require(wakeCandidate)
        let cancellationCandidate = reconciliation.begin(desired: nil)
        let cancellation = try #require(cancellationCandidate)

        #expect(!reconciliation.isCurrent(wake.id))
        #expect(reconciliation.isCurrent(cancellation.id))
        reconciliation.complete(cancellation.id, outcome: .confirmed)
        #expect(!reconciliation.isConfirmed(desired: nil))

        let duplicateWhileOlderCallIsUnresolved = reconciliation.begin(desired: nil)
        #expect(duplicateWhileOlderCallIsUnresolved == nil)

        reconciliation.complete(wake.id, outcome: .confirmed)
        let retryCandidate = reconciliation.begin(desired: nil)
        let retry = try #require(retryCandidate)
        #expect(retry.id != cancellation.id)
    }

    @Test func supersededUndispatchedWorkDoesNotLeaveProofProvisional() throws {
        var reconciliation = ScheduledWakeReconciliation()
        let staleDesired = Date(timeIntervalSince1970: 1_700_000_000)
        let freshDesired = staleDesired.addingTimeInterval(3_600)

        let staleCandidate = reconciliation.begin(desired: staleDesired)
        let stale = try #require(staleCandidate)
        let freshCandidate = reconciliation.begin(desired: freshDesired)
        let fresh = try #require(freshCandidate)

        reconciliation.complete(fresh.id, outcome: .confirmed)
        #expect(!reconciliation.isConfirmed(desired: freshDesired))
        let duplicateWhileStaleIsUnresolved = reconciliation.begin(desired: freshDesired)
        #expect(duplicateWhileStaleIsUnresolved == nil)

        reconciliation.discardUndispatched(stale.id)
        #expect(reconciliation.isConfirmed(desired: freshDesired))
        let duplicateAfterDiscard = reconciliation.begin(desired: freshDesired)
        #expect(duplicateAfterDiscard == nil)
    }

    @Test func discardingSupersededWorkBeforeFreshSuccessAllowsConfirmation() throws {
        var reconciliation = ScheduledWakeReconciliation()
        let staleDesired = Date(timeIntervalSince1970: 1_700_000_000)
        let freshDesired = staleDesired.addingTimeInterval(3_600)

        let staleCandidate = reconciliation.begin(desired: staleDesired)
        let stale = try #require(staleCandidate)
        let freshCandidate = reconciliation.begin(desired: freshDesired)
        let fresh = try #require(freshCandidate)

        reconciliation.discardUndispatched(stale.id)
        reconciliation.complete(fresh.id, outcome: .confirmed)
        #expect(reconciliation.isConfirmed(desired: freshDesired))

        let duplicate = reconciliation.begin(desired: freshDesired)
        #expect(duplicate == nil)
    }

    @Test func staleReplyTaintsANewerInFlightConfirmation() throws {
        var reconciliation = ScheduledWakeReconciliation()
        let staleDesired = Date(timeIntervalSince1970: 1_700_000_000)
        let freshDesired = staleDesired.addingTimeInterval(3_600)

        let staleCandidate = reconciliation.begin(desired: staleDesired)
        let stale = try #require(staleCandidate)
        #expect(reconciliation.isCurrent(stale.id))
        reconciliation.invalidate()
        #expect(!reconciliation.isCurrent(stale.id))

        let freshCandidate = reconciliation.begin(desired: freshDesired)
        let fresh = try #require(freshCandidate)
        reconciliation.complete(stale.id, outcome: .confirmed)
        #expect(reconciliation.isCurrent(fresh.id))

        reconciliation.complete(fresh.id, outcome: .confirmed)
        let retryCandidate = reconciliation.begin(desired: freshDesired)
        let retry = try #require(retryCandidate)
        #expect(retry.id != fresh.id)
    }

    @Test func staleReplyAfterNewerSuccessForcesFreshReconciliation() throws {
        var reconciliation = ScheduledWakeReconciliation()
        let staleDesired = Date(timeIntervalSince1970: 1_700_000_000)
        let freshDesired = staleDesired.addingTimeInterval(3_600)

        let staleCandidate = reconciliation.begin(desired: staleDesired)
        let stale = try #require(staleCandidate)
        reconciliation.invalidate()

        let freshCandidate = reconciliation.begin(desired: freshDesired)
        let fresh = try #require(freshCandidate)
        reconciliation.complete(fresh.id, outcome: .confirmed)
        let redundantFresh = reconciliation.begin(desired: freshDesired)
        #expect(redundantFresh == nil)

        reconciliation.complete(stale.id, outcome: .confirmed)
        let retryCandidate = reconciliation.begin(desired: freshDesired)
        let retry = try #require(retryCandidate)
        #expect(retry.id != fresh.id)
    }

    @Test func uncertainTransportNeverBecomesConfirmedByALaterSuccess() throws {
        var reconciliation = ScheduledWakeReconciliation()
        let desired = Date(timeIntervalSince1970: 1_700_000_000)

        for _ in 0..<3 {
            let uncertainCandidate = reconciliation.begin(desired: desired)
            let uncertain = try #require(uncertainCandidate)
            reconciliation.complete(uncertain.id, outcome: .uncertain)
            #expect(reconciliation.outstandingRequestCount == 0)
            #expect(reconciliation.hasUnresolvedOrderingHazard)
        }

        let retryCandidate = reconciliation.begin(desired: desired)
        let retry = try #require(retryCandidate)
        reconciliation.complete(retry.id, outcome: .confirmed)

        #expect(!reconciliation.isConfirmed(desired: desired))
        let duplicateWhileOutcomeIsUnresolved = reconciliation.begin(desired: desired)
        #expect(duplicateWhileOutcomeIsUnresolved == nil)
    }

    @Test func staleUncertaintyTaintsNewerWorkAndRemainsSticky() throws {
        var reconciliation = ScheduledWakeReconciliation()
        let staleDesired = Date(timeIntervalSince1970: 1_700_000_000)
        let freshDesired = staleDesired.addingTimeInterval(3_600)

        let staleCandidate = reconciliation.begin(desired: staleDesired)
        let stale = try #require(staleCandidate)
        let freshCandidate = reconciliation.begin(desired: freshDesired)
        let fresh = try #require(freshCandidate)

        reconciliation.complete(stale.id, outcome: .uncertain)
        #expect(reconciliation.outstandingRequestCount == 0)
        #expect(reconciliation.hasUnresolvedOrderingHazard)

        reconciliation.complete(fresh.id, outcome: .confirmed)
        #expect(!reconciliation.isConfirmed(desired: freshDesired))

        let retryCandidate = reconciliation.begin(desired: freshDesired)
        let retry = try #require(retryCandidate)
        reconciliation.complete(retry.id, outcome: .confirmed)
        #expect(!reconciliation.isConfirmed(desired: freshDesired))
        #expect(reconciliation.begin(desired: freshDesired) == nil)
    }

    @Test func appCommitsOnlySuccessfulHelperRepliesAndChecksCurrentWork() throws {
        let app = try repositoryFile("App/Sources/AppState.swift")
        let client = try repositoryFile("App/Sources/Helper/HelperClient.swift")
        let wakeMaintenance = try section(
            of: app,
            from: "private func maintainScheduledWake()",
            through: "// MARK: - Heartbeat"
        )
        let finalize = try section(
            of: app,
            from: "private func finalizeSession(",
            through: "func cutoffLabel("
        )
        let interruption = try section(
            of: app,
            from: "private func helperInterrupted()",
            through: "private func startTerminalRecoveryAfterHelperProofLoss("
        )
        let scheduleCall = try section(
            of: client,
            from: "    func scheduleWake(_ date: Date?) async throws {",
            through: "// MARK: - Connection plumbing"
        )

        #expect(wakeMaintenance.contains("scheduledWakeReconciliation.begin(desired:"))
        #expect(wakeMaintenance.contains("scheduledWakeReconciliation.isCurrent("))
        #expect(wakeMaintenance.contains("scheduledWakeReconciliation.discardUndispatched("))
        #expect(wakeMaintenance.contains("scheduledWakeReconciliation.complete("))
        #expect(!wakeMaintenance.contains("lastScheduledWakeSent = .some(desired)"))
        #expect(wakeMaintenance.contains("catch HelperClientError.rejected(_)"))
        #expect(scheduleCall.contains("guard reply.ok,"))
        #expect(scheduleCall.contains(
            "SleepOverrideSafety.isCurrentHelper(reply.status)"
        ))
        #expect(!scheduleCall.contains("guard reply.ok else"))
        #expect(finalize.contains("scheduledWakeReconciliation.invalidate()"))
        #expect(interruption.contains("scheduledWakeReconciliation.invalidate()"))

        let currentCheck = try #require(wakeMaintenance.range(
            of: "scheduledWakeReconciliation.isCurrent(request.id)"
        ))
        let undispatchedDiscard = try #require(wakeMaintenance.range(
            of: "scheduledWakeReconciliation.discardUndispatched(request.id)"
        ))
        let dispatch = try #require(wakeMaintenance.range(
            of: "helper.scheduleWake(request.desired)"
        ))
        let rejection = try #require(wakeMaintenance.range(
            of: "scheduledWakeReconciliation.complete(request.id, outcome: .rejected)"
        ))
        let success = try #require(wakeMaintenance.range(
            of: "scheduledWakeReconciliation.complete(request.id, outcome: .confirmed)"
        ))
        let uncertainty = try #require(wakeMaintenance.range(
            of: "scheduledWakeReconciliation.complete(request.id, outcome: .uncertain)"
        ))
        #expect(currentCheck.lowerBound < undispatchedDiscard.lowerBound)
        #expect(undispatchedDiscard.lowerBound < dispatch.lowerBound)
        #expect(dispatch.lowerBound < success.lowerBound)
        #expect(success.lowerBound < rejection.lowerBound)
        #expect(rejection.lowerBound < uncertainty.lowerBound)

        let replyGuard = try #require(scheduleCall.range(of: "guard reply.ok,"))
        let revisionGuard = try #require(scheduleCall.range(
            of: "SleepOverrideSafety.isCurrentHelper(reply.status)"
        ))
        let rejectionThrow = try #require(scheduleCall.range(
            of: "throw HelperClientError.rejected"
        ))
        #expect(replyGuard.lowerBound < revisionGuard.lowerBound)
        #expect(revisionGuard.lowerBound < rejectionThrow.lowerBound)
    }

    private func repositoryFile(_ relativePath: String) throws -> String {
        var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let fileManager = FileManager.default

        while directory.path != "/" {
            let candidate = directory.appendingPathComponent(relativePath)
            if fileManager.fileExists(atPath: candidate.path) {
                return try String(contentsOf: candidate, encoding: .utf8)
            }
            directory.deleteLastPathComponent()
        }

        throw CocoaError(.fileNoSuchFile)
    }

    private func section(
        of source: String,
        from start: String,
        through end: String
    ) throws -> Substring {
        let startRange = try #require(source.range(of: start))
        let endRange = try #require(source.range(
            of: end,
            range: startRange.upperBound..<source.endIndex
        ))
        return source[startRange.lowerBound..<endRange.upperBound]
    }
}
