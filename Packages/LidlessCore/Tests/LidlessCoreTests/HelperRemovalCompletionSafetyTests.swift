import Foundation
import Testing
@testable import LidlessCore

@Suite("Helper removal completion proof")
struct HelperRemovalCompletionSafetyTests {
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

    private func occurrences(of needle: String, in source: Substring) -> Int {
        source.components(separatedBy: needle).count - 1
    }

    @Test func unregisterCompletionNeedsInactiveRegistrationAndFreshNormalSleep() {
        #expect(HelperRemovalCompletionSafety.isUnregisterCompletionProven(
            registrationState: .inactive,
            independentlyObserved: false
        ))

        let rejected: [(HelperRemovalSafety.RegistrationState, Bool?)] = [
            (.inactive, nil),
            (.inactive, true),
            (.enabled, false),
            (.enabled, nil),
            (.unknown, false),
            (.unknown, nil)
        ]
        for (registrationState, independentlyObserved) in rejected {
            #expect(!HelperRemovalCompletionSafety.isUnregisterCompletionProven(
                registrationState: registrationState,
                independentlyObserved: independentlyObserved
            ))
        }
    }

    @Test func preUnregisterAuthorizationCannotSubstituteForTheFinalPostcondition() throws {
        let restoredReply = HelperReply(
            ok: true,
            status: HelperStatus(
                helperVersion: LidlessIDs.helperVersion,
                armed: false,
                sleepDisabled: false,
                sleepStateVerified: true,
                restorePending: false
            )
        )
        let action = try #require(HelperRemovalSafety.removalAction(
            .enabled,
            helperReply: restoredReply,
            independentlyObserved: false
        ))
        #expect(action == .unregister)
        #expect(!HelperRemovalCompletionSafety.isUnregisterCompletionProven(
            registrationState: .enabled,
            independentlyObserved: false
        ))
        #expect(!HelperRemovalCompletionSafety.isUnregisterCompletionProven(
            registrationState: .unknown,
            independentlyObserved: false
        ))
    }

    @Test func clientFailsClosedUntilThePostUnregisterStateIsProven() throws {
        let client = try repositoryFile("App/Sources/Helper/HelperClient.swift")
        let uninstall = try section(
            of: client,
            from: "func uninstall() async throws",
            through: "private func removalRegistrationState()"
        )
        let unregisterStart = try #require(uninstall.range(of: "case .unregister:"))
        let unregisterTail = uninstall[unregisterStart.lowerBound...]

        #expect(occurrences(
            of: "try await Self.unregisterDaemon()",
            in: unregisterTail
        ) == 1)
        let unregister = try #require(unregisterTail.range(
            of: "try await Self.unregisterDaemon()"
        ))
        let invalidate = try #require(unregisterTail.range(
            of: "invalidateConnection()",
            range: unregister.upperBound..<unregisterTail.endIndex
        ))
        let finalRegistration = try #require(unregisterTail.range(
            of: "let finalRegistrationState = removalRegistrationState()",
            range: invalidate.upperBound..<unregisterTail.endIndex
        ))
        let finalRegistry = try #require(unregisterTail.range(
            of: "let finalSleepDisabled = PowerRegistry.sleepDisabled()",
            range: finalRegistration.upperBound..<unregisterTail.endIndex
        ))
        let completionGate = try #require(unregisterTail.range(
            of: "HelperRemovalCompletionSafety.isUnregisterCompletionProven(",
            range: finalRegistry.upperBound..<unregisterTail.endIndex
        ))
        let completedState = try #require(unregisterTail.range(
            of: "installState = .notInstalled",
            range: completionGate.upperBound..<unregisterTail.endIndex
        ))

        #expect(invalidate.lowerBound < finalRegistration.lowerBound)
        #expect(finalRegistration.lowerBound < finalRegistry.lowerBound)
        #expect(finalRegistry.lowerBound < completionGate.lowerBound)
        #expect(completionGate.lowerBound < completedState.lowerBound)
        #expect(occurrences(of: "installState = .unknown", in: unregisterTail) >= 2)
        #expect(!unregisterTail.contains("await refreshInstallState()"))
        #expect(!unregisterTail.contains("remains installed"))
        #expect(!unregisterTail.contains("supervision can continue"))
    }

    @Test func removalFailureCopyDoesNotAssumeDeregistrationFailed() throws {
        let app = try repositoryFile("App/Sources/AppState.swift")
        let appUninstall = try section(
            of: app,
            from: "func uninstall() async -> String?",
            through: "// MARK: - Login item"
        )
        #expect(appUninstall.contains("Helper removal could not be fully verified:"))
        #expect(!appUninstall.contains("Could not remove the helper:"))
        #expect(appUninstall.contains("Helper registration inactive"))
        #expect(appUninstall.contains("the helper is not registered"))
        #expect(!appUninstall.contains("Helper removed"))
        #expect(!appUninstall.contains("helper registration was removed"))

        let setup = try repositoryFile("App/Sources/UI/Main/SetupPane.swift")
        let setupUninstall = try section(
            of: setup,
            from: "private var uninstallSection",
            through: "private var aboutSection"
        )
        // The failure guidance moved into `AppState.uninstall()` so it can match
        // what the failing code path actually proved. An unresolved remote
        // outcome must still refuse to assume removal happened and must still
        // offer the emergency command; a failure that provably requested no
        // cleanup or deregistration must not contradict its own message.
        #expect(appUninstall.contains("do not assume the helper is still installed"))
        #expect(appUninstall.contains("LidlessIDs.manualFallbackCommand"))
        #expect(appUninstall.contains(
            "HelperRemovalFailureInfo.didNotStartKey"
        ))
        #expect(appUninstall.contains(
            "still installed and still supervised. Do not remove it manually."
        ))
        #expect(setupUninstall.contains("message: Text(message)"))
        #expect(setupUninstall.contains("Helper registration inactive"))
        #expect(setupUninstall.contains("the helper is not registered"))
        #expect(!setupUninstall.contains("Helper removed"))
        #expect(!setupUninstall.contains("helper registration was removed"))
        #expect(!setupUninstall.contains("Nothing dangerous remains"))
        #expect(!setupUninstall.contains(
            "The helper remains installed whenever normal sleep cannot be verified"
        ))
    }

    @Test func simulationCannotBypassCompletionProof() throws {
        #expect(HelperRemovalCompletionSafety.canAttemptVerifiedRemoval(
            isSimulation: false
        ))
        #expect(!HelperRemovalCompletionSafety.canAttemptVerifiedRemoval(
            isSimulation: true
        ))

        let app = try repositoryFile("App/Sources/AppState.swift")
        let appUninstall = try section(
            of: app,
            from: "func uninstall() async -> String?",
            through: "// MARK: - Login item"
        )
        let eligibility = try #require(appUninstall.range(
            of: "guard HelperRemovalCompletionSafety.canAttemptVerifiedRemoval("
        ))
        let helperCall = try #require(appUninstall.range(
            of: "try await helper.uninstall()"
        ))
        #expect(eligibility.lowerBound < helperCall.lowerBound)
        #expect(appUninstall.contains(
            "Uninstall is unavailable in simulation. Exit simulation to remove the installed helper."
        ))

        let setup = try repositoryFile("App/Sources/UI/Main/SetupPane.swift")
        let setupUninstall = try section(
            of: setup,
            from: "private var uninstallSection",
            through: "private var aboutSection"
        )
        #expect(setupUninstall.contains(".disabled(busy || state.isSimulation)"))
        #expect(setupUninstall.contains("Exit simulation to remove the installed helper."))
    }
}
