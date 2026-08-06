import Foundation
import Testing
@testable import LidlessCore

@Suite("Sleep state presentation safety")
struct SleepStatePresentationTests {
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
              let endRange = source.range(of: end, range: startRange.upperBound..<source.endIndex)
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

    private func snapshot(
        presentation: SleepPresentationState?,
        updatedAt: Date,
        armed: Bool? = nil,
        overrideActive: Bool? = nil,
        overrideStateVerified: Bool? = nil
    ) -> WidgetSnapshot {
        WidgetSnapshot(
            armed: armed ?? (presentation == .verifiedArmed),
            statusLine: "test",
            batteryPercent: nil,
            isCharging: false,
            overrideActive: overrideActive
                ?? (presentation == .verifiedArmed || presentation == .outsideOverride),
            overrideStateVerified: overrideStateVerified ?? (presentation != .unknown),
            sleepPresentation: presentation,
            updatedAt: updatedAt
        )
    }

    @Test func presentationTruthTableNeverTurnsUnknownOrMismatchIntoSuccess() {
        let cases: [(SleepPresentationPhase, Bool?, Bool, SleepPresentationState)] = [
            (.disarmed, false, false, .verifiedNormal),
            (.disarmed, true, false, .outsideOverride),
            (.disarmed, nil, false, .unknown),
            (.arming, false, false, .verifyingArm),
            (.arming, true, false, .verifyingArm),
            (.arming, nil, false, .verifyingArm),
            (.armed, false, true, .unknown),
            (.armed, true, true, .verifiedArmed),
            (.armed, nil, true, .unknown),
            (.armed, false, false, .unknown),
            (.armed, true, false, .unknown),
            (.armed, nil, false, .unknown),
            (.restoring, false, false, .restoring),
            (.restoring, true, false, .restoring),
            (.restoring, nil, false, .restoring),
        ]

        for (phase, observation, helperSessionProven, expected) in cases {
            #expect(SleepPresentationPolicy.resolve(
                phase: phase,
                observedOverride: observation,
                helperSessionProven: helperSessionProven
            ) == expected)
        }
    }

    @Test func widgetEvidenceFreshnessHasFailClosedBoundaries() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        #expect(snapshot(
            presentation: .verifiedArmed,
            updatedAt: now.addingTimeInterval(-60)
        ).effectiveSleepPresentation(at: now) == .verifiedArmed)
        #expect(snapshot(
            presentation: .verifiedNormal,
            updatedAt: now.addingTimeInterval(-WidgetSnapshot.freshnessLifetime - 1)
        ).effectiveSleepPresentation(at: now) == .unknown)
        #expect(snapshot(
            presentation: .verifiedNormal,
            updatedAt: now.addingTimeInterval(WidgetSnapshot.futureTimestampTolerance + 1)
        ).effectiveSleepPresentation(at: now) == .unknown)
        #expect(snapshot(
            presentation: nil,
            updatedAt: now
        ).effectiveSleepPresentation(at: now) == .unknown)

        #expect(snapshot(
            presentation: .verifiedNormal,
            updatedAt: now.addingTimeInterval(WidgetSnapshot.futureTimestampTolerance)
        ).evidenceFreshness(at: now) == .fresh)
        #expect(snapshot(
            presentation: .verifiedNormal,
            updatedAt: now.addingTimeInterval(WidgetSnapshot.futureTimestampTolerance + 1)
        ).evidenceFreshness(at: now) == .rejectedFuture)
        #expect(snapshot(
            presentation: .verifiedNormal,
            updatedAt: now.addingTimeInterval(-WidgetSnapshot.freshnessLifetime)
        ).evidenceFreshness(at: now) == .fresh)
        #expect(snapshot(
            presentation: .verifiedNormal,
            updatedAt: now.addingTimeInterval(-WidgetSnapshot.freshnessLifetime - 1)
        ).evidenceFreshness(at: now) == .expired)
        #expect(snapshot(
            presentation: .verifiedNormal,
            updatedAt: Date(timeIntervalSinceReferenceDate: .nan)
        ).evidenceFreshness(at: now) == .rejectedFuture)
    }


    @Test func widgetStoreMigratesAwayFromUnprovableLegacySchema() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("lidless-widget-store-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let legacyURL = directory.appendingPathComponent(WidgetStore.legacySnapshotFileName)
        try Data("legacy".utf8).write(to: legacyURL)

        let saved = WidgetStore.save(snapshot(
            presentation: .verifiedNormal,
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        ), in: directory)

        #expect(saved)
        #expect(!FileManager.default.fileExists(atPath: legacyURL.path))
        #expect(FileManager.default.fileExists(atPath: directory
            .appendingPathComponent(WidgetStore.currentSnapshotFileName).path))
    }

    @Test func widgetRejectsContradictoryOrUnprovedSuccessClaims() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        let missingProof = WidgetSnapshot(
            armed: true,
            statusLine: "test",
            batteryPercent: nil,
            isCharging: false,
            overrideActive: true,
            overrideStateVerified: nil,
            sleepPresentation: .verifiedArmed,
            updatedAt: now
        )
        #expect(missingProof.effectiveSleepPresentation(at: now) == .unknown)

        #expect(snapshot(
            presentation: .verifiedArmed,
            updatedAt: now,
            overrideStateVerified: false
        ).effectiveSleepPresentation(at: now) == .unknown)
        #expect(snapshot(
            presentation: .verifiedArmed,
            updatedAt: now,
            overrideActive: false
        ).effectiveSleepPresentation(at: now) == .unknown)
        #expect(snapshot(
            presentation: .verifiedArmed,
            updatedAt: now,
            armed: false
        ).effectiveSleepPresentation(at: now) == .unknown)
        #expect(snapshot(
            presentation: .verifiedNormal,
            updatedAt: now,
            overrideActive: true
        ).effectiveSleepPresentation(at: now) == .unknown)
        #expect(snapshot(
            presentation: .verifiedNormal,
            updatedAt: now,
            armed: true
        ).effectiveSleepPresentation(at: now) == .unknown)
        #expect(snapshot(
            presentation: .outsideOverride,
            updatedAt: now,
            overrideStateVerified: false
        ).effectiveSleepPresentation(at: now) == .unknown)
        #expect(snapshot(
            presentation: .restoring,
            updatedAt: now,
            armed: true
        ).effectiveSleepPresentation(at: now) == .unknown)
    }

    @Test func legacyWidgetJSONWithoutProofDecodesAsUnknown() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let encoded = try IPCCoding.encoder().encode(snapshot(
            presentation: .verifiedArmed,
            updatedAt: now
        ))
        var object = try #require(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        object.removeValue(forKey: "sleepPresentation")
        object.removeValue(forKey: "overrideStateVerified")
        let legacyData = try JSONSerialization.data(withJSONObject: object)
        let decoded = try #require(IPCCoding.decode(WidgetSnapshot.self, from: legacyData))

        #expect(decoded.sleepPresentation == nil)
        #expect(decoded.overrideStateVerified == nil)
        #expect(decoded.effectiveSleepPresentation(at: now) == .unknown)
    }

    @Test func appAndWidgetSourcesUseTheFailClosedReducer() throws {
        let monitor = try repositoryFile("App/Sources/Monitors/SystemStateMonitor.swift")
        let app = try repositoryFile("App/Sources/AppState.swift")
        let helper = try repositoryFile("App/Sources/Helper/HelperClient.swift")
        let publisher = try repositoryFile("App/Sources/Services/WidgetPublisher.swift")
        let simulation = try repositoryFile("App/Sources/Simulation/Simulation.swift")
        let widget = try repositoryFile("Widget/Sources/LidlessWidget.swift")
        let glassSwitch = try repositoryFile("App/Sources/UI/MenuBar/GlassSwitch.swift")
        let menuPanel = try repositoryFile("App/Sources/UI/MenuBar/MenuPanelView.swift")
        let overview = try repositoryFile("App/Sources/UI/Main/OverviewPane.swift")

        #expect(monitor.contains("private(set) var overrideActive: Bool?"))
        #expect(monitor.contains("let override = PowerRegistry.sleepDisabled()"))
        #expect(!monitor.contains("PowerRegistry.sleepDisabled() ?? false"))
        #expect(monitor.contains("private(set) var overrideRevision: UInt64 = 0"))
        #expect(monitor.contains("overrideRevision &+= 1"))
        #expect(app.contains("private var lastOverrideRevision: UInt64?"))
        #expect(app.contains("private var helperSessionProven = false"))
        #expect(app.contains("lastOverrideRevision != systemMonitor.overrideRevision"))
        #expect(app.contains("SleepPresentationPolicy.resolve("))
        #expect(app.contains("let eligibleHelperSessionProven = helperSessionProven && helperState.isUsable"))
        #expect(app.contains("helperSessionProven: eligibleHelperSessionProven"))
        #expect(app.contains("sleepPresentation: sleepPresentation"))
        #expect(app.contains("guard sleepPresentation == .verifiedNormal else"))
        #expect(app.contains("armed: sleepPresentation == .verifiedArmed"))
        #expect(publisher.contains("$0.sleepPresentation != snapshot.sleepPresentation"))
        #expect(simulation.contains("sleepStateVerified: true"))
        #expect(simulation.contains("restorePending: false"))

        let usability = try section(
            of: helper,
            from: "var isUsable: Bool",
            through: "var isReachable: Bool"
        )
        #expect(usability.contains("case .ready, .simulated: true"))
        #expect(!usability.contains(".stale"))
        #expect(glassSwitch.contains("guard !busy, actionAvailable else"))
        #expect(menuPanel.contains("armed: state.sleepPresentation == .verifiedArmed"))
        #expect(menuPanel.contains("actionAvailable: state.phase == .armed"))
        #expect(menuPanel.contains("else if state.sleepPresentation == .verifiedNormal"))
        #expect(overview.contains("state.sleepPresentation != .verifiedNormal"))

        let timeline = try section(
            of: widget,
            from: "func getTimeline",
            through: "extension WidgetSnapshot"
        )
        #expect(!timeline.contains("if let snapshot, snapshot.armed"))
        #expect(timeline.contains("snapshot.updatedAt.addingTimeInterval(WidgetSnapshot.freshnessLifetime)"))
        #expect(timeline.contains("case .rejectedFuture:"))
        #expect(timeline.contains("policy: .never"))
        #expect(widget.contains("effectiveSleepPresentation(at: date)"))
        #expect(widget.contains("presentation == .verifiedArmed"))
        #expect(!widget.contains("return snapshot.statusLine"))
        #expect(widget.contains("case .verifiedNormal:"))
        #expect(widget.contains("return \"Sleeping normally\""))

        let confirmArm = try section(
            of: app,
            from: "func confirmArm() async",
            through: "func disarm() async"
        )
        let arming = try #require(confirmArm.range(of: "phase = .arming"))
        let invalidation = try #require(confirmArm.range(
            of: "overrideStateVerified = false",
            range: arming.upperBound..<confirmArm.endIndex
        ))
        let transitionPublish = try #require(confirmArm.range(
            of: "publishWidget()",
            range: invalidation.upperBound..<confirmArm.endIndex
        ))
        let firstSuspension = try #require(confirmArm.range(
            of: "await notifications.requestAuthorizationIfNeeded()",
            range: transitionPublish.upperBound..<confirmArm.endIndex
        ))
        let helperRefresh = try #require(confirmArm.range(
            of: "await refreshHelperInstallState()",
            range: firstSuspension.upperBound..<confirmArm.endIndex
        ))
        let eligibilityEpoch = try #require(confirmArm.range(
            of: "let eligibilityEpoch = helperProofEpoch",
            range: firstSuspension.upperBound..<helperRefresh.lowerBound
        ))
        let helperEligibility = try #require(confirmArm.range(
            of: "guard helperState.isUsable else",
            range: helperRefresh.upperBound..<confirmArm.endIndex
        ))
        let armCall = try #require(confirmArm.range(
            of: "try await trackedArm(options)",
            range: helperEligibility.upperBound..<confirmArm.endIndex
        ))
        let armOptions = try #require(confirmArm.range(
            of: "let options = pending.plan.helperOptions",
            range: helperEligibility.upperBound..<armCall.lowerBound
        ))
        let committedIntent = try #require(confirmArm.range(
            of: "pendingArm = nil",
            range: armOptions.upperBound..<armCall.lowerBound
        ))
        #expect(arming.lowerBound < transitionPublish.lowerBound)
        #expect(invalidation.lowerBound < transitionPublish.lowerBound)
        #expect(transitionPublish.lowerBound < firstSuspension.lowerBound)
        #expect(confirmArm.contains("guard publishWidget() else"))
        #expect(eligibilityEpoch.lowerBound < helperRefresh.lowerBound)
        #expect(helperRefresh.lowerBound < helperEligibility.lowerBound)
        #expect(helperEligibility.lowerBound < armCall.lowerBound)
        #expect(armOptions.lowerBound < committedIntent.lowerBound)
        #expect(committedIntent.lowerBound < armCall.lowerBound)
        #expect(confirmArm.contains("SleepOverrideSafety.isArmProven(reply)"))
        #expect(confirmArm.contains("guard let pending = pendingArm"))
        #expect(confirmArm.contains("pending.createdAt == intent.createdAt"))
        #expect(confirmArm.contains("freshAssessment == intent.assessment"))

        let proofLoss = try section(
            of: app,
            from: "private func helperInterrupted()",
            through: "private func resyncAfterWake()"
        )
        #expect(proofLoss.contains("overrideStateVerified = false"))
        #expect(occurrenceCount(
            of: "startTerminalRecoveryAfterHelperProofLoss",
            in: proofLoss
        ) == 2)
        #expect(proofLoss.contains("beginRestore(PendingRestore("))
        #expect(proofLoss.contains("endReason: currentSession == nil ? nil : .helperProofLost"))
        #expect(!proofLoss.contains("trackedArm("))
        #expect(!proofLoss.contains("helper.arm("))
        #expect(!proofLoss.contains("helperSessionProven = true"))
        #expect(!proofLoss.contains("rearmAfterHelperRestart"))

        let wake = try section(
            of: app,
            from: "private func resyncAfterWake()",
            through: "private func reconcileWithHelper()"
        )
        #expect(wake.contains("recordSleepTransition()"))
        #expect(wake.contains("scheduleSleepTerminationRestore()"))
        #expect(!wake.contains("helperSessionProven = true"))
        #expect(!wake.contains("SleepOverrideSafety.isArmProven(status)"))

        let flags = try section(
            of: app,
            from: "private func refreshSystemFlags()",
            through: "// MARK: - Cutoff evaluation"
        )
        #expect(flags.contains("if phase == .armed, observedOverride != true"))
        #expect(flags.contains("invalidateHelperSessionProof()"))
        #expect(app.contains("systemMonitor?.onWillSleep = { [weak self] in\n            self?.recordSleepTransition()"))
        #expect(app.contains(
            "if (phase == .armed || phase == .arming),\n           !helperState.isUsable"
        ))

        #expect(publisher.contains("func publish(_ snapshot: WidgetSnapshot) -> Bool"))
        #expect(publisher.contains("guard WidgetStore.save(snapshot) else { return false }"))
        #expect(publisher.contains("return true"))

        let heartbeat = try section(
            of: app,
            from: "private func startHeartbeat()",
            through: "private func stopHeartbeat()"
        )
        #expect(String(heartbeat).components(
            separatedBy: "overrideStateVerified = false"
        ).count == 3)
    }

    @Test func sleepTransitionTerminallyFencesInFlightArmProofs() throws {
        let app = try repositoryFile("App/Sources/AppState.swift")

        let transition = try section(
            of: app,
            from: "private func recordSleepTransition()",
            through: "var effectiveConfig"
        )
        #expect(transition.contains("sleepGeneration &+= 1"))
        #expect(transition.contains("sleepTerminationGeneration = sleepGeneration"))
        #expect(transition.contains("phase = .disarming"))
        #expect(transition.contains("stopHeartbeat()"))
        #expect(transition.contains("scheduleSleepTerminationRestore()"))
        #expect(transition.contains("armRequestsInFlight > 0"))
        #expect(transition.contains("let cancelledPendingIntent = pendingArm != nil"))
        let pendingClear = try #require(transition.range(of: "pendingArm = nil"))
        let terminalBranch = try #require(transition.range(of: "if terminatesActiveIntent"))
        #expect(pendingClear.lowerBound < terminalBranch.lowerBound)

        let confirm = try section(
            of: app,
            from: "func confirmArm() async",
            through: "func disarm() async"
        )
        #expect(confirm.contains("let armSleepGeneration = sleepGeneration"))
        #expect(confirm.contains("try await trackedArm(options)"))
        #expect(confirm.contains("phase == .arming"))
        #expect(confirm.contains("armSleepGeneration == sleepGeneration"))

        let proofLoss = try section(
            of: app,
            from: "private func helperInterrupted()",
            through: "private func resyncAfterWake()"
        )
        #expect(occurrenceCount(
            of: "startTerminalRecoveryAfterHelperProofLoss",
            in: proofLoss
        ) == 2)
        #expect(proofLoss.contains("phase == .armed || phase == .arming"))
        #expect(!proofLoss.contains("trackedArm(options)"))
        #expect(!proofLoss.contains("rearmAfterHelperRestart"))

        let wake = try section(
            of: app,
            from: "private func resyncAfterWake()",
            through: "private func reconcileWithHelper()"
        )
        #expect(wake.contains("scheduleSleepTerminationRestore()"))
        #expect(!wake.contains("helperSessionProven = true"))
        #expect(!wake.contains("SleepOverrideSafety.isArmProven(status)"))

        let restore = try section(
            of: app,
            from: "private func scheduleSleepTerminationRestore()",
            through: "var effectiveConfig"
        )
        #expect(restore.contains("armRequestsInFlight == 0"))
        #expect(restore.contains("SleepOverrideSafety.isRestoreProven(reply)"))
        #expect(restore.contains("finalizeSession(endReason: .systemSlept)"))

        let restorePaths = try section(
            of: app,
            from: "func disarm() async",
            through: "private func finalizeSession"
        )
        #expect(String(restorePaths).components(
            separatedBy: "sleepTerminationGeneration == nil"
        ).count >= 5)
        #expect(String(restorePaths).components(
            separatedBy: "cancelPendingRestoreForSleepTransition()"
        ).count >= 4)
    }
}
