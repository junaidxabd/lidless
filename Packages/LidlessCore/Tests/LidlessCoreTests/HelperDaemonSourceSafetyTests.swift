import Foundation
import Testing

@Suite("Helper daemon source safety")
struct HelperDaemonSourceSafetyTests {
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
              let endRange = source.range(of: end, range: startRange.upperBound..<source.endIndex) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return source[startRange.lowerBound..<endRange.upperBound]
    }

    @Test func activeSessionPathsNeverRewriteTheRecoverySentinel() throws {
        let source = try repositoryFile("Helper/HelperDaemon.swift")
        let rearm = try section(
            of: source,
            from: "if var current = sentinel {",
            through: "// Snapshot optional settings"
        )
        let verifiedArm = try section(
            of: source,
            from: "let armReadback = PMSet.readSleepDisabled()",
            through: "// Best-effort extras"
        )
        let heartbeat = try section(
            of: source,
            from: "fileprivate func handleHeartbeat",
            through: "fileprivate func handleDisarm"
        )

        #expect(!rearm.contains("writeSentinel"))
        #expect(!verifiedArm.contains("writeSentinel"))
        #expect(!heartbeat.contains("writeSentinel"))
    }

    @Test func blockingCommandBoundsAreWiredIntoPMSet() throws {
        let source = try repositoryFile("Helper/PMSet.swift")

        #expect(source.contains("HelperSupervisionTiming.pmsetCommandTimeout"))
        #expect(source.contains("HelperSupervisionTiming.forcedTerminationGrace"))
        #expect(source.contains("let killResult = kill"))
        #expect(source.contains("killResult == 0 || killErrno == ESRCH"))
        #expect(!source.contains("timeout: TimeInterval = 20"))
    }

    @Test func supervisionPrecedesEnableAndSuccessPrecedesOptionalWork() throws {
        let source = try repositoryFile("Helper/HelperDaemon.swift")
        let freshArm = try section(
            of: source,
            from: "// Fresh arm.",
            through: "// Best-effort extras"
        )

        let sentinelWrite = try #require(freshArm.range(of: "try writeSentinel(record)"))
        let afterSentinelWrite = freshArm[sentinelWrite.upperBound...]
        let ownershipConfirmation = try #require(afterSentinelWrite.range(
            of: "SleepOverrideSafety.preflight(observed: PMSet.readSleepDisabled())"
        ))
        let memoryOwner = try #require(freshArm.range(of: "sentinel = record"))
        let enable = try #require(freshArm.range(of: "try PMSet.setSleepDisabled(true)"))
        let proof = try #require(freshArm.range(of: "SleepOverrideSafety.isArmProven(result)"))
        let successReply = try #require(freshArm.range(of: "reply(IPCCoding.encode(result))"))

        #expect(sentinelWrite.lowerBound < memoryOwner.lowerBound)
        #expect(ownershipConfirmation.lowerBound < memoryOwner.lowerBound)
        #expect(memoryOwner.lowerBound < enable.lowerBound)
        #expect(enable.lowerBound < proof.lowerBound)
        #expect(proof.lowerBound < successReply.lowerBound)
    }

    @Test func wakeSchedulingCannotBlockActiveSupervision() throws {
        let source = try repositoryFile("Helper/HelperDaemon.swift")
        let schedule = try section(
            of: source,
            from: "fileprivate func handleScheduleWake",
            through: "fileprivate func handleUninstall"
        )
        let guardPosition = try #require(schedule.range(
            of: "guard sentinel == nil, restorePending == nil"
        ))
        let commandPosition = try #require(schedule.range(of: "PMSet.scheduleWake"))

        #expect(guardPosition.lowerBound < commandPosition.lowerBound)
    }
}
