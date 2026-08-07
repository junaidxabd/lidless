import Foundation
import Testing
@testable import LidlessCore

@Suite("Helper client admission safety")
struct HelperClientAdmissionSafetyTests {
    @Test(arguments: [
        nil,
        HelperClientIdentity(protocolVersion: 5, safetyRevision: 8),
        HelperClientIdentity(protocolVersion: 6, safetyRevision: 7),
        HelperClientIdentity(protocolVersion: 6, safetyRevision: 9),
    ])
    func staleOrMissingIdentityCannotIncreaseRisk(
        _ identity: HelperClientIdentity?
    ) {
        #expect(!HelperClientAdmissionSafety.allows(.arm, identity: identity))
        #expect(!HelperClientAdmissionSafety.allows(.scheduleWake, identity: identity))
        #expect(!HelperClientAdmissionSafety.allows(.forceSleep, identity: identity))
        #expect(HelperClientAdmissionSafety.allows(
            .restoreNormalSleep,
            identity: identity
        ))
        #expect(HelperClientAdmissionSafety.allows(.cancelWake, identity: identity))
        #expect(HelperClientAdmissionSafety.allows(.repairOverride, identity: identity))
    }

    @Test func exactCurrentIdentityIsAdmittedForEveryCurrentOperation() {
        #expect(HelperClientIdentity.current == HelperClientIdentity(
            protocolVersion: LidlessIDs.helperVersion,
            safetyRevision: LidlessIDs.helperSafetyRevision
        ))

        for operation in HelperClientOperation.allCases {
            #expect(HelperClientAdmissionSafety.allows(
                operation,
                identity: .current
            ))
        }
    }

    @Test func armPayloadDefaultsCurrentButDecodesLegacyAsMissing() throws {
        let encoded = try IPCCoding.encoder().encode(HelperArmOptions())
        let roundTrip = try #require(IPCCoding.decode(
            HelperArmOptions.self,
            from: encoded
        ))
        #expect(roundTrip.clientIdentity == .current)

        let legacy = Data(
            #"{"watchdogTTL":45,"lowPowerMode":false,"tcpKeepAlive":false}"#.utf8
        )
        let decodedLegacy = try #require(IPCCoding.decode(
            HelperArmOptions.self,
            from: legacy
        ))
        #expect(decodedLegacy.clientIdentity == nil)
    }

    @Test func disarmPayloadDefaultsCurrentButDecodesLegacyAsMissing() throws {
        let encoded = try IPCCoding.encoder().encode(HelperDisarmOptions(
            forceSleep: false,
            reason: "test"
        ))
        let roundTrip = try #require(IPCCoding.decode(
            HelperDisarmOptions.self,
            from: encoded
        ))
        #expect(roundTrip.clientIdentity == .current)

        let legacy = Data(
            #"{"forceSleep":false,"reason":"legacy"}"#.utf8
        )
        let decodedLegacy = try #require(IPCCoding.decode(
            HelperDisarmOptions.self,
            from: legacy
        ))
        #expect(decodedLegacy.clientIdentity == nil)
    }

    @Test func scheduledWakeRequestIsStructuredAndBackwardDecodable() throws {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let request = HelperScheduleWakeRequest(desiredDate: date)
        let encoded = try IPCCoding.encoder().encode(request)
        #expect(IPCCoding.decode(
            HelperScheduleWakeRequest.self,
            from: encoded
        ) == request)

        let legacy = try JSONSerialization.data(withJSONObject: [
            "desiredDate": date.timeIntervalSince1970,
        ])
        let decodedLegacy = try #require(IPCCoding.decode(
            HelperScheduleWakeRequest.self,
            from: legacy
        ))
        #expect(decodedLegacy.clientIdentity == nil)
        #expect(decodedLegacy.desiredDate == date)
    }

    @Test func appAndHelperWireIdentityBeforeRiskIncreasingMutation() throws {
        let ipc = try repositoryFile(
            "Packages/LidlessCore/Sources/LidlessCore/HelperIPC.swift"
        )
        let client = try repositoryFile("App/Sources/Helper/HelperClient.swift")
        let helper = try repositoryFile("Helper/HelperDaemon.swift")

        #expect(ipc.contains("func scheduleWakeRequest("))
        #expect(client.contains(
            "proxy.scheduleWakeRequest(IPCCoding.encode(request), reply: done)"
        ))
        #expect(!client.contains("proxy.scheduleWake(epoch, reply: done)"))

        let arm = try section(
            of: helper,
            from: "fileprivate func handleArm(",
            through: "private func rejectPreparedArm("
        )
        let armAdmission = try #require(arm.range(
            of: "HelperClientAdmissionSafety.allows("
        ))
        let armMutation = try #require(arm.range(
            of: "try PMSet.setSleepDisabled(true)"
        ))
        #expect(armAdmission.lowerBound < armMutation.lowerBound)

        let disarm = try section(
            of: helper,
            from: "fileprivate func handleDisarm(",
            through: "fileprivate func handleRepairOverride("
        )
        let forceSleepAdmission = try #require(disarm.range(
            of: "HelperClientAdmissionSafety.allows("
        ))
        let restore = try #require(disarm.range(of: "performRestore(record"))
        let sleepNow = try #require(disarm.range(of: "try PMSet.sleepNow()"))
        #expect(forceSleepAdmission.lowerBound < sleepNow.lowerBound)
        #expect(restore.lowerBound < sleepNow.lowerBound)
        #expect(disarm.contains(
            "normal sleep is restored; forced sleep was refused"
        ))

        let schedule = try section(
            of: helper,
            from: "fileprivate func handleScheduleWake(",
            through: "fileprivate func handleLegacyScheduleWake("
        )
        let scheduleAdmission = try #require(schedule.range(
            of: "HelperClientAdmissionSafety.allows("
        ))
        let scheduleMutation = try #require(schedule.range(
            of: "PMSet.scheduleWake"
        ))
        #expect(scheduleAdmission.lowerBound < scheduleMutation.lowerBound)

        let legacy = try section(
            of: helper,
            from: "fileprivate func handleLegacyScheduleWake(",
            through: "fileprivate func enqueueScheduleWake("
        )
        #expect(legacy.contains("guard epoch <= 0 else"))
        #expect(!legacy.contains("PMSet.scheduleWake"))
    }

    private func repositoryFile(_ relativePath: String) throws -> String {
        var directory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
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
}
