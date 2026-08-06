import Foundation
import Testing
@testable import LidlessCore

@Suite("Arm intent confirmation safety")
struct ArmIntentConfirmationTests {
    @Test func onlyTheExactCurrentIntentMayBeConfirmed() {
        let current = UUID(uuidString: "3DEED988-2F01-4899-96CB-3756384D9D59")!
        let replaced = UUID(uuidString: "0352D33F-F6FD-4B8B-B14D-63FDF3E8C87B")!
        let confirmedPlan = ArmIntentPlan(
            cutoffs: CutoffConfig(),
            helperOptions: HelperArmOptions(lowPowerMode: true)
        )
        var changedCutoffs = CutoffConfig()
        changedCutoffs.batteryFloorEnabled = false
        let changedPlan = ArmIntentPlan(
            cutoffs: changedCutoffs,
            helperOptions: HelperArmOptions(lowPowerMode: true)
        )
        let changedOptions = ArmIntentPlan(
            cutoffs: CutoffConfig(),
            helperOptions: HelperArmOptions(
                lowPowerMode: true,
                tcpKeepAlive: true
            )
        )
        let scheduled = ScheduleEngine.Occurrence(
            windowID: current,
            start: Date(timeIntervalSince1970: 1_000),
            end: Date(timeIntervalSince1970: 2_000)
        )
        let scheduledPlan = ArmIntentPlan(
            cutoffs: CutoffConfig(),
            helperOptions: HelperArmOptions(lowPowerMode: true),
            scheduledOccurrence: scheduled
        )
        let editedSchedulePlan = ArmIntentPlan(
            cutoffs: CutoffConfig(),
            helperOptions: HelperArmOptions(lowPowerMode: true),
            scheduledOccurrence: ScheduleEngine.Occurrence(
                windowID: current,
                start: scheduled.start,
                end: scheduled.end.addingTimeInterval(60)
            )
        )

        #expect(ArmIntentConfirmationSafety.authorizes(
            expectedIntentID: current,
            currentIntentID: current,
            confirmedPlan: confirmedPlan,
            currentPlan: confirmedPlan
        ))
        #expect(!ArmIntentConfirmationSafety.authorizes(
            expectedIntentID: replaced,
            currentIntentID: current,
            confirmedPlan: confirmedPlan,
            currentPlan: confirmedPlan
        ))
        #expect(!ArmIntentConfirmationSafety.authorizes(
            expectedIntentID: current,
            currentIntentID: current,
            confirmedPlan: confirmedPlan,
            currentPlan: changedPlan
        ))
        #expect(!ArmIntentConfirmationSafety.authorizes(
            expectedIntentID: current,
            currentIntentID: current,
            confirmedPlan: confirmedPlan,
            currentPlan: changedOptions
        ))
        #expect(!ArmIntentConfirmationSafety.authorizes(
            expectedIntentID: current,
            currentIntentID: current,
            confirmedPlan: scheduledPlan,
            currentPlan: confirmedPlan
        ))
        #expect(!ArmIntentConfirmationSafety.authorizes(
            expectedIntentID: current,
            currentIntentID: current,
            confirmedPlan: scheduledPlan,
            currentPlan: editedSchedulePlan
        ))
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
              )
        else {
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

    @Test func everyConfirmationIsBoundToTheIntentThatRequestedIt() throws {
        let app = try repositoryFile("App/Sources/AppState.swift")
        let panel = try repositoryFile(
            "App/Sources/UI/MenuBar/MenuPanelView.swift"
        )
        let overview = try repositoryFile(
            "App/Sources/UI/Main/OverviewPane.swift"
        )
        let begin = try section(
            of: app,
            from: "func beginArmFlow(preset: ArmPreset? = nil)",
            through: "func cancelArmFlow()"
        )
        let pendingProjection = try section(
            of: app,
            from: "func refreshPendingProjection()",
            through: "private func projection("
        )
        let confirmation = try section(
            of: app,
            from: "func confirmArm() async",
            through: "func disarm() async"
        )
        #expect(app.contains("var id: UUID"))
        #expect(app.contains("func confirmArm(expectedIntentID: UUID) async"))
        #expect(occurrenceCount(
            of: "Task { await confirmArm(expectedIntentID: pending.id) }",
            in: app
        ) == 2)
        #expect(!app.contains("Task { await confirmArm() }"))
        #expect(pendingProjection.contains(
            "id: retainsConfirmation ? pending.id : UUID()"
        ))
        #expect(confirmation.contains("ArmIntentConfirmationSafety.authorizes("))
        #expect(confirmation.contains("currentIntentID: intent.id"))
        #expect(confirmation.contains("pending.id == intent.id"))
        #expect(panel.contains(
            "state.confirmArm(expectedIntentID: pending.id)"
        ))
        #expect(begin.contains("pendingArm == nil"))
        #expect(overview.contains("|| state.pendingArm != nil"))
    }

    @Test func confirmationCannotDriftToAChangedSafetyPlan() throws {
        let app = try repositoryFile("App/Sources/AppState.swift")
        let pendingProjection = try section(
            of: app,
            from: "func refreshPendingProjection()",
            through: "private func projection("
        )
        let confirmation = try section(
            of: app,
            from: "func confirmArm() async",
            through: "func disarm() async"
        )
        let storesPlan = app.contains("var plan: ArmIntentPlan")
        let refreshesPlan = pendingProjection.contains(
            "let currentPlan = currentArmIntentPlan("
        )
        let invalidatesChangedConsent = pendingProjection.contains(
            "pending.plan == currentPlan\n            && pending.assessment == assessment"
        )
        let checksConfirmedPlan = confirmation.contains("confirmedPlan: intent.plan")
            && confirmation.contains("currentPlan: currentArmIntentPlan(for: intent)")
        let assessesConfirmedCutoffs = occurrenceCount(
            of: "config: pending.plan.cutoffs",
            in: confirmation
        ) == 2
        let dispatchesConfirmedOptions = confirmation.contains(
            "let options = pending.plan.helperOptions"
        )
        let summarizesConfirmedCutoffs = confirmation.contains(
            "let cfg = pending.plan.cutoffs"
        )
        let restoresOnPostDispatchDrift = confirmation.contains(
            "pending.plan == currentArmIntentPlan(for: pending)"
        )

        #expect(storesPlan)
        #expect(refreshesPlan)
        #expect(invalidatesChangedConsent)
        #expect(checksConfirmedPlan)
        #expect(assessesConfirmedCutoffs)
        #expect(dispatchesConfirmedOptions)
        #expect(summarizesConfirmedCutoffs)
        #expect(restoresOnPostDispatchDrift)
    }

    @Test func scheduledConfirmationRequiresTheExactLiveOccurrence() throws {
        let core = try repositoryFile(
            "Packages/LidlessCore/Sources/LidlessCore/ArmIntentConfirmationSafety.swift"
        )
        let app = try repositoryFile("App/Sources/AppState.swift")
        let cancellation = try section(
            of: app,
            from: "func cancelArmFlow()",
            through: "func refreshPendingProjection()"
        )
        let confirmation = try section(
            of: app,
            from: "func confirmArm() async",
            through: "func disarm() async"
        )
        let evaluation = try section(
            of: app,
            from: "private func evaluateCutoffs()",
            through: "private func emitPreCutoffWarnings()"
        )
        let automation = try section(
            of: app,
            from: "private func scheduleAutomationTick()",
            through: "private func maintainScheduledWake()"
        )

        #expect(core.contains(
            "public var scheduledOccurrence: ScheduleEngine.Occurrence?"
        ))
        #expect(automation.contains("scheduledOccurrence: active"))
        #expect(confirmation.contains("currentArmIntentPlan(for: intent)"))
        #expect(confirmation.contains("currentArmIntentPlan(for: pending)"))
        #expect(app.contains(
            "if case .schedule = pending.source,\n           !retainsConfirmation {"
        ))
        #expect(cancellation.contains(
            "suppressedOccurrence = pending.plan.scheduledOccurrence"
        ))
        #expect(cancellation.contains("scheduleOccurrence = nil"))
        #expect(evaluation.contains(
            "if !config.scheduleAutomationEnabled {\n                fired.append(.scheduleEnded)"
        ))

        let preflight = try #require(confirmation.range(
            of: "currentPlan: currentArmIntentPlan(for: intent)"
        ))
        let dispatch = try #require(confirmation.range(of: "try await trackedArm(options)"))
        let postflight = try #require(confirmation.range(
            of: "pending.plan == currentArmIntentPlan(for: pending)"
        ))
        let commit = try #require(confirmation.range(of: "currentSession = session"))
        #expect(preflight.upperBound < dispatch.lowerBound)
        #expect(dispatch.upperBound < postflight.lowerBound)
        #expect(postflight.upperBound < commit.lowerBound)
    }
}
