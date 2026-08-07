import Foundation
import Testing
@testable import LidlessCore

@Suite("Disabled helper cleanup surface")
struct HelperCleanupSurfaceSourceTests {
    private func repositoryURL(_ relativePath: String) throws -> URL {
        var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let fileManager = FileManager.default

        while directory.path != "/" {
            let candidate = directory.appendingPathComponent(relativePath)
            if fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
            directory.deleteLastPathComponent()
        }
        throw CocoaError(.fileNoSuchFile)
    }

    private func repositoryFile(_ relativePath: String) throws -> String {
        try String(contentsOf: repositoryURL(relativePath), encoding: .utf8)
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

    @Test func deadCleanupPolicyImplementationsAreAbsent() throws {
        let fileManager = FileManager.default
        let sourceDirectory = try repositoryURL(
            "Packages/LidlessCore/Sources/LidlessCore/HelperIPC.swift"
        ).deletingLastPathComponent()
        let removedPolicies = [
            "HelperRemovalAppSafety.swift",
            "HelperRemovalClientSafety.swift",
            "HelperRemovalCompletionSafety.swift",
            "HelperRemovalDaemonSafety.swift",
            "HelperRemovalSafety.swift",
        ]

        for filename in removedPolicies {
            #expect(!fileManager.fileExists(
                atPath: sourceDirectory.appendingPathComponent(filename).path
            ))
        }

        let ipc = try repositoryFile(
            "Packages/LidlessCore/Sources/LidlessCore/HelperIPC.swift"
        )
        #expect(!ipc.contains("HelperCleanupHandshakeSafety"))
        #expect(ipc.contains("struct HelperCleanupAuthorization"))
        #expect(ipc.contains("struct HelperCleanupPreparation"))

        let sleepSafety = try repositoryFile(
            "Packages/LidlessCore/Sources/LidlessCore/SleepOverrideSafety.swift"
        )
        let identifiers = try repositoryFile(
            "Packages/LidlessCore/Sources/LidlessCore/LidlessIDs.swift"
        )
        #expect(!sleepSafety.contains("isReviewedCleanupCompatibleHelper"))
        #expect(!sleepSafety.contains("isReviewedStaleReplacementCompatible"))
        #expect(!identifiers.contains("reviewedStaleReplacementSafetyRevision"))
    }

    @Test func clientCanOnlyRefuseCleanupAndCannotDeregisterDaemon() throws {
        let client = try repositoryFile("App/Sources/Helper/HelperClient.swift")
        let uninstall = try section(
            of: client,
            from: "func uninstall() async throws {",
            through: "// MARK: - XPC surface"
        )

        #expect(uninstall.contains("throw HelperClientError.rejected("))
        #expect(uninstall.contains("Automatic helper cleanup is disabled"))
        #expect(!uninstall.contains("await"))
        #expect(!client.contains("HelperRemoval"))
        #expect(!client.contains("removalFence"))
        #expect(!client.contains("prepareUninstall"))
        #expect(!client.contains("commitUninstall"))
        #expect(!client.contains("beginRemoteCleanup"))
        #expect(!client.contains("unregisterDaemon"))
        #expect(!client.contains(".unregister()"))
    }

    @Test func appStateCleanupEntryIsAnImmediateSideEffectFreeRefusal() throws {
        let app = try repositoryFile("App/Sources/AppState.swift")
        let uninstall = try section(
            of: app,
            from: "func uninstall() async -> String?",
            through: "// MARK: - Login item"
        )

        #expect(uninstall.contains("Automatic helper cleanup is disabled"))
        #expect(uninstall.contains("No state was changed by this request"))
        for forbidden in [
            "await",
            "helper.uninstall",
            "deleteAllData",
            "setLaunchAtLogin",
            "SMAppService",
            "beginHelperLifecycleOperation",
            "helperRegistrationInProgress =",
            "scheduledWakeReconciliation.invalidate",
        ] {
            #expect(!uninstall.contains(forbidden))
        }
    }

    @Test func registrationFenceAndSimulationRetainNoCleanupBehavior() throws {
        let app = try repositoryFile("App/Sources/AppState.swift")
        let launchSafety = try repositoryFile(
            "Packages/LidlessCore/Sources/LidlessCore/LaunchReconciliationSafety.swift"
        )
        let simulation = try repositoryFile("App/Sources/Simulation/Simulation.swift")
        let simulatedUninstall = try section(
            of: simulation,
            from: "func uninstall() async throws {",
            through: "func status() async throws"
        )

        #expect(!app.contains("uninstallInProgress"))
        #expect(!launchSafety.contains("uninstallInProgress"))
        #expect(app.contains("helperRegistrationInProgress"))
        #expect(launchSafety.contains("helperRegistrationInProgress"))
        #expect(simulatedUninstall.contains("throw HelperClientError.rejected("))
        #expect(simulatedUninstall.contains("Automatic helper cleanup is disabled"))
        #expect(!simulatedUninstall.contains("armed = false"))
        #expect(!simulatedUninstall.contains("sleepDisabled = false"))
    }

    @Test func daemonCompatibilitySelectorsRefuseWithoutCleanupMutation() throws {
        let helper = try repositoryFile("Helper/HelperDaemon.swift")
        let handlers: [Substring] = [
            try section(
                of: helper,
                from: "fileprivate func handlePrepareUninstall(",
                through: "fileprivate func handleUninstall("
            ),
            try section(
                of: helper,
                from: "fileprivate func handleUninstall(",
                through: "fileprivate func handleLegacyUninstall("
            ),
            try section(
                of: helper,
                from: "fileprivate func handleLegacyUninstall(",
                through: "private func currentStatus()"
            ),
        ]

        #expect(!helper.contains("HelperRemoval"))
        #expect(!helper.contains("helperRemovalFence"))
        #expect(!helper.contains("helper cleanup has started"))
        #expect(!helper.contains("launchctl"))
        #expect(!helper.contains("bootout"))
        #expect(!helper.contains("SMAppService"))
        #expect(!helper.contains("unregisterDaemon"))

        for handler in handlers {
            #expect(handler.contains("ok: false"))
            #expect(handler.contains(
                "automatic helper cleanup is disabled; a reviewed removal procedure is required"
            ))
            #expect(handler.contains("status: currentStatus()"))
            for forbidden in [
                "advanceLifecycle()",
                "performRestore(",
                "PMSet.",
                "FileManager",
                "removeItem",
                "unlinkat",
                "IPCCoding.decode(",
            ] {
                #expect(!handler.contains(forbidden))
            }
        }

        let bridge = try section(
            of: helper,
            from: "final class HelperXPCBridge",
            through: "daemon.handleLegacyUninstall(reply: reply)"
        )
        #expect(bridge.contains("func prepareUninstall("))
        #expect(bridge.contains("func commitUninstall("))
        #expect(bridge.contains("func uninstall("))
    }

    @Test func removingPermanentOpenFenceKeepsLiveAdmissionGates() throws {
        let helper = try repositoryFile("Helper/HelperDaemon.swift")
        let arm = try section(
            of: helper,
            from: "private func handleArm(",
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
            through: "fileprivate func handlePrepareUninstall("
        )

        for source in [arm, heartbeat, disarm, repair, wake] {
            #expect(!source.contains("HelperRemoval"))
            #expect(!source.contains("helperRemovalFence"))
        }
        #expect(arm.contains("HelperClientAdmissionSafety.allows("))
        #expect(arm.contains("!unresolvedMutationRemains()"))
        #expect(arm.contains("!durableMutationMarkerRequiresRecovery"))
        #expect(arm.contains("HelperTerminationSafety.allows(.arm"))
        #expect(arm.contains("HelperSessionOwnershipSafety.armDisposition("))
        #expect(heartbeat.contains("HelperSessionOwnershipSafety.heartbeatDisposition("))
        #expect(disarm.contains("HelperClientAdmissionSafety.allows("))
        #expect(disarm.contains("DelayedSleepSafety.allowsForceSleep("))
        #expect(disarm.contains("HelperTerminationSafety.allows(.forceSleep"))
        #expect(disarm.contains("!durableMutationMarkerRequiresRecovery"))
        #expect(repair.contains("HelperTerminationSafety.allows(.repairOverride"))
        #expect(repair.contains("sentinel ?? restorePending"))
        #expect(wake.contains("HelperClientAdmissionSafety.allows("))
        #expect(wake.contains("!unresolvedMutationRemains()"))
        #expect(wake.contains("!durableMutationMarkerRequiresRecovery"))
        #expect(wake.contains("HelperTerminationSafety.allows(.scheduleWake"))
        #expect(wake.contains("sentinel == nil, restorePending == nil"))
    }
}
