import Foundation
import Testing
@testable import LidlessCore

@Suite("Core smoke")
struct SmokeTests {
    @Test func defaultsMatchSpec() {
        let config = CutoffConfig()
        #expect(config.batteryFloorEnabled)
        #expect(config.batteryFloorPercent == 10)
        #expect(config.thermalEnabled)
        #expect(config.thermalSpeedLimitFloor == 60)
        #expect(!config.durationEnabled)
        #expect(config.durationSeconds == 4 * 3600)
        #expect(!config.offTimeEnabled)
        #expect(config.offTime == HMTime(hour: 7, minute: 0))
    }

    @Test func ipcRoundTrip() {
        let status = HelperStatus(
            helperVersion: LidlessIDs.helperVersion,
            armed: true,
            sleepDisabled: true,
            armedSince: Date(timeIntervalSince1970: 1_700_000_000),
            watchdogDeadline: Date(timeIntervalSince1970: 1_700_000_045)
        )
        let reply = HelperReply(ok: true, status: status)
        let data = IPCCoding.encode(reply)
        let decoded = IPCCoding.decode(HelperReply.self, from: data)
        #expect(decoded == reply)
    }
}
