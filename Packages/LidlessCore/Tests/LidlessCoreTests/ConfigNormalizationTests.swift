import Foundation
import Testing
@testable import LidlessCore

@Suite("Cutoff configuration normalization")
struct ConfigNormalizationTests {
    @Test func extremeConfigurationAlwaysNormalizesToSafeFiniteBounds() {
        var config = CutoffConfig()
        config.batteryFloorPercent = .max
        config.thermalSpeedLimitFloor = .min
        config.thermalStrikesRequired = .max
        config.durationSeconds = .infinity
        config.offTime = HMTime(hour: .max, minute: .min)

        let value = config.normalized()

        #expect(value.batteryFloorPercent == 50)
        #expect(value.thermalSpeedLimitFloor == 20)
        #expect(value.thermalStrikesRequired == 5)
        #expect(value.durationSeconds == 24 * 3600)
        #expect(value.offTime == HMTime(hour: 23, minute: 0))
    }

    @Test func oppositeExtremesClampToTheOtherSafeBounds() {
        var config = CutoffConfig()
        config.batteryFloorPercent = .min
        config.thermalSpeedLimitFloor = .max
        config.thermalStrikesRequired = .min
        config.durationSeconds = 0
        config.offTime = HMTime(hour: .min, minute: .max)

        let value = config.normalized()

        #expect(value.batteryFloorPercent == 5)
        #expect(value.thermalSpeedLimitFloor == 90)
        #expect(value.thermalStrikesRequired == 1)
        #expect(value.durationSeconds == 30 * 60)
        #expect(value.offTime == HMTime(hour: 0, minute: 59))
    }

    @Test(arguments: [
        TimeInterval.nan,
        TimeInterval.infinity,
        -TimeInterval.infinity,
    ])
    func nonFiniteDurationsFailClosedToTheMaximum(_ duration: TimeInterval) {
        var config = CutoffConfig()
        config.durationSeconds = duration

        #expect(config.normalized().durationSeconds == 24 * 3600)
    }

    @Test func applyingOverridesReturnsANormalizedConfiguration() {
        var base = CutoffConfig()
        base.thermalSpeedLimitFloor = .max
        base.thermalStrikesRequired = .max

        let value = base.applying(SessionOverrides(
            batteryFloorPercent: .min,
            durationSeconds: .infinity,
            offTime: HMTime(hour: .max, minute: .min)
        ))

        #expect(value.batteryFloorPercent == 5)
        #expect(value.thermalSpeedLimitFloor == 90)
        #expect(value.thermalStrikesRequired == 5)
        #expect(value.durationSeconds == 24 * 3600)
        #expect(value.offTime == HMTime(hour: 23, minute: 0))
        #expect(value.normalized() == value)
    }

    @Test func decodingNormalizesUntrustedPersistedValues() throws {
        var config = CutoffConfig()
        config.batteryFloorPercent = .max
        config.thermalSpeedLimitFloor = .min
        config.thermalStrikesRequired = .max
        config.durationSeconds = 1
        config.offTime = HMTime(hour: .max, minute: .min)

        let encoded = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(CutoffConfig.self, from: encoded)

        #expect(decoded == config.normalized())
    }

    @Test func thermalStrikeTrackingConsumesTheNormalizedSpeedFloor() {
        let now = Date(timeIntervalSince1970: 1_785_000_000)
        var config = CutoffConfig()
        config.thermalSpeedLimitFloor = .min
        var tracker = ThermalStrikeTracker()

        let strikes = tracker.observe(
            config: config,
            thermal: ThermalReading(
                warningLevel: 0,
                cpuSpeedLimit: 19,
                sampledAt: now
            ),
            processThermal: .nominal,
            at: now
        )

        #expect(strikes == 1)
    }

    @Test func engineNormalizesBeforeOverflowSensitiveComparisons() {
        let now = Date(timeIntervalSince1970: 1_785_000_000)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        var armConfig = CutoffConfig()
        armConfig.thermalEnabled = false
        armConfig.batteryFloorPercent = .max
        #expect(CutoffEngine.assessArm(
            config: armConfig,
            battery: BatterySnapshot(
                percent: 50,
                state: .battery,
                isCharging: false,
                sampledAt: now
            ),
            thermal: nil,
            processThermal: .nominal,
            at: now
        ) == .refusedBelowFloor(percent: 50, floor: 50))

        var evaluationConfig = CutoffConfig()
        evaluationConfig.batteryFloorEnabled = false
        evaluationConfig.thermalStrikesRequired = .max
        let result = CutoffEngine.evaluate(
            config: evaluationConfig,
            armedAt: now,
            now: now,
            battery: BatterySnapshot(
                percent: 80,
                state: .ac,
                isCharging: false,
                sampledAt: now
            ),
            thermal: ThermalReading(warningLevel: 1, sampledAt: now),
            processThermal: .nominal,
            thermalStrikes: .max,
            calendar: calendar
        )
        #expect(result.fired == [.thermal(detail: "Thermal warning level 1")])
    }
}
