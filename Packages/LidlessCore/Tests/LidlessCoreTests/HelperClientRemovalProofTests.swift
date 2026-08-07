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

    @Test func publicClientRemovalCannotDispatchOrDeregister() throws {
        let client = try repositoryFile("App/Sources/Helper/HelperClient.swift")
        let publicRemoval = try section(
            of: client,
            from: "func uninstall() async throws {",
            through: "// MARK: - XPC surface"
        )

        #expect(publicRemoval.contains(
            "Automatic helper cleanup is disabled; a reviewed removal procedure is required"
        ))
        #expect(publicRemoval.contains("throw HelperClientError.rejected("))
        #expect(publicRemoval.contains("Keep the helper registered"))
        #expect(!publicRemoval.contains("await"))
        #expect(!publicRemoval.contains("commitUninstall"))
        #expect(!publicRemoval.contains("prepareUninstall"))
        #expect(!publicRemoval.contains("unregister"))
        #expect(!client.contains("private func uninstall("))
        #expect(!client.contains("unregisterDaemon"))
        #expect(!client.contains("HelperCleanupTarget"))
        #expect(!client.contains("HelperCleanupOutcome"))
    }

    @Test func daemonWireCompatibilitySelectorsAllRefuseWithoutMutation() throws {
        let helper = try repositoryFile("Helper/HelperDaemon.swift")
        let selectors: [(String, String)] = [
            ("fileprivate func handlePrepareUninstall(", "fileprivate func handleUninstall("),
            ("fileprivate func handleUninstall(", "fileprivate func handleLegacyUninstall("),
            ("fileprivate func handleLegacyUninstall(", "private func currentStatus()"),
        ]

        for (start, end) in selectors {
            let handler = try section(of: helper, from: start, through: end)
            #expect(handler.contains(
                "automatic helper cleanup is disabled; a reviewed removal procedure is required"
            ))
            #expect(handler.contains("ok: false"))
            #expect(!handler.contains("advanceLifecycle()"))
            #expect(!handler.contains("performRestore("))
            #expect(!handler.contains("PMSet."))
            #expect(!handler.contains("FileManager"))
            #expect(!handler.contains("IPCCoding.decode("))
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
}
