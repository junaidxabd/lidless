import Foundation
import Testing
@testable import LidlessCore

@Suite("Durable mutation marker wiring")
struct DurableMutationMarkerSourceTests {
    @Test func onlyAChangedBootSessionProvesAnInheritedChildCannotRemain() {
        let markerBoot = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let laterBoot = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

        #expect(!DurableMutationRecoverySafety.priorChildExitIsProven(
            markerBootSessionUUID: markerBoot,
            currentBootSessionUUID: markerBoot
        ))
        #expect(DurableMutationRecoverySafety.priorChildExitIsProven(
            markerBootSessionUUID: markerBoot,
            currentBootSessionUUID: laterBoot
        ))
        #expect(!DurableMutationRecoverySafety.priorChildExitIsProven(
            markerBootSessionUUID: nil,
            currentBootSessionUUID: laterBoot
        ))
        #expect(!DurableMutationRecoverySafety.priorChildExitIsProven(
            markerBootSessionUUID: markerBoot,
            currentBootSessionUUID: nil
        ))
    }

    @Test func startupLoadsMarkerBeforeAnyRecoveryMutation() throws {
        let helper = try repositoryFile("Helper/HelperDaemon.swift")
        let start = try section(
            of: helper,
            from: "func start() {",
            through: "private func recoveryPass("
        )

        #expect(helper.contains("private struct DurableMutationMarker"))
        let load = try #require(start.range(of: "try loadDurableMutationMarker()"))
        let recovery = try #require(start.range(of: "recoveryPass(storageFailure:"))
        #expect(load.lowerBound < recovery.lowerBound)
        #expect(helper.contains("durableMutationMarkerLoadedFromPriorProcess"))
    }

    @Test func everyMutationRunsInsidePersistedTracking() throws {
        let helper = try repositoryFile("Helper/HelperDaemon.swift")

        for operation in [
            ".enableOverride",
            ".restoreOverride",
            ".applyManagedSettings",
            ".forceSleep",
            ".scheduleWake",
            ".cancelWake",
        ] {
            #expect(helper.contains("performTrackedMutation(\(operation)"))
        }

        let tracker = try section(
            of: helper,
            from: "private func performTrackedMutation(",
            through: "private func mutationTerminationIsUnproven("
        )
        let persist = try #require(tracker.range(
            of: "try persistDurableMutationMarker(candidate)"
        ))
        let mutate = try #require(tracker.range(of: "try body()"))
        #expect(persist.lowerBound < mutate.lowerBound)
        #expect(tracker.contains("mutationTerminationIsUnproven(error)"))
        #expect(tracker.contains("durableMutationMarkerCanBeCleared"))
    }

    @Test func priorProcessUncertaintyCannotBeInventedAway() throws {
        let helper = try repositoryFile("Helper/HelperDaemon.swift")
        let launchd = try repositoryFile(
            "Helper/Resources/com.lidless.helper.plist"
        )
        let restore = try section(
            of: helper,
            from: "private func performRestore(",
            through: "private func parkRestore("
        )
        let wakeReconciliation = try section(
            of: helper,
            from: "private func reconcileScheduledWakeLedger(",
            through: "private func commitScheduledWakeLedger("
        )

        #expect(restore.contains("durableMutationMarkerRequiresReviewedResolution"))
        #expect(restore.contains(
            "retaining recovery sentinel until the reviewed reboot boundary"
        ))
        #expect(wakeReconciliation.contains(
            "durableMutationMarkerBlocksWakeAbsenceProof"
        ))
        #expect(helper.contains("!durableMutationMarkerRequiresRecovery"))
        #expect(helper.contains("removeDurableMutationMarkerFile()"))
        #expect(launchd.contains(
            "/var/db/lidless/mutation-in-flight.json"
        ))
    }

    @Test func markerPersistsBootIdentityAndOnlyRebootUnlocksRecovery() throws {
        let helper = try repositoryFile("Helper/HelperDaemon.swift")

        #expect(helper.contains("var bootSessionUUID: UUID?"))
        #expect(helper.contains("readCurrentBootSessionUUID()"))
        #expect(helper.contains(
            "DurableMutationRecoverySafety.priorChildExitIsProven("
        ))
        #expect(helper.contains(
            "durableMutationMarkerPriorChildExitProvenByReboot"
        ))
        #expect(helper.contains(
            "same-boot prior-command child exit is unproven"
        ))
        #expect(helper.contains(
            "a reboot boundary proves the prior mutating child cannot remain"
        ))
    }

    private func repositoryFile(_ relativePath: String) throws -> String {
        var directory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
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
