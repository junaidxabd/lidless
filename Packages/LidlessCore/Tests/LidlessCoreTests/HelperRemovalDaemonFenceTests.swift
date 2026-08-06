import Foundation
import Testing
@testable import LidlessCore

@Suite("Helper daemon removal handoff fence")
struct HelperRemovalDaemonFenceTests {
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

    @Test func anOpenFenceAllowsEveryClassifiedOperation() {
        for operation in HelperRemovalDaemonSafety.Operation.allCases {
            #expect(HelperRemovalDaemonSafety.allows(operation, while: .open))
        }
    }

    @Test func startedCleanupBlocksOnlyRiskIncreasingWork() {
        let blocked: [HelperRemovalDaemonSafety.Operation] = [
            .arm,
            .heartbeat,
            .forceSleep,
            .scheduleWake,
            .beginOverrideRepair
        ]
        let recovery: [HelperRemovalDaemonSafety.Operation] = [
            .observe,
            .restoreOwnedState,
            .cancelWake,
            .retryCleanup
        ]

        for operation in blocked {
            #expect(!HelperRemovalDaemonSafety.allows(operation, while: .cleanupStarted))
        }
        for operation in recovery {
            #expect(HelperRemovalDaemonSafety.allows(operation, while: .cleanupStarted))
        }
    }

    @Test func daemonLatchesBeforeSideEffectsAndKeepsOwnedRecoveryAvailable() throws {
        let helper = try repositoryFile("Helper/HelperDaemon.swift")
        let arm = try section(
            of: helper,
            from: "fileprivate func handleArm(",
            through: "private func rejectPreparedArm("
        )
        let heartbeat = try section(
            of: helper,
            from: "fileprivate func handleHeartbeat(",
            through: "fileprivate func handleDisarm("
        )
        let disarm = try section(
            of: helper,
            from: "fileprivate func handleDisarm(",
            through: "fileprivate func handleRepairOverride("
        )
        let repair = try section(
            of: helper,
            from: "fileprivate func handleRepairOverride(",
            through: "fileprivate func handleScheduleWake("
        )
        let wake = try section(
            of: helper,
            from: "fileprivate func handleScheduleWake(",
            through: "fileprivate func handleUninstall("
        )
        let cleanup = try section(
            of: helper,
            from: "fileprivate func handleUninstall(",
            through: "private func currentStatus()"
        )

        #expect(helper.contains(
            "private var helperRemovalFence: HelperRemovalDaemonSafety.Fence = .open"
        ))
        #expect(!helper.contains("uninstallCommitted"))
        #expect(!helper.contains("helperRemovalFence = .open"))
        #expect(helper.components(
            separatedBy: "helperRemovalFence = .cleanupStarted"
        ).count == 2)

        let armFence = try #require(arm.range(
            of: "HelperRemovalDaemonSafety.allows(.arm, while: helperRemovalFence)"
        ))
        let rearmMutation = try #require(arm.range(of: "if var current = sentinel"))
        let freshSentinel = try #require(arm.range(of: "try writeSentinel(record)"))
        let armMutation = try #require(arm.range(of: "try PMSet.setSleepDisabled(true)"))
        #expect(armFence.lowerBound < rearmMutation.lowerBound)
        #expect(armFence.lowerBound < freshSentinel.lowerBound)
        #expect(armFence.lowerBound < armMutation.lowerBound)

        let heartbeatFence = try #require(heartbeat.range(
            of: "HelperRemovalDaemonSafety.allows(.heartbeat, while: helperRemovalFence)"
        ))
        let heartbeatExtension = try #require(heartbeat.range(
            of: "watchdogDeadline = .now() + current.watchdogTTL"
        ))
        #expect(heartbeatFence.lowerBound < heartbeatExtension.lowerBound)

        let forceSleepAdmission = try #require(disarm.range(
            of: "HelperRemovalDaemonSafety.allows(.forceSleep, while: helperRemovalFence)"
        ))
        let disarmReply = try #require(disarm.range(
            of: "reply(IPCCoding.encode(HelperReply("
        ))
        let forceSleep = try #require(disarm.range(of: "try PMSet.sleepNow()"))
        #expect(forceSleepAdmission.lowerBound < disarmReply.lowerBound)
        #expect(forceSleepAdmission.lowerBound < forceSleep.lowerBound)
        #expect(String(disarm).components(separatedBy:
            "HelperRemovalDaemonSafety.allows(.forceSleep, while: helperRemovalFence)"
        ).count == 3)

        #expect(repair.contains(
            "sentinel != nil || restorePending != nil ? .restoreOwnedState : .beginOverrideRepair"
        ))
        let repairClassification = try #require(repair.range(
            of: "let removalOperation: HelperRemovalDaemonSafety.Operation"
        ))
        let repairFence = try #require(repair.range(
            of: "HelperRemovalDaemonSafety.allows(removalOperation, while: helperRemovalFence)"
        ))
        let repairSentinel = try #require(repair.range(of: "try writeSentinel(record)"))
        #expect(repairClassification.lowerBound < repairFence.lowerBound)
        #expect(repairFence.lowerBound < repairSentinel.lowerBound)
        #expect(wake.contains(
            "epoch > 0 ? .scheduleWake : .cancelWake"
        ))
        let wakeClassification = try #require(wake.range(
            of: "let removalOperation: HelperRemovalDaemonSafety.Operation"
        ))
        let wakeFence = try #require(wake.range(
            of: "HelperRemovalDaemonSafety.allows(removalOperation, while: helperRemovalFence)"
        ))
        let wakeMutation = try #require(wake.range(of: "PMSet.scheduleWake"))
        #expect(wakeClassification.lowerBound < wakeFence.lowerBound)
        #expect(wakeFence.lowerBound < wakeMutation.lowerBound)

        let cancelBranch = try section(
            of: String(wake),
            from: "} else if let existing = scheduledWake {",
            through: "persistScheduledWake()"
        )
        #expect(!cancelBranch.contains("try? PMSet.cancelWake"))
        let cancelAttempt = try #require(cancelBranch.range(
            of: "try PMSet.cancelWake(rendered: existing.rendered)"
        ))
        let cancelFailure = try #require(cancelBranch.range(
            of: "reply(replyData(ok: false"
        ))
        let clearWake = try #require(cancelBranch.range(of: "scheduledWake = nil"))
        #expect(cancelAttempt.lowerBound < clearWake.lowerBound)
        #expect(cancelFailure.lowerBound < clearWake.lowerBound)

        let commit = try #require(cleanup.range(of: "helperRemovalFence = .cleanupStarted"))
        let restore = try #require(cleanup.range(of: "performRestore(record"))
        let wakeCancellation = try #require(cleanup.range(of: "PMSet.cancelWake"))
        let dataRemoval = try #require(cleanup.range(of: "FileManager.default.removeItem"))
        let success = try #require(cleanup.range(
            of: "reply(IPCCoding.encode(HelperReply(ok: true"
        ))
        #expect(commit.lowerBound < restore.lowerBound)
        #expect(commit.lowerBound < wakeCancellation.lowerBound)
        #expect(commit.lowerBound < dataRemoval.lowerBound)
        #expect(commit.lowerBound < success.lowerBound)
        #expect(!cleanup.contains(
            "HelperRemovalDaemonSafety.allows(.retryCleanup"
        ))
    }
}
