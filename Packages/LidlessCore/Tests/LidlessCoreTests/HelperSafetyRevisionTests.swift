import Foundation
import Testing
@testable import LidlessCore

@Suite("Helper safety revision")
struct HelperSafetyRevisionTests {
    private enum RevisionField {
        case missing
        case value(Int)
    }

    private struct LegacyStatus: Decodable {
        let helperVersion: Int
        let armed: Bool
        let sleepDisabled: Bool
    }

    private func decodedReply(
        revision: RevisionField,
        ok: Bool = true,
        armed: Bool,
        sleepDisabled: Bool
    ) throws -> HelperReply {
        var status: [String: Any] = [
            "helperVersion": 6,
            "armed": armed,
            "sleepDisabled": sleepDisabled,
            "sleepStateVerified": true,
            "restorePending": false,
        ]
        if case .value(let value) = revision {
            status["helperSafetyRevision"] = value
        }
        let data = try JSONSerialization.data(withJSONObject: [
            "ok": ok,
            "status": status,
        ])
        return try #require(IPCCoding.decode(HelperReply.self, from: data))
    }

    @Test func exactRevisionIsRequiredThroughEveryProofAndRecoveryWrapper() throws {
        let incompatible: [RevisionField] = [
            .missing,
            .value(0),
            .value(1),
            .value(2),
            .value(3),
            .value(4),
            .value(5),
            .value(6),
            .value(8),
        ]
        for revision in incompatible {
            let armed = try decodedReply(
                revision: revision,
                armed: true,
                sleepDisabled: true
            )
            let restored = try decodedReply(
                revision: revision,
                armed: false,
                sleepDisabled: false
            )
            let outsideOverride = try decodedReply(
                revision: revision,
                ok: false,
                armed: false,
                sleepDisabled: true
            )

            switch revision {
            case .missing:
                #expect(armed.status.helperSafetyRevision == nil)
            case .value(let value):
                #expect(armed.status.helperSafetyRevision == value)
            }

            #expect(!SleepOverrideSafety.isCurrentHelper(armed.status))
            #expect(!SleepOverrideSafety.isArmProven(armed.status))
            #expect(!SleepOverrideSafety.isArmProven(armed))
            #expect(!SleepOverrideSafety.isRestoreProven(restored.status))
            #expect(!SleepOverrideSafety.isRestoreProven(restored))
            #expect(!SleepOverrideSafety.isRestoreProven(
                restored.status,
                independentlyObserved: false
            ))
            #expect(!SleepOverrideSafety.isRestoreProven(
                restored,
                independentlyObserved: false
            ))
            #expect(!SleepOverrideSafety.isUnownedExternalOverride(
                outsideOverride.status,
                independentlyObserved: true
            ))
            #expect(SleepOverrideSafety.failedArmDisposition(
                outsideOverride,
                independentlyObserved: true
            ) == .recoveryRequired)

            var gate = NonSleepRestoreGate()
            let generation = gate.begin()
            #expect(gate.completeUnownedExternalOverride(
                generation: generation,
                helperReply: outsideOverride,
                independentlyObserved: true,
                armRequestsInFlight: 0,
                establishedSessionExists: false
            ) == .retry)
            #expect(gate.owns(generation))

            #expect(HelperRemovalSafety.removalAction(
                .enabled,
                helperReply: restored,
                independentlyObserved: false
            ) == nil)
        }
    }

    @Test func currentRevisionCompletesTheSameProofAndRecoveryPaths() throws {
        let armed = try decodedReply(
            revision: .value(7),
            armed: true,
            sleepDisabled: true
        )
        let restored = try decodedReply(
            revision: .value(7),
            armed: false,
            sleepDisabled: false
        )
        let outsideOverride = try decodedReply(
            revision: .value(7),
            ok: false,
            armed: false,
            sleepDisabled: true
        )

        #expect(LidlessIDs.helperSafetyRevision == 7)
        #expect(armed.status.helperSafetyRevision == LidlessIDs.helperSafetyRevision)
        #expect(SleepOverrideSafety.isCurrentHelper(armed.status))
        #expect(SleepOverrideSafety.isArmProven(armed.status))
        #expect(SleepOverrideSafety.isArmProven(armed))
        #expect(SleepOverrideSafety.isRestoreProven(restored.status))
        #expect(SleepOverrideSafety.isRestoreProven(restored))
        #expect(SleepOverrideSafety.isRestoreProven(
            restored.status,
            independentlyObserved: false
        ))
        #expect(SleepOverrideSafety.isRestoreProven(
            restored,
            independentlyObserved: false
        ))
        #expect(SleepOverrideSafety.isUnownedExternalOverride(
            outsideOverride.status,
            independentlyObserved: true
        ))
        #expect(SleepOverrideSafety.failedArmDisposition(
            outsideOverride,
            independentlyObserved: true
        ) == .externalOverride)

        var gate = NonSleepRestoreGate()
        let generation = gate.begin()
        #expect(gate.completeUnownedExternalOverride(
            generation: generation,
            helperReply: outsideOverride,
            independentlyObserved: true,
            armRequestsInFlight: 0,
            establishedSessionExists: false
        ) == .complete)
        #expect(gate.isCompleted(generation))

        #expect(HelperRemovalSafety.removalAction(
            .enabled,
            helperReply: restored,
            independentlyObserved: false
        ) == .unregister)
    }

    @Test func revisionEncodingIsExplicitAndWireCompatible() throws {
        let current = try decodedReply(
            revision: .value(7),
            armed: true,
            sleepDisabled: true
        )
        let encodedReply = try IPCCoding.encoder().encode(current)
        let object = try #require(
            JSONSerialization.jsonObject(with: encodedReply) as? [String: Any]
        )
        let status = try #require(object["status"] as? [String: Any])
        #expect(status["helperSafetyRevision"] as? Int == LidlessIDs.helperSafetyRevision)

        let encodedStatus = try IPCCoding.encoder().encode(current.status)
        let legacy = try JSONDecoder().decode(LegacyStatus.self, from: encodedStatus)
        #expect(legacy.helperVersion == LidlessIDs.helperVersion)
        #expect(legacy.armed)
        #expect(legacy.sleepDisabled)

        let wrongType = try JSONSerialization.data(withJSONObject: [
            "helperVersion": 6,
            "helperSafetyRevision": "7",
            "armed": false,
            "sleepDisabled": false,
        ])
        #expect(IPCCoding.decode(HelperStatus.self, from: wrongType) == nil)
    }

    @Test func productionSourcesPublishAndRequireTheExactRevision() throws {
        let ids = try repositoryFile(
            "Packages/LidlessCore/Sources/LidlessCore/LidlessIDs.swift"
        )
        let ipc = try repositoryFile(
            "Packages/LidlessCore/Sources/LidlessCore/HelperIPC.swift"
        )
        let safety = try repositoryFile(
            "Packages/LidlessCore/Sources/LidlessCore/SleepOverrideSafety.swift"
        )
        let helper = try repositoryFile("Helper/HelperDaemon.swift")
        let client = try repositoryFile("App/Sources/Helper/HelperClient.swift")
        let simulation = try repositoryFile("App/Sources/Simulation/Simulation.swift")

        #expect(ids.contains("public static let helperSafetyRevision = 7"))
        #expect(ipc.contains("helperSafetyRevision: Int?,"))
        #expect(!ipc.contains(
            "helperSafetyRevision: Int? = LidlessIDs.helperSafetyRevision"
        ))
        #expect(safety.contains(
            "status.helperSafetyRevision == LidlessIDs.helperSafetyRevision"
        ))

        let implementedRevision = try #require(firstCapturedInteger(
            in: helper,
            pattern: #"implementedSafetyRevision\s*=\s*(\d+)"#
        ))
        #expect(implementedRevision == LidlessIDs.helperSafetyRevision)
        #expect(helper.contains(
            "helperSafetyRevision: Self.implementedSafetyRevision"
        ))
        #expect(simulation.contains(
            "helperSafetyRevision: LidlessIDs.helperSafetyRevision"
        ))

        let refresh = try section(
            of: client,
            from: "    func refreshInstallState() async {",
            through: "    func install() async throws {"
        )
        let normalizedRefresh = normalize(refresh)
        #expect(normalizedRefresh.contains(
            "case .enabled: do { let status = try await status() "
                + "installState = SleepOverrideSafety.isCurrentHelper(status) "
                + "? .ready(helperVersion: status.helperVersion) "
                + ": .stale(helperVersion: status.helperVersion)"
        ))
        #expect(!refresh.contains(
            "installState = status.helperVersion == LidlessIDs.helperVersion"
        ))

        let scheduleWake = try section(
            of: client,
            from: "    func scheduleWake(_ date: Date?) async throws {",
            through: "private func ensureOperationAllowed("
        )
        #expect(scheduleWake.contains(
            "SleepOverrideSafety.isCurrentHelper(reply.status)"
        ))
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

    private func normalize(_ source: some StringProtocol) -> String {
        String(source).replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression
        )
    }

    private func firstCapturedInteger(
        in source: String,
        pattern: String
    ) -> Int? {
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(
                  in: source,
                  range: NSRange(source.startIndex..., in: source)
              ),
              let range = Range(match.range(at: 1), in: source)
        else { return nil }
        return Int(source[range])
    }
}
