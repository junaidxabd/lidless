import Foundation
import Testing
@testable import LidlessCore

@Suite("Launch reconciliation safety")
struct LaunchReconciliationTests {
    private var quiescent: LaunchReconciliationSafety.Context {
        LaunchReconciliationSafety.Context(
            isDisarmed: true,
            hasCurrentSession: false,
            hasQueuedArmIntent: false,
            hasPendingRestore: false,
            armRequestsInFlight: 0,
            terminationPending: false,
            helperRegistrationInProgress: false,
            sleepTerminationInProgress: false,
            helperReachable: true,
            helperProofEpoch: 11,
            helperLifecycleEpoch: 12,
            helperLifecycleOperationsInFlight: 0,
            sleepGeneration: 22
        )
    }

    private func status(
        version: Int = LidlessIDs.helperVersion,
        armed: Bool = false,
        restorePending: Bool? = false
    ) -> HelperStatus {
        HelperStatus(
            helperVersion: version,
            armed: armed,
            sleepDisabled: armed,
            sleepStateVerified: true,
            restorePending: restorePending
        )
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

    @Test func queryBeginsOnlyFromAReachableQuiescentContext() {
        #expect(LaunchReconciliationSafety.canQuery(quiescent))

        var invalid = quiescent
        invalid.helperReachable = false
        #expect(!LaunchReconciliationSafety.canQuery(invalid))

        invalid = quiescent
        invalid.hasCurrentSession = true
        #expect(!LaunchReconciliationSafety.canQuery(invalid))

        invalid = quiescent
        invalid.helperLifecycleOperationsInFlight = 1
        #expect(!LaunchReconciliationSafety.canQuery(invalid))

        invalid = quiescent
        invalid.terminationPending = true
        #expect(!LaunchReconciliationSafety.canQuery(invalid))
    }

    @Test func onlyAStableQuiescentReplyCanStartLaunchRecovery() {
        #expect(LaunchReconciliationSafety.decide(
            initial: quiescent,
            current: quiescent,
            helperStateUnchanged: true,
            status: status(armed: true)
        ) == .restore(cancelQueuedArmIntent: false))
        #expect(LaunchReconciliationSafety.decide(
            initial: quiescent,
            current: quiescent,
            helperStateUnchanged: true,
            status: status(restorePending: true)
        ) == .restore(cancelQueuedArmIntent: false))
        #expect(LaunchReconciliationSafety.decide(
            initial: quiescent,
            current: quiescent,
            helperStateUnchanged: true,
            status: status()
        ) == .none)
        #expect(LaunchReconciliationSafety.decide(
            initial: quiescent,
            current: quiescent,
            helperStateUnchanged: true,
            status: status(restorePending: nil)
        ) == .none)
    }

    @Test func differentWireResponderCannotStartAutomaticLaunchRecovery() {
        for version in [
            LidlessIDs.helperVersion - 1,
            LidlessIDs.helperVersion + 1,
        ] {
            #expect(LaunchReconciliationSafety.decide(
                initial: quiescent,
                current: quiescent,
                helperStateUnchanged: true,
                status: status(version: version, armed: true)
            ) == .abandon)
            #expect(LaunchReconciliationSafety.decide(
                initial: quiescent,
                current: quiescent,
                helperStateUnchanged: true,
                status: status(version: version, restorePending: true)
            ) == .abandon)
        }
    }

    @Test func aLateReplyCannotCrossANewSessionArmOrLifecycleGeneration() {
        #expect(LaunchReconciliationSafety.responseBelongsToContext(
            initial: quiescent,
            current: quiescent,
            helperStateUnchanged: true
        ))

        var changed = quiescent
        changed.isDisarmed = false
        changed.hasCurrentSession = true
        #expect(!LaunchReconciliationSafety.responseBelongsToContext(
            initial: quiescent,
            current: changed,
            helperStateUnchanged: true
        ))
        #expect(LaunchReconciliationSafety.decide(
            initial: quiescent,
            current: changed,
            helperStateUnchanged: true,
            status: status(armed: true)
        ) == .abandon)

        changed = quiescent
        changed.armRequestsInFlight = 1
        #expect(LaunchReconciliationSafety.decide(
            initial: quiescent,
            current: changed,
            helperStateUnchanged: true,
            status: status(armed: true)
        ) == .abandon)

        changed = quiescent
        changed.helperProofEpoch &+= 1
        #expect(LaunchReconciliationSafety.decide(
            initial: quiescent,
            current: changed,
            helperStateUnchanged: true,
            status: status(armed: true)
        ) == .abandon)

        changed = quiescent
        changed.helperLifecycleEpoch &+= 1
        #expect(!LaunchReconciliationSafety.responseBelongsToContext(
            initial: quiescent,
            current: changed,
            helperStateUnchanged: true
        ))
        #expect(LaunchReconciliationSafety.decide(
            initial: quiescent,
            current: changed,
            helperStateUnchanged: true,
            status: status(armed: true)
        ) == .abandon)

        changed = quiescent
        changed.helperLifecycleOperationsInFlight = 1
        #expect(LaunchReconciliationSafety.decide(
            initial: quiescent,
            current: changed,
            helperStateUnchanged: true,
            status: status(armed: true)
        ) == .abandon)

        changed = quiescent
        changed.sleepGeneration &+= 1
        #expect(LaunchReconciliationSafety.decide(
            initial: quiescent,
            current: changed,
            helperStateUnchanged: true,
            status: status(armed: true)
        ) == .abandon)

        #expect(LaunchReconciliationSafety.decide(
            initial: quiescent,
            current: quiescent,
            helperStateUnchanged: false,
            status: status(armed: true)
        ) == .abandon)
        #expect(!LaunchReconciliationSafety.responseBelongsToContext(
            initial: quiescent,
            current: quiescent,
            helperStateUnchanged: false
        ))
    }

    @Test func terminationRegistrationSleepAndPendingRecoveryFailClosed() {
        var changed = quiescent
        changed.terminationPending = true
        #expect(LaunchReconciliationSafety.decide(
            initial: quiescent,
            current: changed,
            helperStateUnchanged: true,
            status: status(armed: true)
        ) == .abandon)

        changed = quiescent
        changed.helperRegistrationInProgress = true
        #expect(LaunchReconciliationSafety.decide(
            initial: quiescent,
            current: changed,
            helperStateUnchanged: true,
            status: status(armed: true)
        ) == .abandon)

        changed = quiescent
        changed.sleepTerminationInProgress = true
        #expect(LaunchReconciliationSafety.decide(
            initial: quiescent,
            current: changed,
            helperStateUnchanged: true,
            status: status(armed: true)
        ) == .abandon)

        changed = quiescent
        changed.hasPendingRestore = true
        #expect(LaunchReconciliationSafety.decide(
            initial: quiescent,
            current: changed,
            helperStateUnchanged: true,
            status: status(armed: true)
        ) == .abandon)
    }

    @Test func affirmativeRecoveryEvidenceCancelsOnlyAQueuedUnmutatedIntent() {
        var current = quiescent
        current.hasQueuedArmIntent = true
        #expect(LaunchReconciliationSafety.decide(
            initial: quiescent,
            current: current,
            helperStateUnchanged: true,
            status: status(armed: true)
        ) == .restore(cancelQueuedArmIntent: true))
        #expect(LaunchReconciliationSafety.decide(
            initial: quiescent,
            current: current,
            helperStateUnchanged: true,
            status: status()
        ) == .abandon)

        var initial = quiescent
        initial.hasQueuedArmIntent = true
        #expect(LaunchReconciliationSafety.decide(
            initial: initial,
            current: current,
            helperStateUnchanged: true,
            status: status()
        ) == .none)
    }

    @Test func appWiresTheGateBeforeCoordinatorDispatchAndReturnsEarly() throws {
        let app = try repositoryFile("App/Sources/AppState.swift")
        let contextStart = try #require(app.range(of: "private func launchReconciliationContext()"))
        let start = try #require(app.range(of: "private func reconcileWithHelper() async"))
        let end = try #require(app.range(
            of: "private func startTickLoop()",
            range: start.upperBound..<app.endIndex
        ))
        let context = app[contextStart.lowerBound..<start.lowerBound]
        let reconciliation = app[start.lowerBound..<end.lowerBound]

        #expect(context.contains("hasCurrentSession: currentSession != nil"))
        #expect(context.contains("hasQueuedArmIntent: pendingArm != nil || scheduleOccurrence != nil"))
        #expect(context.contains("hasPendingRestore: pendingRestore != nil"))
        #expect(context.contains("armRequestsInFlight: armRequestsInFlight"))
        #expect(context.contains("terminationPending: terminationPending"))
        #expect(context.contains(
            "helperRegistrationInProgress: helperRegistrationInProgress"
        ))
        #expect(context.contains("sleepTerminationInProgress: sleepTerminationGeneration != nil"))
        #expect(context.contains("helperReachable: helperState.isRecoveryUsable"))
        #expect(!context.contains("helperReachable: helperState.isReachable"))
        #expect(context.contains("helperProofEpoch: helperProofEpoch"))
        #expect(context.contains("helperLifecycleEpoch: helperLifecycleEpoch"))
        #expect(context.contains("helperLifecycleOperationsInFlight: helperLifecycleOperationsInFlight"))
        #expect(context.contains("sleepGeneration: sleepGeneration"))

        #expect(reconciliation.contains("let initial = launchReconciliationContext()"))
        #expect(reconciliation.contains("let initialHelperState = helperState"))
        #expect(reconciliation.contains("LaunchReconciliationSafety.canQuery(initial)"))
        #expect(reconciliation.contains("guard !launchReconciliationInFlight else"))
        #expect(reconciliation.contains("launchReconciliationInFlight = true"))
        #expect(reconciliation.contains("defer { launchReconciliationInFlight = false }"))
        #expect(reconciliation.contains("let current = launchReconciliationContext()"))
        #expect(reconciliation.contains("let helperStateUnchanged = helperState == initialHelperState"))
        #expect(reconciliation.contains("LaunchReconciliationSafety.responseBelongsToContext("))
        #expect(reconciliation.contains("retainRecoveryOnlyHelperStateIfNeeded(status)"))
        #expect(reconciliation.contains("let decision = LaunchReconciliationSafety.decide("))
        #expect(reconciliation.contains("LaunchReconciliationSafety.decide("))
        #expect(reconciliation.contains("current: current"))
        #expect(reconciliation.contains("helperStateUnchanged: helperStateUnchanged"))
        #expect(reconciliation.contains("switch decision"))
        #expect(reconciliation.contains("case .abandon:\n            return"))
        #expect(reconciliation.contains("case .restore(let cancelQueuedArmIntent):"))
        #expect(reconciliation.contains("if cancelQueuedArmIntent"))
        #expect(reconciliation.contains("pendingArm = nil"))
        #expect(reconciliation.contains("suppressCurrentScheduleOccurrence()"))
        #expect(reconciliation.contains("guard beginRestore(PendingRestore("))
        #expect(reconciliation.contains(
            "reason: \"unfinished helper recovery found at app launch\""
        ))
        #expect(!reconciliation.contains("try? await helper.disarm("))

        let initialCapture = try #require(reconciliation.range(
            of: "let initial = launchReconciliationContext()"
        ))
        let statusRead = try #require(reconciliation.range(of: "await helper.status()"))
        let launchExclusion = try #require(reconciliation.range(
            of: "launchReconciliationInFlight = true"
        ))
        let launchExclusionRelease = try #require(reconciliation.range(
            of: "defer { launchReconciliationInFlight = false }"
        ))
        let responseFence = try #require(reconciliation.range(
            of: "LaunchReconciliationSafety.responseBelongsToContext("
        ))
        let wakeAdmission = try #require(reconciliation.range(
            of: "retainRecoveryOnlyHelperStateIfNeeded(status)"
        ))
        let postAwaitDecision = try #require(reconciliation.range(
            of: "let decision = LaunchReconciliationSafety.decide("
        ))
        let decisionSwitch = try #require(reconciliation.range(
            of: "switch decision"
        ))
        let coordinatedRestore = try #require(reconciliation.range(
            of: "guard beginRestore(PendingRestore("
        ))
        let queuedIntentCancellation = try #require(reconciliation.range(
            of: "suppressCurrentScheduleOccurrence()"
        ))
        let restorePublish = try #require(reconciliation.range(
            of: "publishWidget()",
            range: coordinatedRestore.upperBound..<reconciliation.endIndex
        ))
        let restoreReturn = try #require(reconciliation.range(
            of: "return",
            range: restorePublish.upperBound..<reconciliation.endIndex
        ))
        let wakeMaintenance = try #require(reconciliation.range(
            of: "maintainScheduledWake()",
            range: restoreReturn.upperBound..<reconciliation.endIndex
        ))
        #expect(initialCapture.lowerBound < statusRead.lowerBound)
        #expect(launchExclusion.lowerBound < launchExclusionRelease.lowerBound)
        #expect(launchExclusionRelease.lowerBound < statusRead.lowerBound)
        #expect(statusRead.lowerBound < responseFence.lowerBound)
        #expect(responseFence.lowerBound < wakeAdmission.lowerBound)
        #expect(wakeAdmission.lowerBound < postAwaitDecision.lowerBound)
        #expect(postAwaitDecision.lowerBound < decisionSwitch.lowerBound)
        #expect(statusRead.lowerBound < postAwaitDecision.lowerBound)
        #expect(queuedIntentCancellation.lowerBound < coordinatedRestore.lowerBound)
        #expect(postAwaitDecision.lowerBound < coordinatedRestore.lowerBound)
        #expect(coordinatedRestore.lowerBound < restoreReturn.lowerBound)
        #expect(restoreReturn.lowerBound < wakeMaintenance.lowerBound)

        let installStart = try #require(app.range(of: "func installHelper() async"))
        let uninstallStart = try #require(app.range(
            of: "func uninstall() async -> String?",
            range: installStart.upperBound..<app.endIndex
        ))
        let loginItem = try #require(app.range(
            of: "// MARK: - Login item",
            range: uninstallStart.upperBound..<app.endIndex
        ))
        let install = app[installStart.lowerBound..<uninstallStart.lowerBound]
        let uninstall = app[uninstallStart.lowerBound..<loginItem.lowerBound]
        let installBegin = try #require(install.range(of: "beginHelperLifecycleOperation()"))
        let installEnd = try #require(install.range(of: "endHelperLifecycleOperation()"))
        let installAwait = try #require(install.range(of: "try await helper.install()"))
        #expect(installBegin.lowerBound < installEnd.lowerBound)
        #expect(installEnd.lowerBound < installAwait.lowerBound)
        #expect(uninstall.contains("Automatic helper cleanup is disabled"))
        #expect(uninstall.contains("No state was changed"))
        #expect(!uninstall.contains("beginHelperLifecycleOperation()"))
        #expect(!uninstall.contains("await"))

        #expect(app.contains("private func refreshHelperInstallState() async"))
        #expect(app.contains("helperLifecycleOperationsInFlight += 1"))
        #expect(app.contains("helperLifecycleOperationsInFlight -= 1"))
    }
}
