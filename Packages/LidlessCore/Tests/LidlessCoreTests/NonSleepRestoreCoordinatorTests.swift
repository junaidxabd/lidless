import Foundation
import Testing
@testable import LidlessCore

@Suite("Non-sleep restore coordinator safety")
struct NonSleepRestoreCoordinatorTests {
    private var restoredStatus: HelperStatus {
        HelperStatus(
            helperVersion: LidlessIDs.helperVersion,
            armed: false,
            sleepDisabled: false,
            sleepStateVerified: true,
            restorePending: false
        )
    }

    private var restoredReply: HelperReply {
        HelperReply(ok: true, status: restoredStatus)
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

    private func occurrenceCount(of needle: String, in source: String) -> Int {
        var count = 0
        var remainder = source[source.startIndex...]
        while let match = remainder.range(of: needle) {
            count += 1
            remainder = remainder[match.upperBound...]
        }
        return count
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

    @Test func combinedRestoreProofRequiresBothCompleteSources() {
        #expect(SleepOverrideSafety.isRestoreProven(
            restoredReply,
            independentlyObserved: false
        ))
        #expect(!SleepOverrideSafety.isRestoreProven(
            restoredReply,
            independentlyObserved: true
        ))
        #expect(!SleepOverrideSafety.isRestoreProven(
            restoredReply,
            independentlyObserved: nil
        ))

        let rejectedReply = HelperReply(ok: false, status: restoredStatus)
        #expect(!SleepOverrideSafety.isRestoreProven(
            rejectedReply,
            independentlyObserved: false
        ))

        let stillArmed = HelperStatus(
            helperVersion: LidlessIDs.helperVersion,
            armed: true,
            sleepDisabled: true,
            sleepStateVerified: true,
            restorePending: false
        )
        #expect(!SleepOverrideSafety.isRestoreProven(
            stillArmed,
            independentlyObserved: false
        ))

        let unverified = HelperStatus(
            helperVersion: LidlessIDs.helperVersion,
            armed: false,
            sleepDisabled: false,
            sleepStateVerified: false,
            restorePending: true
        )
        #expect(!SleepOverrideSafety.isRestoreProven(
            unverified,
            independentlyObserved: false
        ))
    }

    @Test func gateRejectsUnknownContradictoryAndInFlightArmEvidence() {
        var gate = NonSleepRestoreGate()
        let generation = gate.begin()

        #expect(gate.evaluateBaseProof(
            generation: generation,
            helperReply: restoredReply,
            independentlyObserved: nil,
            armRequestsInFlight: 0
        ) == .retry)
        #expect(gate.evaluateBaseProof(
            generation: generation,
            helperReply: restoredReply,
            independentlyObserved: true,
            armRequestsInFlight: 0
        ) == .retry)
        #expect(gate.evaluateBaseProof(
            generation: generation,
            helperReply: restoredReply,
            independentlyObserved: false,
            armRequestsInFlight: 1
        ) == .retry)
        #expect(gate.owns(generation))

        #expect(gate.evaluateBaseProof(
            generation: generation,
            helperReply: restoredReply,
            independentlyObserved: false,
            armRequestsInFlight: 0
        ) == .complete)
        #expect(!gate.owns(generation))
        #expect(gate.isCompleted(generation))
        let consumed = gate.consumeCompletion(generation)
        #expect(consumed)
        #expect(!gate.isCompleted(generation))
    }

    @Test func immediateQuitRejectsStaleCachedNormalPresentation() {
        #expect(NonSleepRestoreGate.allowsImmediateTermination(
            isDisarmed: true,
            hasActiveSession: false,
            hasPendingRestore: false,
            independentlyObserved: false,
            presentation: .verifiedNormal
        ))
        #expect(!NonSleepRestoreGate.allowsImmediateTermination(
            isDisarmed: true,
            hasActiveSession: false,
            hasPendingRestore: false,
            independentlyObserved: nil,
            presentation: .verifiedNormal
        ))
        #expect(!NonSleepRestoreGate.allowsImmediateTermination(
            isDisarmed: true,
            hasActiveSession: false,
            hasPendingRestore: false,
            independentlyObserved: true,
            presentation: .verifiedNormal
        ))
        #expect(!NonSleepRestoreGate.allowsImmediateTermination(
            isDisarmed: true,
            hasActiveSession: true,
            hasPendingRestore: false,
            independentlyObserved: false,
            presentation: .verifiedNormal
        ))
        #expect(!NonSleepRestoreGate.allowsImmediateTermination(
            isDisarmed: false,
            hasActiveSession: false,
            hasPendingRestore: false,
            independentlyObserved: false,
            presentation: .verifiedNormal
        ))
        #expect(!NonSleepRestoreGate.allowsImmediateTermination(
            isDisarmed: true,
            hasActiveSession: false,
            hasPendingRestore: false,
            independentlyObserved: false,
            presentation: .unknown
        ))
        #expect(!NonSleepRestoreGate.allowsImmediateTermination(
            isDisarmed: true,
            hasActiveSession: false,
            hasPendingRestore: true,
            independentlyObserved: false,
            presentation: .verifiedNormal
        ))
    }

    @Test func staleGenerationCannotConsumeOrCompleteItsReplacement() {
        var gate = NonSleepRestoreGate()
        let cancelled = gate.begin()
        gate.cancel(cancelled)
        let replacement = gate.begin()

        #expect(cancelled != replacement)
        #expect(gate.evaluateBaseProof(
            generation: cancelled,
            helperReply: restoredReply,
            independentlyObserved: false,
            armRequestsInFlight: 0
        ) == .ignore)
        #expect(gate.owns(replacement))
        #expect(!gate.isCompleted(cancelled))
    }

    @Test func repeatedBeginCannotChangeAnActiveGenerationsSemantics() {
        var gate = NonSleepRestoreGate()
        let original = gate.begin()
        let repeated = gate.begin(
            forceSleepRequested: true,
            requiresFinalProof: true
        )

        #expect(repeated == original)
        #expect(gate.evaluateBaseProof(
            generation: original,
            helperReply: restoredReply,
            independentlyObserved: false,
            armRequestsInFlight: 0
        ) == .complete)
    }

    @Test func forceSleepFollowUpCanBeDispatchedOnlyOnceAfterRestoreProof() {
        var gate = NonSleepRestoreGate()
        let generation = gate.begin(forceSleepRequested: true)

        #expect(gate.evaluateBaseProof(
            generation: generation,
            helperReply: restoredReply,
            independentlyObserved: false,
            armRequestsInFlight: 0
        ) == .dispatchForceSleep)

        // A negative or lost follow-up reply can only return to idempotent
        // base restoration. It must never authorize a second sleep request.
        #expect(gate.evaluateFollowUpProof(
            generation: generation,
            helperReply: HelperReply(ok: false, status: restoredStatus),
            independentlyObserved: false,
            armRequestsInFlight: 0
        ) == .retry)
        #expect(gate.evaluateBaseProof(
            generation: generation,
            helperReply: restoredReply,
            independentlyObserved: false,
            armRequestsInFlight: 0
        ) == .complete)

        let lostReplyGeneration = gate.begin(forceSleepRequested: true)
        #expect(gate.evaluateBaseProof(
            generation: lostReplyGeneration,
            helperReply: restoredReply,
            independentlyObserved: false,
            armRequestsInFlight: 0
        ) == .dispatchForceSleep)
        #expect(gate.evaluateBaseProof(
            generation: lostReplyGeneration,
            helperReply: restoredReply,
            independentlyObserved: false,
            armRequestsInFlight: 0
        ) == .complete)
    }

    @Test func quitCompletionNeedsASecondFreshProofAndStaysLatchedByGeneration() {
        var gate = NonSleepRestoreGate()
        let quit = gate.begin(requiresFinalProof: true)

        #expect(gate.evaluateBaseProof(
            generation: quit,
            helperReply: restoredReply,
            independentlyObserved: false,
            armRequestsInFlight: 0
        ) == .awaitFinalProof)
        #expect(gate.isAwaitingFinalProof(quit))
        #expect(!gate.isCompleted(quit))

        #expect(gate.evaluateFinalProof(
            generation: quit,
            helperReply: restoredReply,
            independentlyObserved: nil,
            armRequestsInFlight: 0
        ) == .retry)
        #expect(gate.owns(quit))
        #expect(!gate.isCompleted(quit))

        #expect(gate.evaluateBaseProof(
            generation: quit,
            helperReply: restoredReply,
            independentlyObserved: false,
            armRequestsInFlight: 0
        ) == .awaitFinalProof)
        #expect(gate.rejectFinalProof(quit) == .retry)
        #expect(gate.evaluateBaseProof(
            generation: quit,
            helperReply: restoredReply,
            independentlyObserved: false,
            armRequestsInFlight: 0
        ) == .awaitFinalProof)
        #expect(gate.evaluateFinalProof(
            generation: quit,
            helperReply: restoredReply,
            independentlyObserved: false,
            armRequestsInFlight: 0
        ) == .complete)

        let later = gate.begin()
        #expect(gate.isCompleted(quit))
        #expect(gate.owns(later))
        #expect(gate.evaluateBaseProof(
            generation: later,
            helperReply: restoredReply,
            independentlyObserved: false,
            armRequestsInFlight: 0
        ) == .complete)
        #expect(gate.isCompleted(later))
        let consumed = gate.consumeCompletion(quit)
        #expect(consumed)
        #expect(gate.isCompleted(later))
        #expect(!gate.isCompleted(quit))
    }

    @Test func cancelledQuitCannotFinalizeFromALateReply() {
        var gate = NonSleepRestoreGate()
        let quit = gate.begin(requiresFinalProof: true)
        #expect(gate.evaluateBaseProof(
            generation: quit,
            helperReply: restoredReply,
            independentlyObserved: false,
            armRequestsInFlight: 0
        ) == .awaitFinalProof)

        gate.cancel(quit)
        #expect(gate.evaluateFinalProof(
            generation: quit,
            helperReply: restoredReply,
            independentlyObserved: false,
            armRequestsInFlight: 0
        ) == .ignore)
        #expect(!gate.isCompleted(quit))
    }

    @Test func repairActuationCannotAcquireSessionOrUnownedCompletionSemantics() {
        #expect(NonSleepRestoreActuation.repairOverride.allowsConfiguration(
            forceSleepRequested: false,
            finalizesSession: false,
            allowsUnownedExternalOverrideCompletion: false
        ))

        let invalidRepairConfigurations: [(Bool, Bool, Bool)] = [
            (true, false, false),
            (false, true, false),
            (false, false, true),
            (true, true, false),
            (true, false, true),
            (false, true, true),
            (true, true, true)
        ]
        for (forceSleep, finalizesSession, unownedCompletion) in invalidRepairConfigurations {
            #expect(!NonSleepRestoreActuation.repairOverride.allowsConfiguration(
                forceSleepRequested: forceSleep,
                finalizesSession: finalizesSession,
                allowsUnownedExternalOverrideCompletion: unownedCompletion
            ))
        }

        #expect(NonSleepRestoreActuation.disarm.allowsConfiguration(
            forceSleepRequested: true,
            finalizesSession: true,
            allowsUnownedExternalOverrideCompletion: true
        ))
    }

    @Test func appUsesTheBehavioralGateAndTruthfulSleepRequestCopy() throws {
        let app = try repositoryFile("App/Sources/AppState.swift")
        let delegate = try repositoryFile("App/Sources/LidlessApp.swift")
        let beginArm = try section(
            of: app,
            from: "func beginArmFlow(",
            through: "func cancelArmFlow()"
        )
        let confirmArm = try section(
            of: app,
            from: "func confirmArm() async",
            through: "func disarm() async"
        )
        let uninstall = try section(
            of: app,
            from: "func uninstall() async",
            through: "// MARK: - Login item"
        )
        let schedule = try section(
            of: app,
            from: "private func scheduleAutomationTick()",
            through: "private func maintainScheduledWake()"
        )

        #expect(app.contains("private var restoreGate = NonSleepRestoreGate()"))
        #expect(app.contains("restoreGate.evaluateBaseProof("))
        #expect(app.contains("restoreGate.evaluateFollowUpProof("))
        #expect(app.contains("restoreGate.evaluateFinalProof("))
        #expect(app.contains("NonSleepRestoreGate.allowsImmediateTermination("))
        #expect(app.contains("return await waitForRestore(restoreID: restoreID)"))
        #expect(occurrenceCount(
            of: "startRestoreMonitor(delayFirstAttempt: true)",
            in: app
        ) == 2)
        #expect(beginArm.contains("guard !terminationPending"))
        #expect(confirmArm.contains("guard !terminationPending"))
        #expect(schedule.contains("guard !terminationPending"))
        #expect(uninstall.contains("guard phase == .disarmed, pendingRestore == nil else"))
        #expect(app.contains("? \"Sleep requested\" : \"Keep-awake ended\""))
        #expect(!app.contains("? \"Going to sleep\" : \"Keep-awake ended\""))
        #expect(app.contains("pending.notificationTitle = \"Keep-awake ended\""))
        #expect(app.contains("pending.playChime = false"))
        #expect(delegate.contains("Normal macOS sleep behavior will be restored before Lidless quits."))
        #expect(!delegate.contains("your Mac will go to sleep shortly after"))
        #expect(delegate.contains("guard let state = Self.stateProvider?() else {\n            return .terminateCancel"))
        #expect(delegate.contains("if state.phase == .arming"))
        #expect(delegate.contains("if state.phase == .disarming"))
        #expect(delegate.contains("return .terminateLater"))
        #expect(occurrenceCount(
            of: "NSApp.reply(toApplicationShouldTerminate: restored)",
            in: delegate
        ) == 1)
        let awaitedRestore = try #require(delegate.range(
            of: "let restored = await state.disarmForQuit()"
        ))
        let appKitReply = try #require(delegate.range(
            of: "NSApp.reply(toApplicationShouldTerminate: restored)"
        ))
        #expect(awaitedRestore.lowerBound < appKitReply.lowerBound)
    }

    @Test func outsideOverrideRepairUsesTheGenerationBoundRestoreWorker() throws {
        let app = try repositoryFile("App/Sources/AppState.swift")
        let pendingRestore = try section(
            of: app,
            from: "private struct PendingRestore",
            through: "private var pendingRestore: PendingRestore?"
        )
        let repair = try section(
            of: app,
            from: "func repairOverride() async",
            through: "func installHelper() async"
        )
        let monitor = try section(
            of: app,
            from: "private func runRestoreMonitor(",
            through: "private func dispatchForceSleepFollowUp("
        )
        let sleepTransition = try section(
            of: app,
            from: "private func recordSleepTransition()",
            through: "private func trackedArm("
        )
        let transitionRestore = try section(
            of: app,
            from: "private func restoreAfterSleepTransition()",
            through: "var effectiveConfig: CutoffConfig"
        )

        #expect(pendingRestore.contains("var actuation: NonSleepRestoreActuation"))
        #expect(app.contains("pending.actuation.allowsConfiguration("))
        #expect(app.contains("pending.options.forceSleep || pending.forceSleepFollowUp != nil"))
        #expect(repair.contains("actuation: .repairOverride"))
        #expect(repair.contains("sleepPresentation == .outsideOverride"))
        #expect(repair.contains("phase == .disarmed"))
        #expect(repair.contains("currentSession == nil"))
        #expect(repair.contains("pendingArm == nil"))
        #expect(repair.contains("pendingRestore == nil"))
        #expect(repair.contains("armRequestsInFlight == 0"))
        #expect(repair.contains("!uninstallInProgress"))
        #expect(repair.contains("helperState.isUsable"))
        #expect(repair.contains("refreshedSleepOverride() == true"))
        #expect(repair.contains("forceSleepFollowUp: nil"))
        #expect(repair.contains("allowsUnownedExternalOverrideCompletion: false"))
        #expect(!repair.contains("lastError = nil"))
        #expect(!repair.contains("let reply = try await helper.repairOverride()"))
        #expect(monitor.contains("switch pending.actuation"))
        #expect(monitor.contains("case .repairOverride:"))
        #expect(monitor.contains("reply = try await helper.repairOverride()"))
        #expect(monitor.contains("restoreGate.evaluateBaseProof("))
        #expect(app.contains("guard case .disarm = pending.actuation else"))
        #expect(sleepTransition.contains("sleepTerminationActuation = pendingRestore?.actuation ?? .disarm"))
        let sleepActuationSnapshot = try #require(sleepTransition.range(
            of: "sleepTerminationActuation = pendingRestore?.actuation ?? .disarm"
        ))
        let pendingRestoreCancellation = try #require(sleepTransition.range(
            of: "cancelPendingRestoreForSleepTransition()"
        ))
        #expect(sleepActuationSnapshot.lowerBound < pendingRestoreCancellation.lowerBound)
        #expect(sleepTransition.contains(
            "if sleepTerminationGeneration == nil {\n"
                + "                sleepTerminationGeneration = sleepGeneration\n"
                + "                sleepTerminationActuation = pendingRestore?.actuation ?? .disarm\n"
                + "            }\n"
                + "            cancelPendingRestoreForSleepTransition()"
        ))
        #expect(transitionRestore.contains("switch terminalActuation"))
        #expect(transitionRestore.contains("case .repairOverride:"))
        #expect(transitionRestore.contains("reply = try await helper.repairOverride()"))
        let transitionRepairCall = try #require(transitionRestore.range(
            of: "reply = try await helper.repairOverride()"
        ))
        let postAwaitGenerationFence = try #require(transitionRestore.range(
            of: "guard terminalGeneration == sleepTerminationGeneration else { continue }"
        ))
        #expect(transitionRepairCall.lowerBound < postAwaitGenerationFence.lowerBound)
        #expect(transitionRestore.contains(
            "sleepTerminationGeneration = nil\n"
                + "                    sleepTerminationActuation = nil"
        ))
        #expect(app.contains("uninstallInProgress = true"))
        #expect(app.contains("defer { uninstallInProgress = false }"))
    }
}
