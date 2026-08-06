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
            through: "fileprivate func handleLegacyUninstall("
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
        let wakeCancellation = try #require(cleanup.range(
            of: "try PMSet.cancelWake(rendered: existing.rendered)"
        ))
        let wakeCancellationFailure = try #require(cleanup.range(
            of: "scheduled wake cleanup failed; helper cleanup remains incomplete"
        ))
        let wakeFailureStatus = try #require(cleanup.range(
            of: "let failureStatus = currentStatus()",
            range: wakeCancellation.upperBound..<wakeCancellationFailure.lowerBound
        ))
        let wakeFailureReply = try #require(cleanup.range(
            of: "reply(IPCCoding.encode(HelperReply(",
            range: wakeFailureStatus.upperBound..<wakeCancellationFailure.lowerBound
        ))
        let wakeFailureOK = try #require(cleanup.range(
            of: "ok: false",
            range: wakeFailureReply.upperBound..<wakeCancellationFailure.lowerBound
        ))
        let wakeClear = try #require(cleanup.range(of: "scheduledWake = nil"))
        let wakeReplyStatus = try #require(cleanup.range(
            of: "status: failureStatus",
            range: wakeCancellationFailure.lowerBound..<wakeClear.lowerBound
        ))
        let wakeFailureReturn = try #require(cleanup.range(
            of: "return",
            range: wakeCancellationFailure.upperBound..<wakeClear.lowerBound
        ))
        let dataRemoval = try #require(cleanup.range(of: "FileManager.default.removeItem"))
        let success = try #require(cleanup.range(
            of: "reply(IPCCoding.encode(HelperReply(ok: true"
        ))
        #expect(commit.lowerBound < restore.lowerBound)
        #expect(commit.lowerBound < wakeCancellation.lowerBound)
        #expect(wakeCancellation.lowerBound < wakeFailureStatus.lowerBound)
        #expect(wakeFailureStatus.lowerBound < wakeCancellationFailure.lowerBound)
        #expect(wakeFailureStatus.lowerBound < wakeFailureReply.lowerBound)
        #expect(wakeFailureReply.lowerBound < wakeFailureOK.lowerBound)
        #expect(wakeFailureOK.lowerBound < wakeCancellationFailure.lowerBound)
        #expect(wakeCancellation.lowerBound < wakeCancellationFailure.lowerBound)
        #expect(wakeCancellationFailure.lowerBound < wakeReplyStatus.lowerBound)
        #expect(wakeReplyStatus.lowerBound < wakeFailureReturn.lowerBound)
        #expect(wakeCancellationFailure.lowerBound < wakeFailureReturn.lowerBound)
        #expect(wakeCancellationFailure.lowerBound < wakeClear.lowerBound)
        #expect(wakeFailureReturn.lowerBound < dataRemoval.lowerBound)
        #expect(wakeClear.lowerBound < dataRemoval.lowerBound)
        #expect(commit.lowerBound < dataRemoval.lowerBound)
        #expect(commit.lowerBound < success.lowerBound)
        #expect(!cleanup.contains("try? PMSet.cancelWake"))
        #expect(!cleanup.contains("try? FileManager.default.removeItem"))
        #expect(String(cleanup).components(
            separatedBy: "try PMSet.cancelWake(rendered: existing.rendered)"
        ).count == 2)
        #expect(String(cleanup).components(
            separatedBy: "reply(IPCCoding.encode(HelperReply(ok: true"
        ).count == 2)
        let wakeFailureBranch = cleanup[
            wakeCancellation.lowerBound..<wakeClear.lowerBound
        ]
        #expect(String(wakeFailureBranch).components(
            separatedBy: "ok: false"
        ).count == 2)
        #expect(!cleanup.contains(
            "HelperRemovalDaemonSafety.allows(.retryCleanup"
        ))
    }

    @Test func failedDataRemovalRestoresTheFileAuditSinkBeforeReplying() throws {
        let helper = try repositoryFile("Helper/HelperDaemon.swift")
        let helperLog = try repositoryFile("Helper/HelperLog.swift")
        let cleanup = try section(
            of: helper,
            from: "fileprivate func handleUninstall(",
            through: "fileprivate func handleLegacyUninstall("
        )
        let disableLogControl = try section(
            of: helperLog,
            from: "func disableFileSink()",
            through: "func enableFileSink()"
        )
        let enableLogControl = try section(
            of: helperLog,
            from: "func enableFileSink()",
            through: "private func append("
        )
        let dataCleanup = try section(
            of: String(cleanup),
            from: "log.disableFileSink()",
            through: "reply(IPCCoding.encode(HelperReply(ok: true, status: finalStatus)))"
        )
        let disable = try #require(dataCleanup.range(of: "log.disableFileSink()"))
        let removal = try #require(dataCleanup.range(
            of: "try FileManager.default.removeItem(atPath: HelperPaths.workDirectory)"
        ))
        let reenable = try #require(dataCleanup.range(of: "log.enableFileSink()"))
        let generalCatchInSource = try #require(dataCleanup.range(
            of: "} catch {",
            range: removal.upperBound..<reenable.lowerBound
        ))
        let failureLog = try #require(dataCleanup.range(
            of: "log.error(\"helper data cleanup failed during uninstall:"
        ))
        let failureStatus = try #require(dataCleanup.range(
            of: "let failureStatus = currentStatus()"
        ))
        let failureReply = try #require(dataCleanup.range(
            of: "reply(IPCCoding.encode(HelperReply(",
            range: failureStatus.upperBound..<dataCleanup.endIndex
        ))
        let failureOK = try #require(dataCleanup.range(
            of: "ok: false",
            range: failureReply.upperBound..<dataCleanup.endIndex
        ))
        let failure = try #require(dataCleanup.range(
            of: "helper data cleanup failed; deregistration is not authorized"
        ))
        let replyStatus = try #require(dataCleanup.range(
            of: "status: failureStatus",
            range: failure.lowerBound..<dataCleanup.endIndex
        ))
        let finalStatus = try #require(dataCleanup.range(
            of: "let finalStatus = currentStatus()"
        ))
        let failureReturn = try #require(dataCleanup.range(
            of: "return",
            range: replyStatus.upperBound..<finalStatus.lowerBound
        ))
        let success = try #require(dataCleanup.range(
            of: "reply(IPCCoding.encode(HelperReply(ok: true, status: finalStatus)))"
        ))

        #expect(disable.lowerBound < removal.lowerBound)
        #expect(removal.lowerBound < reenable.lowerBound)
        #expect(generalCatchInSource.lowerBound < reenable.lowerBound)
        #expect(reenable.lowerBound < failureLog.lowerBound)
        #expect(failureLog.lowerBound < failureStatus.lowerBound)
        #expect(failureStatus.lowerBound < failureReply.lowerBound)
        #expect(failureReply.lowerBound < failureOK.lowerBound)
        #expect(failureOK.lowerBound < failure.lowerBound)
        #expect(failureStatus.lowerBound < failure.lowerBound)
        #expect(failure.lowerBound < replyStatus.lowerBound)
        #expect(replyStatus.lowerBound < failureReturn.lowerBound)
        #expect(failureReturn.lowerBound < finalStatus.lowerBound)
        #expect(failure.lowerBound < success.lowerBound)
        #expect(!dataCleanup.contains("fileExists(atPath:"))
        let normalizedDataCleanup = dataCleanup.replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression
        )
        let exactAbsentCatch = "catch let error as CocoaError where "
            + "error.code == .fileNoSuchFile && "
            + "error.filePath == HelperPaths.workDirectory {"
        let absentCatch = try #require(normalizedDataCleanup.range(
            of: exactAbsentCatch
        ))
        let normalizedGeneralCatch = try #require(normalizedDataCleanup.range(
            of: "} catch {",
            range: absentCatch.upperBound..<normalizedDataCleanup.endIndex
        ))
        #expect(absentCatch.lowerBound < normalizedGeneralCatch.lowerBound)
        #expect(normalizedDataCleanup.components(
            separatedBy: exactAbsentCatch
        ).count == 2)
        let dataFailureBranch = dataCleanup[
            reenable.lowerBound..<finalStatus.lowerBound
        ]
        #expect(String(dataFailureBranch).components(
            separatedBy: "ok: false"
        ).count == 2)
        #expect(String(dataCleanup).components(
            separatedBy: "try FileManager.default.removeItem(atPath: HelperPaths.workDirectory)"
        ).count == 2)
        #expect(String(disableLogControl).components(
            separatedBy: "queue.sync { self.fileSinkEnabled = false }"
        ).count == 2)
        #expect(!disableLogControl.contains("self.fileSinkEnabled = true"))
        #expect(String(enableLogControl).components(
            separatedBy: "queue.sync { self.fileSinkEnabled = true }"
        ).count == 2)
        #expect(!enableLogControl.contains("self.fileSinkEnabled = false"))
    }

    @Test func cleanupCompletionRechecksNormalSleepAndReturnsFreshStatus() throws {
        let helper = try repositoryFile("Helper/HelperDaemon.swift")
        let cleanup = try section(
            of: helper,
            from: "fileprivate func handleUninstall(",
            through: "fileprivate func handleLegacyUninstall("
        )

        let dataRemoval = try #require(cleanup.range(
            of: "try FileManager.default.removeItem(atPath: HelperPaths.workDirectory)"
        ))
        let wakeClear = try #require(cleanup.range(of: "scheduledWake = nil"))
        let finalStatus = try #require(cleanup.range(
            of: "let finalStatus = currentStatus()"
        ))
        let finalProof = try #require(cleanup.range(
            of: "guard SleepOverrideSafety.isRestoreProven(finalStatus) else"
        ))
        let reenable = try #require(cleanup.range(
            of: "log.enableFileSink()",
            range: finalProof.upperBound..<cleanup.endIndex
        ))
        let failureLog = try #require(cleanup.range(
            of: "log.error(\"normal sleep could not be reverified after helper cleanup\")"
        ))
        let rejected = try #require(cleanup.range(
            of: "error: \"normal sleep could not be reverified after helper cleanup; not authorizing deregistration\""
        ))
        let rejectedReply = try #require(cleanup.range(
            of: "reply(IPCCoding.encode(HelperReply(",
            range: failureLog.upperBound..<rejected.lowerBound
        ))
        let rejectedOK = try #require(cleanup.range(
            of: "ok: false",
            range: rejectedReply.upperBound..<rejected.lowerBound
        ))
        let rejectedStatus = try #require(cleanup.range(
            of: "status: finalStatus",
            range: rejected.upperBound..<cleanup.endIndex
        ))
        let success = try #require(cleanup.range(
            of: "reply(IPCCoding.encode(HelperReply(ok: true, status: finalStatus)))"
        ))
        let rejectedReturn = try #require(cleanup.range(
            of: "return",
            range: rejectedStatus.upperBound..<success.lowerBound
        ))

        #expect(wakeClear.lowerBound < finalStatus.lowerBound)
        #expect(dataRemoval.lowerBound < finalStatus.lowerBound)
        #expect(finalStatus.lowerBound < finalProof.lowerBound)
        #expect(finalProof.lowerBound < reenable.lowerBound)
        #expect(reenable.lowerBound < failureLog.lowerBound)
        #expect(failureLog.lowerBound < rejectedReply.lowerBound)
        #expect(rejectedReply.lowerBound < rejectedOK.lowerBound)
        #expect(rejectedOK.lowerBound < rejected.lowerBound)
        #expect(failureLog.lowerBound < rejected.lowerBound)
        #expect(rejected.lowerBound < rejectedStatus.lowerBound)
        #expect(rejectedStatus.lowerBound < rejectedReturn.lowerBound)
        #expect(rejectedReturn.lowerBound < success.lowerBound)
        #expect(finalProof.lowerBound < success.lowerBound)
        #expect(String(cleanup).components(
            separatedBy: "let finalStatus = currentStatus()"
        ).count == 2)
        let finalFailureBranch = cleanup[
            finalProof.lowerBound..<success.lowerBound
        ]
        #expect(String(finalFailureBranch).components(
            separatedBy: "ok: false"
        ).count == 2)
    }
}
