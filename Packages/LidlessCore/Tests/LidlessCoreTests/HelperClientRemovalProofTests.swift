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
}
