import Foundation
import Testing
@testable import LidlessCore

@Suite("Helper removal registration authorization")
struct HelperRemovalRegistrationSafetyTests {
    private var restoredReply: HelperReply {
        HelperReply(
            ok: true,
            status: HelperStatus(
                helperVersion: LidlessIDs.helperVersion,
                armed: false,
                sleepDisabled: false,
                sleepStateVerified: true,
                restorePending: false
            )
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

    @Test func exactEvidenceSelectsUnregisterOrAlreadyInactive() {
        #expect(HelperRemovalSafety.removalAction(
            .enabled,
            helperReply: restoredReply,
            independentlyObserved: false
        ) == .unregister)
        #expect(HelperRemovalSafety.removalAction(
            .enabled,
            helperReply: nil,
            independentlyObserved: false
        ) == nil)
        #expect(HelperRemovalSafety.removalAction(
            .enabled,
            helperReply: restoredReply,
            independentlyObserved: nil
        ) == nil)

        #expect(HelperRemovalSafety.removalAction(
            .inactive,
            helperReply: nil,
            independentlyObserved: false
        ) == .alreadyInactive)
        #expect(HelperRemovalSafety.removalAction(
            .inactive,
            helperReply: nil,
            independentlyObserved: nil
        ) == nil)
        #expect(HelperRemovalSafety.removalAction(
            .inactive,
            helperReply: nil,
            independentlyObserved: true
        ) == nil)

        #expect(HelperRemovalSafety.removalAction(
            .unknown,
            helperReply: restoredReply,
            independentlyObserved: false
        ) == nil)
    }

    @Test func registrationPolicyKeepsTypedActionsSeparateFromAppAdmission() throws {
        let registrationPolicy = try repositoryFile(
            "Packages/LidlessCore/Sources/LidlessCore/HelperRemovalSafety.swift"
        )
        let appPolicy = try repositoryFile(
            "Packages/LidlessCore/Sources/LidlessCore/HelperRemovalAppSafety.swift"
        )

        #expect(registrationPolicy.contains("func removalAction("))
        #expect(!registrationPolicy.contains("func canRemoveRegistration("))
        #expect(!registrationPolicy.contains("func canBeginAppRemoval("))
        #expect(appPolicy.contains("func canStartRemoval("))
        #expect(appPolicy.contains("func canProceedRemoval("))
    }

    @Test func clientClassifiesAndRechecksRegistrationBeforeDeregistration() throws {
        let client = try repositoryFile("App/Sources/Helper/HelperClient.swift")
        let uninstall = try section(
            of: client,
            from: "func uninstall() async throws {",
            through: "private nonisolated static func unregisterDaemon()"
        )
        let classifier = try section(
            of: client,
            from: "private func removalRegistrationState()",
            through: "private nonisolated static func unregisterDaemon()"
        )

        #expect(uninstall.contains("let registrationState = removalRegistrationState()"))
        #expect(uninstall.contains("switch registrationState"))
        #expect(uninstall.contains("case .enabled:"))
        #expect(uninstall.contains("case .inactive:"))
        #expect(uninstall.contains("case .unknown:"))
        #expect(uninstall.contains("HelperRemovalSafety.removalAction("))
        #expect(uninstall.contains("guard removalRegistrationState() == registrationState"))
        #expect(uninstall.contains("case .alreadyInactive:"))
        #expect(uninstall.contains("case .unregister:"))
        #expect(String(uninstall).components(
            separatedBy: "HelperRemovalSafety.removalAction("
        ).count == 3)
        #expect(String(uninstall).components(
            separatedBy: "Self.unregisterDaemon()"
        ).count == 2)
        #expect(!uninstall.contains("PowerRegistry.sleepDisabled() != true"))
        #expect(!uninstall.contains("if service.status == .enabled"))

        #expect(classifier.contains("case .enabled:"))
        #expect(classifier.contains("case .notRegistered:"))
        #expect(classifier.contains("case .notFound, .requiresApproval:"))
        #expect(classifier.contains("@unknown default:"))

        let classification = try #require(uninstall.range(
            of: "let registrationState = removalRegistrationState()"
        ))
        let authorization = try #require(uninstall.range(
            of: "switch registrationState"
        ))
        let stabilityCheck = try #require(uninstall.range(
            of: "guard removalRegistrationState() == registrationState"
        ))
        let alreadyInactive = try #require(uninstall.range(
            of: "case .alreadyInactive:"
        ))
        let unregisterAction = try #require(uninstall.range(
            of: "case .unregister:"
        ))
        let deregistration = try #require(uninstall.range(
            of: "try await Self.unregisterDaemon()"
        ))
        #expect(classification.lowerBound < authorization.lowerBound)
        #expect(authorization.lowerBound < stabilityCheck.lowerBound)
        #expect(stabilityCheck.lowerBound < alreadyInactive.lowerBound)
        #expect(alreadyInactive.lowerBound < unregisterAction.lowerBound)
        #expect(unregisterAction.lowerBound < deregistration.lowerBound)
        #expect(uninstall[alreadyInactive.lowerBound..<unregisterAction.lowerBound].contains("break"))
        #expect(!uninstall[alreadyInactive.lowerBound..<unregisterAction.lowerBound].contains("return"))
        #expect(!uninstall[alreadyInactive.lowerBound..<unregisterAction.lowerBound]
            .contains("unregisterDaemon"))
    }
}
