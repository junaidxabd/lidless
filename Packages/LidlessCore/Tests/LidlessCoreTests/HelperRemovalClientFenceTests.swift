import Foundation
import Testing
@testable import LidlessCore

@Suite("Helper removal client fence")
struct HelperRemovalClientFenceTests {
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

    @Test func dispatchedCleanupBlocksMutationsAcrossEveryAmbiguousObservation() {
        let unresolved = HelperRemovalClientSafety.beginRemoteCleanup()
        #expect(!HelperRemovalClientSafety.allows(.arm, while: unresolved))

        let ambiguous: [(HelperRemovalSafety.RegistrationState, Bool?)] = [
            (.enabled, false),
            (.enabled, true),
            (.enabled, nil),
            (.inactive, true),
            (.inactive, nil),
            (.unknown, false),
            (.unknown, true),
            (.unknown, nil)
        ]
        for (registration, sleepDisabled) in ambiguous {
            #expect(HelperRemovalClientSafety.resolve(
                unresolved,
                registrationState: registration,
                independentlyObserved: sleepDisabled
            ) == .outcomeUnresolved)
        }
    }

    @Test func onlyFinalInactiveAndNormalSleepProofReopensMutations() {
        let unresolved = HelperRemovalClientSafety.beginRemoteCleanup()
        let resolved = HelperRemovalClientSafety.resolve(
            unresolved,
            registrationState: .inactive,
            independentlyObserved: false
        )

        #expect(resolved == .open)
        #expect(HelperRemovalClientSafety.allows(.arm, while: resolved))
        #expect(HelperRemovalClientSafety.resolve(
            .open,
            registrationState: .unknown,
            independentlyObserved: nil
        ) == .open)
    }

    @Test func unresolvedOutcomeBlocksRiskIncreasingWorkButKeepsRecoveryAvailable() {
        let unresolved = HelperRemovalClientSafety.beginRemoteCleanup()
        let blocked: [HelperRemovalClientSafety.Operation] = [
            .install,
            .arm,
            .heartbeat,
            .forceSleep,
            .scheduleWake
        ]
        let recovery: [HelperRemovalClientSafety.Operation] = [
            .observe,
            .restoreNormalSleep,
            .cancelWake,
            .retryCleanup
        ]

        for operation in blocked {
            #expect(!HelperRemovalClientSafety.allows(operation, while: unresolved))
            #expect(HelperRemovalClientSafety.allows(operation, while: .open))
        }
        for operation in recovery {
            #expect(HelperRemovalClientSafety.allows(operation, while: unresolved))
            #expect(HelperRemovalClientSafety.allows(operation, while: .open))
        }
    }

    @Test func clientCommitsTheFenceBeforeDispatchAndClearsOnlyAfterFinalProof() throws {
        let client = try repositoryFile("App/Sources/Helper/HelperClient.swift")
        let refresh = try section(
            of: client,
            from: "    func refreshInstallState() async {",
            through: "    func install() async throws {"
        )
        let install = try section(
            of: client,
            from: "    func install() async throws {",
            through: "    func openApprovalSettings()"
        )
        let uninstall = try section(
            of: client,
            from: "    func uninstall() async throws {",
            through: "private func removalRegistrationState()"
        )
        let arm = try section(
            of: client,
            from: "    func arm(_ options: HelperArmOptions) async throws -> HelperReply {",
            through: "    func heartbeat() async throws -> HelperReply {"
        )
        let heartbeat = try section(
            of: client,
            from: "    func heartbeat() async throws -> HelperReply {",
            through: "    func disarm(_ options: HelperDisarmOptions) async throws -> HelperReply {"
        )
        let disarm = try section(
            of: client,
            from: "    func disarm(_ options: HelperDisarmOptions) async throws -> HelperReply {",
            through: "    func repairOverride() async throws -> HelperReply {"
        )
        let repair = try section(
            of: client,
            from: "    func repairOverride() async throws -> HelperReply {",
            through: "    func scheduleWake(_ date: Date?) async throws {"
        )
        let wake = try section(
            of: client,
            from: "    func scheduleWake(_ date: Date?) async throws {",
            through: "// MARK: - Connection plumbing"
        )

        let fence = try #require(uninstall.range(of: "beginRemoteCleanup()"))
        let dispatch = try #require(uninstall.range(of: "try await callForReply"))
        let finalProof = try #require(uninstall.range(of: "isUnregisterCompletionProven"))
        let resolution = try #require(uninstall.range(of: "HelperRemovalClientSafety.resolve("))
        let success = try #require(uninstall.range(of: "installState = .notInstalled"))
        let inactiveRefresh = try section(
            of: String(refresh),
            from: "if registrationStatus == .notRegistered {",
            through: "            guard HelperRemovalClientSafety.allows"
        )
        #expect(fence.lowerBound < dispatch.lowerBound)
        #expect(finalProof.lowerBound < resolution.lowerBound)
        #expect(resolution.lowerBound < success.lowerBound)

        #expect(refresh.contains("removalFence == .outcomeUnresolved"))
        #expect(refresh.contains("HelperRemovalClientSafety.resolve("))
        #expect(refresh.contains("PowerRegistry.sleepDisabled()"))
        #expect(inactiveRefresh.contains("HelperRemovalClientSafety.resolve("))
        #expect(refresh.contains("installState = .unknown"))
        #expect(!refresh.contains("registrationStatus != .enabled"))
        #expect(!uninstall.contains("removalFence = .open"))
        #expect(!client.contains("removalCommitted"))

        let installGuard = try #require(install.range(of: ".install, while: removalFence"))
        let register = try #require(install.range(of: "try service.register()"))
        #expect(installGuard.lowerBound < register.lowerBound)

        #expect(arm.contains("ensureOperationAllowed(.arm)"))
        #expect(heartbeat.contains("ensureOperationAllowed(.heartbeat)"))
        #expect(disarm.contains("options.forceSleep ? .forceSleep : .restoreNormalSleep"))
        #expect(repair.contains("ensureOperationAllowed(.restoreNormalSleep)"))
        #expect(wake.contains("date == nil ? .cancelWake : .scheduleWake"))
        #expect(!uninstall.contains("ensureOperationAllowed"))
    }
}
