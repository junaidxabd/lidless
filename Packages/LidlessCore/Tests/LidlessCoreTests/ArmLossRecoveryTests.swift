import Foundation
import Testing
@testable import LidlessCore

@Suite("Lost arm-proof recovery")
struct ArmLossRecoveryTests {
    private func status(
        armed: Bool = false,
        sleepDisabled: Bool,
        sleepStateVerified: Bool? = true,
        restorePending: Bool? = false
    ) -> HelperStatus {
        HelperStatus(
            helperVersion: LidlessIDs.helperVersion,
            armed: armed,
            sleepDisabled: sleepDisabled,
            sleepStateVerified: sleepStateVerified,
            restorePending: restorePending
        )
    }

    @Test func rejectedArmDoesNotTakeOwnershipOfAnExternalOverride() {
        let rejection = HelperReply(
            ok: false,
            error: "an outside override is already active",
            status: status(sleepDisabled: true)
        )

        #expect(SleepOverrideSafety.failedArmDisposition(
            rejection,
            independentlyObserved: true
        ) == .externalOverride)
    }

    @Test func independentExternalOverrideWinsOverAStaleHelperRead() {
        let rejection = HelperReply(
            ok: false,
            status: status(sleepDisabled: false)
        )

        #expect(SleepOverrideSafety.failedArmDisposition(
            rejection,
            independentlyObserved: true
        ) == .externalOverride)
    }

    @Test func exactNormalSleepProofNeedsNoCompensatingMutation() {
        let rejection = HelperReply(
            ok: false,
            status: status(sleepDisabled: false)
        )

        #expect(SleepOverrideSafety.failedArmDisposition(
            rejection,
            independentlyObserved: false
        ) == .alreadyRestored)
    }

    @Test func terminalRecoveryConcedesOnlyToAProvenUnownedExternalOverride() {
        let outsideOverride = HelperReply(
            ok: false,
            error: "normal sleep is not verified",
            status: status(sleepDisabled: true)
        )

        var acceptingGate = NonSleepRestoreGate()
        let acceptingGeneration = acceptingGate.begin()
        #expect(acceptingGate.completeUnownedExternalOverride(
            generation: acceptingGeneration,
            helperReply: outsideOverride,
            independentlyObserved: true,
            armRequestsInFlight: 0,
            establishedSessionExists: false
        ) == .complete)
        #expect(acceptingGate.isCompleted(acceptingGeneration))

        let rejectedEvidence: [(HelperReply, Bool?, Int, Bool)] = [
            (HelperReply(
                ok: false,
                status: status(armed: true, sleepDisabled: true)
            ), true, 0, false),
            (HelperReply(
                ok: false,
                status: status(sleepDisabled: true, restorePending: true)
            ), true, 0, false),
            (outsideOverride, nil, 0, false),
            (outsideOverride, false, 0, false),
            (outsideOverride, true, 1, false),
            (outsideOverride, true, 0, true),
            (HelperReply(
                ok: false,
                status: HelperStatus(
                    helperVersion: LidlessIDs.helperVersion + 1,
                    armed: false,
                    sleepDisabled: true,
                    sleepStateVerified: true,
                    restorePending: false
                )
            ), true, 0, false)
        ]

        for (reply, observed, inFlight, establishedSessionExists) in rejectedEvidence {
            var gate = NonSleepRestoreGate()
            let generation = gate.begin()
            #expect(gate.completeUnownedExternalOverride(
                generation: generation,
                helperReply: reply,
                independentlyObserved: observed,
                armRequestsInFlight: inFlight,
                establishedSessionExists: establishedSessionExists
            ) == .retry)
            #expect(!gate.isCompleted(generation))
        }
    }

    @Test func proofLossHasATruthfulDurableEndReason() throws {
        let encoded = try IPCCoding.encoder().encode(SessionEndReason.helperProofLost)
        let decoded = try #require(IPCCoding.decode(SessionEndReason.self, from: encoded))
        #expect(decoded == .helperProofLost)

        let history = try repositoryFile("App/Sources/UI/Main/HistoryPane.swift")
        #expect(history.contains("case .helperProofLost: \"Safety proof lost\""))
    }

    @Test func ownedPendingOrUnknownOutcomesRequireRecovery() {
        let armed = HelperReply(
            ok: false,
            status: status(armed: true, sleepDisabled: true)
        )
        let pending = HelperReply(
            ok: false,
            status: status(sleepDisabled: true, restorePending: true)
        )
        let unreadable = HelperReply(
            ok: false,
            status: status(
                sleepDisabled: false,
                sleepStateVerified: false,
                restorePending: false
            )
        )

        #expect(SleepOverrideSafety.failedArmDisposition(
            armed,
            independentlyObserved: true
        ) == .recoveryRequired)
        #expect(SleepOverrideSafety.failedArmDisposition(
            pending,
            independentlyObserved: true
        ) == .recoveryRequired)
        #expect(SleepOverrideSafety.failedArmDisposition(
            unreadable,
            independentlyObserved: nil
        ) == .recoveryRequired)
    }

    @Test func unknownFutureProtocolCannotProveArmRestoreOrOwnership() throws {
        let futureVersion = LidlessIDs.helperVersion + 1
        let futureArmed = HelperStatus(
            helperVersion: futureVersion,
            armed: true,
            sleepDisabled: true,
            sleepStateVerified: true,
            restorePending: false
        )
        let futureRestored = HelperStatus(
            helperVersion: futureVersion,
            armed: false,
            sleepDisabled: false,
            sleepStateVerified: true,
            restorePending: false
        )
        let futureExternal = HelperReply(
            ok: false,
            status: HelperStatus(
                helperVersion: futureVersion,
                armed: false,
                sleepDisabled: true,
                sleepStateVerified: true,
                restorePending: false
            )
        )

        #expect(!SleepOverrideSafety.isArmProven(futureArmed))
        #expect(!SleepOverrideSafety.isRestoreProven(futureRestored))
        #expect(SleepOverrideSafety.failedArmDisposition(
            futureExternal,
            independentlyObserved: true
        ) == .recoveryRequired)

        let client = try repositoryFile("App/Sources/Helper/HelperClient.swift")
        #expect(client.contains("installState = classifiedInstallState(for: status)"))
        #expect(client.contains("SleepOverrideSafety.isCurrentHelper(status)"))
        #expect(client.contains("guard epoch == installStateEpoch else { return }"))
        #expect(!client.contains("installState = status.helperVersion == LidlessIDs.helperVersion"))
        #expect(!client.contains("status.helperVersion >= LidlessIDs.helperVersion"))
    }

    @Test func appNeverRearmsAfterLosingHelperProof() throws {
        let app = try repositoryFile("App/Sources/AppState.swift")
        let interruption = try section(
            of: app,
            from: "private func helperInterrupted()",
            through: "private func resyncAfterWake()"
        )
        let heartbeat = try section(
            of: app,
            from: "private func startHeartbeat()",
            through: "private func stopHeartbeat()"
        )
        let stopHeartbeat = try section(
            of: app,
            from: "private func stopHeartbeat()",
            through: "// MARK: - Samples & drain"
        )
        let confirmArm = try section(
            of: app,
            from: "func confirmArm() async",
            through: "func disarm() async"
        )
        let helperRefresh = try section(
            of: app,
            from: "func refreshHelperState() async",
            through: "func openApprovalSettings()"
        )
        let systemRefresh = try section(
            of: app,
            from: "private func refreshSystemFlags()",
            through: "// MARK: - Cutoff evaluation"
        )

        #expect(!app.contains("rearmAfterHelperRestart"))
        #expect(occurrenceCount(
            of: "startTerminalRecoveryAfterHelperProofLoss",
            in: interruption
        ) == 2)
        #expect(interruption.contains("suppressCurrentScheduleOccurrence()"))
        #expect(occurrenceCount(
            of: "startTerminalRecoveryAfterHelperProofLoss",
            in: heartbeat
        ) == 2)
        #expect(app.contains("private var heartbeatGeneration = UUID()"))
        #expect(heartbeat.contains("let generation = heartbeatGeneration"))
        #expect(occurrenceCount(
            of: "self.heartbeatGeneration == generation",
            in: heartbeat
        ) == 3)
        let preDispatchFence = try #require(heartbeat.range(
            of: "self.heartbeatGeneration == generation"
        ))
        let heartbeatDispatch = try #require(heartbeat.range(of: "self.helper.heartbeat()"))
        #expect(preDispatchFence.lowerBound < heartbeatDispatch.lowerBound)
        #expect(stopHeartbeat.contains("heartbeatGeneration = UUID()"))
        #expect(!heartbeat.contains("next beat retries"))
        #expect(confirmArm.contains("SleepOverrideSafety.failedArmDisposition("))
        #expect(confirmArm.contains("let responseIsOwned = phase == .arming"))
        // Ownership decides whether the reply may *establish* an arm; it must
        // not decide whether the reply is admitted. A superseded reply is still
        // consumed by `failedArmDisposition`, so it crosses the demotion
        // boundary too — see `failedArmDispositionCannotConsumeAnUnadmittedReply`.
        #expect(!confirmArm.contains(
            "if responseIsOwned {\n"
                + "                retainRecoveryOnlyHelperStateIfNeeded(reply.status)\n"
                + "            }"
        ))
        #expect(confirmArm.contains(
            "guard responseIsOwned,\n                  helperState.isUsable,"
        ))
        #expect(confirmArm.contains("case .externalOverride:"))
        #expect(occurrenceCount(
            of: "suppressCurrentScheduleOccurrence()",
            in: confirmArm
        ) >= 3)
        #expect(occurrenceCount(
            of: "allowsUnownedExternalOverrideCompletion: true",
            in: confirmArm
        ) == 2)
        let disarm = try section(
            of: app,
            from: "func disarm() async",
            through: "func prepareForImmediateTermination()"
        )
        #expect(disarm.contains(
            "allowsUnownedExternalOverrideCompletion: currentSession == nil"
        ))
        let disarmSuppression = try #require(disarm.range(
            of: "suppressCurrentScheduleOccurrence()"
        ))
        let disarmRestore = try #require(disarm.range(
            of: "beginRestore(PendingRestore("
        ))
        #expect(disarmSuppression.lowerBound < disarmRestore.lowerBound)
        #expect(helperRefresh.contains(
            "if (phase == .armed || phase == .arming),\n           !helperState.isUsable"
        ))
        #expect(helperRefresh.contains("startTerminalRecoveryAfterHelperProofLoss"))
        #expect(occurrenceCount(
            of: "startTerminalRecoveryAfterHelperProofLoss",
            in: systemRefresh
        ) == 2)
        #expect(interruption.contains("allowsUnownedExternalOverrideCompletion: currentSession == nil"))
        #expect(interruption.contains("endReason: currentSession == nil ? nil : .helperProofLost"))
        #expect(app.contains("restoreGate.completeUnownedExternalOverride("))
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
        guard let startRange = source.range(of: start),
              let endRange = source.range(
                  of: end,
                  range: startRange.upperBound..<source.endIndex
              ) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return source[startRange.lowerBound..<endRange.upperBound]
    }

    private func occurrenceCount(
        of needle: String,
        in source: some StringProtocol
    ) -> Int {
        source.components(separatedBy: needle).count - 1
    }
}
