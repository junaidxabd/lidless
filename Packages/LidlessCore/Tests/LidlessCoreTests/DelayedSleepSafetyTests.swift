import Foundation
import Testing
@testable import LidlessCore

@Suite("Delayed force-sleep safety")
struct DelayedSleepSafetyTests {
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

    @Test func onlyTheUnchangedQuiescentLifecycleMayForceSleep() {
        let captured = UUID(uuidString: "00000000-0000-0000-0000-000000000007")!
        let newer = UUID(uuidString: "00000000-0000-0000-0000-000000000008")!
        let created: UInt64 = 1_000_000_000
        let onTime = created + DelayedSleepSafety.maximumRequestAgeNanoseconds
        #expect(DelayedSleepSafety.allowsForceSleep(
            capturedGeneration: captured,
            currentGeneration: captured,
            requestCreatedAtNanoseconds: created,
            currentNanoseconds: onTime,
            hasActiveSentinel: false,
            hasPendingRestore: false,
            powerObservationAvailable: true,
            observedClamshellClosed: true,
            observedSleepDisabled: false
        ))

        #expect(!DelayedSleepSafety.allowsForceSleep(
            capturedGeneration: captured,
            currentGeneration: newer,
            requestCreatedAtNanoseconds: created,
            currentNanoseconds: onTime,
            hasActiveSentinel: false,
            hasPendingRestore: false,
            powerObservationAvailable: true,
            observedClamshellClosed: true,
            observedSleepDisabled: false
        ))
        #expect(!DelayedSleepSafety.allowsForceSleep(
            capturedGeneration: captured,
            currentGeneration: captured,
            requestCreatedAtNanoseconds: created,
            currentNanoseconds: onTime,
            hasActiveSentinel: true,
            hasPendingRestore: false,
            powerObservationAvailable: true,
            observedClamshellClosed: true,
            observedSleepDisabled: false
        ))
        #expect(!DelayedSleepSafety.allowsForceSleep(
            capturedGeneration: captured,
            currentGeneration: captured,
            requestCreatedAtNanoseconds: created,
            currentNanoseconds: onTime,
            hasActiveSentinel: false,
            hasPendingRestore: true,
            powerObservationAvailable: true,
            observedClamshellClosed: true,
            observedSleepDisabled: false
        ))
        #expect(!DelayedSleepSafety.allowsForceSleep(
            capturedGeneration: captured,
            currentGeneration: captured,
            requestCreatedAtNanoseconds: created,
            currentNanoseconds: onTime,
            hasActiveSentinel: false,
            hasPendingRestore: false,
            powerObservationAvailable: false,
            observedClamshellClosed: true,
            observedSleepDisabled: false
        ))
    }

    @Test func staleOrUnverifiedPhysicalAuthorizationFailsClosed() {
        let generation = UUID(uuidString: "00000000-0000-0000-0000-000000000009")!
        let created: UInt64 = 10_000_000_000

        func allows(
            now: UInt64,
            lid: Bool? = true,
            sleepDisabled: Bool? = false
        ) -> Bool {
            DelayedSleepSafety.allowsForceSleep(
                capturedGeneration: generation,
                currentGeneration: generation,
                requestCreatedAtNanoseconds: created,
                currentNanoseconds: now,
                hasActiveSentinel: false,
                hasPendingRestore: false,
                powerObservationAvailable: true,
                observedClamshellClosed: lid,
                observedSleepDisabled: sleepDisabled
            )
        }

        #expect(!allows(
            now: created + DelayedSleepSafety.maximumRequestAgeNanoseconds + 1
        ))
        #expect(!allows(now: created - 1))
        #expect(!allows(now: created + 3_000_000_000, lid: false))
        #expect(!allows(now: created + 3_000_000_000, lid: nil))
        #expect(!allows(now: created + 3_000_000_000, sleepDisabled: true))
        #expect(!allows(now: created + 3_000_000_000, sleepDisabled: nil))
    }

    @Test func helperInvalidatesAndChecksTheDelayedRequestGeneration() throws {
        let helper = try repositoryFile("Helper/HelperDaemon.swift")
        let arm = try section(
            of: helper,
            from: "fileprivate func handleArm(",
            through: "private func rejectPreparedArm("
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
        let uninstall = try section(
            of: helper,
            from: "fileprivate func handleUninstall(",
            through: "fileprivate func handleLegacyUninstall("
        )
        let power = try section(
            of: helper,
            from: "private func handlePowerMessage(",
            through: "// MARK: - Arm / restore core"
        )

        #expect(helper.contains("private var lifecycleGeneration = UUID()"))
        #expect(helper.contains("private var powerObservationAvailable = false"))
        #expect(helper.contains("powerObservationAvailable = true"))
        #expect(arm.contains("advanceLifecycle()"))
        #expect(disarm.contains("advanceLifecycle()"))
        #expect(repair.contains("advanceLifecycle()"))
        #expect(!uninstall.contains("advanceLifecycle()"))
        #expect(power.contains("advanceLifecycle()"))
        #expect(disarm.contains("let forceSleepGeneration = lifecycleGeneration"))
        #expect(disarm.contains("let forceSleepCreatedAt = DispatchTime.now().uptimeNanoseconds"))
        #expect(disarm.contains("DelayedSleepSafety.allowsForceSleep("))
        #expect(disarm.contains("hasActiveSentinel: sentinel != nil"))
        #expect(disarm.contains("hasPendingRestore: restorePending != nil"))
        #expect(disarm.contains("powerObservationAvailable: powerObservationAvailable"))
        #expect(disarm.contains("let observedClamshellClosed = PowerRegistry.clamshellClosed()"))
        #expect(disarm.contains("let observedSleepDisabled = PMSet.readSleepDisabled()"))
        #expect(disarm.contains("let authorizationCheckedAt = DispatchTime.now().uptimeNanoseconds"))

        let advance = try #require(disarm.range(of: "advanceLifecycle()"))
        let proof = try #require(disarm.range(of: "let restored = SleepOverrideSafety.isRestoreProven(status)"))
        let capture = try #require(disarm.range(of: "let forceSleepGeneration = lifecycleGeneration"))
        let scheduling = try #require(disarm.range(of: "queue.asyncAfter"))
        let lidObservation = try #require(disarm.range(of: "let observedClamshellClosed = PowerRegistry.clamshellClosed()"))
        let overrideObservation = try #require(disarm.range(of: "let observedSleepDisabled = PMSet.readSleepDisabled()"))
        let checkedAt = try #require(disarm.range(of: "let authorizationCheckedAt = DispatchTime.now().uptimeNanoseconds"))
        let authorization = try #require(disarm.range(of: "DelayedSleepSafety.allowsForceSleep("))
        let mutation = try #require(disarm.range(of: "try PMSet.sleepNow()"))
        #expect(advance.lowerBound < proof.lowerBound)
        #expect(proof.lowerBound < capture.lowerBound)
        #expect(capture.lowerBound < scheduling.lowerBound)
        #expect(scheduling.lowerBound < lidObservation.lowerBound)
        #expect(lidObservation.lowerBound < overrideObservation.lowerBound)
        #expect(overrideObservation.lowerBound < checkedAt.lowerBound)
        #expect(checkedAt.lowerBound < authorization.lowerBound)
        #expect(authorization.lowerBound < mutation.lowerBound)
    }
}
