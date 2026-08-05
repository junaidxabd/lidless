import Foundation
import Testing
@testable import LidlessCore

@Suite("App-local helper removal admission")
struct HelperRemovalAppSafetyTests {
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

    @Test func removalStartsOnlyOutsideCompetingAppOperations() {
        #expect(HelperRemovalAppSafety.canStartRemoval(
            isSimulation: false,
            removalInProgress: false,
            terminationPending: false,
            helperLifecycleOperationsInFlight: 0
        ))

        let rejected: [(Bool, Bool, Bool, Int)] = [
            (true, false, false, 0),
            (false, true, false, 0),
            (false, false, true, 0),
            (false, false, false, 1),
            (false, false, false, -1)
        ]
        for (simulation, removal, termination, lifecycleCount) in rejected {
            #expect(!HelperRemovalAppSafety.canStartRemoval(
                isSimulation: simulation,
                removalInProgress: removal,
                terminationPending: termination,
                helperLifecycleOperationsInFlight: lifecycleCount
            ))
        }
    }

    @Test func removalProceedsOnlyAfterAppStateIsQuiescent() {
        #expect(HelperRemovalAppSafety.canProceedRemoval(
            isDisarmed: true,
            hasCurrentSession: false,
            hasPendingArm: false,
            hasPendingRestore: false,
            armRequestsInFlight: 0,
            sleepTerminationInProgress: false
        ))

        let rejected: [(Bool, Bool, Bool, Bool, Int, Bool)] = [
            (false, false, false, false, 0, false),
            (true, true, false, false, 0, false),
            (true, false, true, false, 0, false),
            (true, false, false, true, 0, false),
            (true, false, false, false, 1, false),
            (true, false, false, false, -1, false),
            (true, false, false, false, 0, true)
        ]
        for (disarmed, session, arm, restore, armCount, sleepTransition) in rejected {
            #expect(!HelperRemovalAppSafety.canProceedRemoval(
                isDisarmed: disarmed,
                hasCurrentSession: session,
                hasPendingArm: arm,
                hasPendingRestore: restore,
                armRequestsInFlight: armCount,
                sleepTerminationInProgress: sleepTransition
            ))
        }
    }

    @Test func appWiringMakesAdmissionAndLifecycleIntervalsMutuallyExclusive() throws {
        let app = try repositoryFile("App/Sources/AppState.swift")
        let lifecycleRefresh = try section(
            of: app,
            from: "private func refreshHelperInstallState()",
            through: "private func recordSleepTransition()"
        )
        let start = try section(
            of: app,
            from: "func start()",
            through: "// MARK: - Derived state for UI"
        )
        let confirmArm = try section(
            of: app,
            from: "func confirmArm() async",
            through: "func disarm() async"
        )
        let install = try section(
            of: app,
            from: "func installHelper() async",
            through: "func refreshHelperState() async"
        )
        let publicRefresh = try section(
            of: app,
            from: "func refreshHelperState() async",
            through: "func openApprovalSettings()"
        )
        let uninstall = try section(
            of: app,
            from: "func uninstall() async",
            through: "// MARK: - Login item"
        )

        let refreshFence = try #require(lifecycleRefresh.range(
            of: "guard !uninstallInProgress else { return false }"
        ))
        let refreshBegin = try #require(lifecycleRefresh.range(
            of: "beginHelperLifecycleOperation()"
        ))
        #expect(refreshFence.lowerBound < refreshBegin.lowerBound)
        #expect(lifecycleRefresh.contains("private func refreshHelperInstallState() async -> Bool"))
        #expect(lifecycleRefresh.contains("return true"))
        #expect(start.contains("guard await refreshHelperInstallState() else { return }"))

        let confirmationRefresh = try #require(confirmArm.range(
            of: "guard await refreshHelperInstallState() else"
        ))
        let armDispatch = try #require(confirmArm.range(
            of: "let reply = try await trackedArm(options)"
        ))
        #expect(confirmationRefresh.lowerBound < armDispatch.lowerBound)
        #expect(confirmArm.contains(
            "Couldn't arm because helper removal began during verification."
        ))

        let installFence = try #require(install.range(of: "guard !uninstallInProgress"))
        let installBegin = try #require(install.range(of: "beginHelperLifecycleOperation()"))
        #expect(installFence.lowerBound < installBegin.lowerBound)
        #expect(publicRefresh.contains("guard await refreshHelperInstallState() else { return }"))

        let admission = try #require(uninstall.range(
            of: "HelperRemovalAppSafety.canStartRemoval("
        ))
        let latch = try #require(uninstall.range(of: "uninstallInProgress = true"))
        let lifecycleBegin = try #require(uninstall.range(of: "beginHelperLifecycleOperation()"))
        let wakeInvalidation = try #require(uninstall.range(
            of: "scheduledWakeReconciliation.invalidate()"
        ))
        let disarm = try #require(uninstall.range(of: "await disarm()"))
        let quiescence = try #require(uninstall.range(
            of: "HelperRemovalAppSafety.canProceedRemoval("
        ))
        #expect(admission.lowerBound < latch.lowerBound)
        #expect(latch.lowerBound < lifecycleBegin.lowerBound)
        #expect(lifecycleBegin.lowerBound < wakeInvalidation.lowerBound)
        #expect(wakeInvalidation.lowerBound < disarm.lowerBound)
        #expect(disarm.lowerBound < quiescence.lowerBound)
        #expect(!uninstall[..<latch.lowerBound].contains("await "))
        #expect(uninstall.contains("endHelperLifecycleOperation()"))
        #expect(uninstall.contains("uninstallInProgress = false"))
        #expect(uninstall.contains("if phase == .armed || phase == .arming"))
        #expect(uninstall.contains("isSimulation: isSimulation"))
        #expect(uninstall.contains("removalInProgress: uninstallInProgress"))
        #expect(uninstall.contains("terminationPending: terminationPending"))
        #expect(uninstall.contains(
            "helperLifecycleOperationsInFlight: helperLifecycleOperationsInFlight"
        ))
        #expect(uninstall.contains("isDisarmed: phase == .disarmed"))
        #expect(uninstall.contains("hasCurrentSession: currentSession != nil"))
        #expect(uninstall.contains("hasPendingArm: pendingArm != nil"))
        #expect(uninstall.contains("hasPendingRestore: pendingRestore != nil"))
        #expect(uninstall.contains("armRequestsInFlight: armRequestsInFlight"))
        #expect(uninstall.contains(
            "sleepTerminationInProgress: sleepTerminationGeneration != nil"
        ))
    }

    @Test func removalLatchRejectsNewArmWakeRepairAndTerminationEntry() throws {
        let app = try repositoryFile("App/Sources/AppState.swift")
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
        let immediateTermination = try section(
            of: app,
            from: "func prepareForImmediateTermination()",
            through: "func disarmForQuit() async"
        )
        let quitRestore = try section(
            of: app,
            from: "func disarmForQuit() async",
            through: "private func fireCutoff("
        )
        let repair = try section(
            of: app,
            from: "func repairOverride() async",
            through: "func installHelper() async"
        )
        let schedule = try section(
            of: app,
            from: "private func scheduleAutomationTick()",
            through: "private func maintainScheduledWake()"
        )
        let wake = try section(
            of: app,
            from: "private func maintainScheduledWake()",
            through: "// MARK: - Heartbeat"
        )

        #expect(beginArm.contains("!uninstallInProgress"))
        #expect(confirmArm.contains("!uninstallInProgress"))
        #expect(immediateTermination.contains("guard !uninstallInProgress"))
        #expect(quitRestore.contains("guard !uninstallInProgress"))
        #expect(repair.contains("!uninstallInProgress"))
        #expect(schedule.contains("!uninstallInProgress"))
        #expect(wake.contains("!uninstallInProgress"))
    }
}
