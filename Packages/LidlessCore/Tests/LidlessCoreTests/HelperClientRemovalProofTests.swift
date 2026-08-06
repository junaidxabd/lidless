import Foundation
import Testing
@testable import LidlessCore

@Suite("Helper client removal proof")
struct HelperClientRemovalProofTests {
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

    private func restoredReply(version: Int = LidlessIDs.helperVersion) -> HelperReply {
        HelperReply(
            ok: true,
            status: HelperStatus(
                helperVersion: version,
                armed: false,
                sleepDisabled: false,
                sleepStateVerified: true,
                restorePending: false
            )
        )
    }

    @Test func removalProofRequiresCurrentHelperAndIndependentRegistryEvidence() {
        let reply = restoredReply()
        #expect(SleepOverrideSafety.isRestoreProven(
            reply,
            independentlyObserved: false
        ))
        #expect(!SleepOverrideSafety.isRestoreProven(
            reply,
            independentlyObserved: nil
        ))
        #expect(!SleepOverrideSafety.isRestoreProven(
            reply,
            independentlyObserved: true
        ))
        #expect(!SleepOverrideSafety.isRestoreProven(
            restoredReply(version: LidlessIDs.helperVersion - 1),
            independentlyObserved: false
        ))
        #expect(!SleepOverrideSafety.isRestoreProven(
            HelperReply(ok: false, status: reply.status),
            independentlyObserved: false
        ))
    }

    @Test func enabledHelperMustSupplyTwoSourceProofBeforeDeregistration() throws {
        let client = try repositoryFile("App/Sources/Helper/HelperClient.swift")
        let uninstall = try section(
            of: client,
            from: "func uninstall() async throws {",
            through: "private nonisolated static func unregisterDaemon()"
        )

        let helperReply = try #require(uninstall.range(of: "callForReply"))
        let independentRead = try #require(uninstall.range(
            of: "let independentlyObserved = PowerRegistry.sleepDisabled()"
        ))
        let combinedProof = try #require(uninstall.range(
            of: "HelperRemovalSafety.removalAction(\n                .enabled,\n                helperReply: reply,\n                independentlyObserved: independentlyObserved\n            )"
        ))
        let unregister = try #require(uninstall.range(of: "Self.unregisterDaemon()"))

        #expect(helperReply.lowerBound < independentRead.lowerBound)
        #expect(independentRead.lowerBound < combinedProof.lowerBound)
        #expect(combinedProof.lowerBound < unregister.lowerBound)
        #expect(!uninstall.contains("Proceed only if the override verifiably reads OFF"))
        #expect(!uninstall.contains("catch let error as NSError where error.domain == \"Lidless\""))
    }

    @Test func cleanupAuthorizationIsBoundToReviewedResponderBeforeMutation() throws {
        let client = try repositoryFile("App/Sources/Helper/HelperClient.swift")
        let helper = try repositoryFile("Helper/HelperDaemon.swift")
        let uninstall = try section(
            of: client,
            from: "func uninstall() async throws {",
            through: "private nonisolated static func unregisterDaemon()"
        )
        let enabled = try section(
            of: String(uninstall),
            from: "case .enabled:",
            through: "case .inactive:"
        )

        let invalidateCachedReadiness = try #require(enabled.range(
            of: "installState = .unknown"
        ))
        let preparation = try #require(enabled.range(
            of: "cleanupPreparation = try await prepareUninstall()"
        ))
        let compatibilityGate = try #require(enabled.range(
            of: "SleepOverrideSafety.isReviewedCleanupCompatibleHelper("
        ))
        #expect(enabled[compatibilityGate.upperBound...].contains(
            "cleanupPreparation.status"
        ))
        let authorization = try #require(enabled.range(
            of: "let cleanupAuthorization = cleanupPreparation.authorization"
        ))
        let registrationRecheck = try #require(enabled.range(
            of: "guard removalRegistrationState() == registrationState else"
        ))
        let cleanupFence = try #require(enabled.range(
            of: "removalFence = HelperRemovalClientSafety.beginRemoteCleanup()"
        ))
        let cleanupDispatch = try #require(enabled.range(
            of: "proxy.commitUninstall("
        ))
        let encodedAuthorization = try #require(enabled.range(
            of: "IPCCoding.encode(cleanupAuthorization)"
        ))

        #expect(invalidateCachedReadiness.lowerBound < preparation.lowerBound)
        #expect(preparation.lowerBound < compatibilityGate.lowerBound)
        #expect(compatibilityGate.lowerBound < authorization.lowerBound)
        #expect(authorization.lowerBound < registrationRecheck.lowerBound)
        #expect(compatibilityGate.lowerBound < registrationRecheck.lowerBound)
        #expect(registrationRecheck.lowerBound < cleanupFence.lowerBound)
        #expect(cleanupFence.lowerBound < cleanupDispatch.lowerBound)
        #expect(cleanupDispatch.lowerBound < encodedAuthorization.lowerBound)
        #expect(enabled.contains("did not request cleanup or deregistration"))
        #expect(enabled.contains(
            "installState = classifiedInstallState(for: cleanupPreparation.status)"
        ))
        #expect(enabled.contains("installState = .notResponding("))
        #expect(!enabled.contains("proxy.uninstall(done)"))
        #expect(String(enabled).components(
            separatedBy: "proxy.commitUninstall("
        ).count == 2)

        let cleanup = try section(
            of: helper,
            from: "fileprivate func handleUninstall(",
            through: "fileprivate func handleLegacyUninstall("
        )
        let tokenDecode = try #require(cleanup.range(
            of: "guard let authorization = IPCCoding.decode("
        ))
        let tokenGate = try #require(cleanup.range(
            of: "HelperCleanupHandshakeSafety.authorizes("
        ))
        let lifecycleMutation = try #require(cleanup.range(of: "advanceLifecycle()"))
        let cleanupFenceMutation = try #require(cleanup.range(
            of: "helperRemovalFence = .cleanupStarted"
        ))
        let restoration = try #require(cleanup.range(of: "performRestore(record"))
        let wakeCancellation = try #require(cleanup.range(
            of: "try PMSet.cancelWake(rendered: existing.rendered)"
        ))
        let dataRemoval = try #require(cleanup.range(
            of: "try FileManager.default.removeItem(atPath: HelperPaths.workDirectory)"
        ))

        #expect(tokenDecode.lowerBound < tokenGate.lowerBound)
        #expect(tokenGate.lowerBound < lifecycleMutation.lowerBound)
        #expect(tokenGate.lowerBound < cleanupFenceMutation.lowerBound)
        #expect(tokenGate.lowerBound < restoration.lowerBound)
        #expect(tokenGate.lowerBound < wakeCancellation.lowerBound)
        #expect(tokenGate.lowerBound < dataRemoval.lowerBound)

        let preparationHandler = try section(
            of: helper,
            from: "fileprivate func handlePrepareUninstall(",
            through: "fileprivate func handleUninstall("
        )
        #expect(preparationHandler.contains("HelperCleanupAuthorization("))
        #expect(preparationHandler.contains("status: currentStatus()"))
        #expect(!preparationHandler.contains("advanceLifecycle()"))
        #expect(!preparationHandler.contains("helperRemovalFence ="))
        #expect(!preparationHandler.contains("performRestore("))
        #expect(!preparationHandler.contains("PMSet.cancelWake"))
        #expect(!preparationHandler.contains("FileManager.default.removeItem"))

        let legacyHandler = try section(
            of: helper,
            from: "fileprivate func handleLegacyUninstall(",
            through: "private func currentStatus()"
        )
        #expect(legacyHandler.contains("ok: false"))
        #expect(legacyHandler.contains("no cleanup was attempted"))
        #expect(!legacyHandler.contains("advanceLifecycle()"))
        #expect(!legacyHandler.contains("helperRemovalFence ="))
        #expect(!legacyHandler.contains("performRestore("))
        #expect(!legacyHandler.contains("PMSet.cancelWake"))
        #expect(!legacyHandler.contains("FileManager.default.removeItem"))

        let bridge = try section(
            of: helper,
            from: "final class HelperXPCBridge",
            through: "daemon.handleLegacyUninstall(reply: reply)"
        )
        #expect(bridge.contains("func prepareUninstall("))
        #expect(bridge.contains("func commitUninstall("))
        #expect(bridge.contains("func uninstall("))
    }
}
