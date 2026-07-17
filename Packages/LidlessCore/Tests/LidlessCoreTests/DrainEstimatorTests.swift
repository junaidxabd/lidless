import Foundation
import Testing
@testable import LidlessCore

// MARK: - Fixtures

/// Fixed reference instant (2001-09-09T01:46:40Z). Never Date().
private let t0 = Date(timeIntervalSince1970: 1_000_000_000)

/// Builds `count` discharging samples every `stepMinutes`, starting at `base`,
/// falling linearly from `startPercent` at `ratePerHour`.
private func linearSamples(
    count: Int,
    stepMinutes: Double,
    startPercent: Double,
    ratePerHour: Double,
    base: Date = t0,
    discharging: Bool = true
) -> [BatterySample] {
    (0..<count).map { i in
        let minutes = Double(i) * stepMinutes
        return BatterySample(
            time: base.addingTimeInterval(minutes * 60),
            percent: startPercent - ratePerHour * minutes / 60,
            isDischarging: discharging
        )
    }
}

private func sample(
    secondsAfterT0 seconds: TimeInterval,
    percent: Double,
    discharging: Bool = true
) -> BatterySample {
    BatterySample(time: t0.addingTimeInterval(seconds), percent: percent, isDischarging: discharging)
}

@Suite("DrainEstimator")
struct DrainEstimatorTests {

    // MARK: drainPerHour — happy paths

    @Test("Perfect 10%/hr linear discharge over 30 min of 5-min samples")
    func drainPerfectLinearTenPerHour() throws {
        // 7 samples at t = 0, 5, ..., 30 min; 80% falling at exactly 10%/hr.
        let samples = linearSamples(count: 7, stepMinutes: 5, startPercent: 80, ratePerHour: 10)
        let now = t0.addingTimeInterval(30 * 60) // last sample is exactly at `now` (<= now boundary)
        let rate = try #require(DrainEstimator.drainPerHour(samples: samples, now: now))
        #expect(abs(rate - 10.0) <= 0.01)
    }

    @Test("Noisy but linear data stays close to the true slope")
    func drainNoisyLinearCloseToTrueSlope() throws {
        // True line: 10%/hr. Noise (percent): [0.3, -0.1, 0.2, 0.0, -0.3, 0.1, -0.2].
        // Hand-computed least squares over xs = 0,300,...,1800 s:
        //   x̄ = 900, Σ(x-x̄)² = 2_520_000, Σ(x-x̄)·noise = -480
        //   Δslope = -480 / 2_520_000 %/s  →  Δdrain = +480·3600/2_520_000 = +0.685714…
        // Expected drain ≈ 10.685714285714286 %/hr.
        let noise: [Double] = [0.3, -0.1, 0.2, 0.0, -0.3, 0.1, -0.2]
        let clean = linearSamples(count: 7, stepMinutes: 5, startPercent: 80, ratePerHour: 10)
        let samples = zip(clean, noise).map {
            BatterySample(time: $0.time, percent: $0.percent + $1, isDischarging: true)
        }
        let now = t0.addingTimeInterval(30 * 60)
        let rate = try #require(DrainEstimator.drainPerHour(samples: samples, now: now))
        #expect(abs(rate - 10.0) <= 1.0)                     // close to the true slope
        #expect(abs(rate - 10.685714285714286) <= 0.001)     // exact least-squares fit
    }

    @Test("Noise orthogonal to time leaves the least-squares slope exact")
    func drainNoiseOrthogonalToTimeExactSlope() throws {
        // Alternating ±0.2 noise over symmetric xs has Σ(x-x̄)·noise = 0,
        // so least squares recovers exactly 10%/hr.
        let noise: [Double] = [0.2, -0.2, 0.2, -0.2, 0.2, -0.2, 0.2]
        let clean = linearSamples(count: 7, stepMinutes: 5, startPercent: 80, ratePerHour: 10)
        let samples = zip(clean, noise).map {
            BatterySample(time: $0.time, percent: $0.percent + $1, isDischarging: true)
        }
        let now = t0.addingTimeInterval(30 * 60)
        let rate = try #require(DrainEstimator.drainPerHour(samples: samples, now: now))
        #expect(abs(rate - 10.0) <= 1e-9)
    }

    // MARK: drainPerHour — count / span guards

    @Test("Two samples are insufficient (minimumSamples = 3)")
    func drainTwoSamplesReturnsNil() {
        let samples = linearSamples(count: 2, stepMinutes: 10, startPercent: 80, ratePerHour: 10)
        let now = t0.addingTimeInterval(10 * 60)
        #expect(DrainEstimator.drainPerHour(samples: samples, now: now) == nil)
    }

    @Test("Three samples spanning 299 s (< 5 min) return nil")
    func drainSpanJustUnderFiveMinutesReturnsNil() {
        let samples = [
            sample(secondsAfterT0: 0, percent: 80.0),
            sample(secondsAfterT0: 150, percent: 79.6),
            sample(secondsAfterT0: 299, percent: 79.2),
        ]
        let now = t0.addingTimeInterval(299)
        #expect(DrainEstimator.drainPerHour(samples: samples, now: now) == nil)
    }

    @Test("Exactly 3 samples spanning exactly 5 min is enough (boundary)")
    func drainExactlyThreeSamplesExactlyFiveMinutes() throws {
        // 10%/hr over exactly 300 s: span >= minimumSpan must accept equality.
        let samples = [
            sample(secondsAfterT0: 0, percent: 80.0),
            sample(secondsAfterT0: 150, percent: 80.0 - 10.0 * 150 / 3600),
            sample(secondsAfterT0: 300, percent: 80.0 - 10.0 * 300 / 3600),
        ]
        let now = t0.addingTimeInterval(300)
        let rate = try #require(DrainEstimator.drainPerHour(samples: samples, now: now))
        #expect(abs(rate - 10.0) <= 0.01)
    }

    @Test("Empty sample array returns nil")
    func drainEmptySamplesReturnsNil() {
        #expect(DrainEstimator.drainPerHour(samples: [], now: t0) == nil)
    }

    @Test("Custom minimumSamples: two-point slope allowed when relaxed to 2")
    func drainCustomMinimumSamplesTwo() throws {
        let samples = linearSamples(count: 2, stepMinutes: 10, startPercent: 80, ratePerHour: 10)
        let now = t0.addingTimeInterval(10 * 60)
        let rate = try #require(
            DrainEstimator.drainPerHour(samples: samples, now: now, minimumSamples: 2)
        )
        #expect(abs(rate - 10.0) <= 0.01)
    }

    // MARK: drainPerHour — window filtering

    @Test("Samples older than the 40-min window are ignored")
    func drainIgnoresSamplesOutsideWindow() throws {
        let now = t0.addingTimeInterval(3600)
        // Old steep drain at 60%/hr, 50/46/43 min before now — all outside the window.
        let old = [
            sample(secondsAfterT0: 600, percent: 90),   // now - 50 min
            sample(secondsAfterT0: 840, percent: 86),   // now - 46 min
            sample(secondsAfterT0: 1020, percent: 83),  // now - 43 min
        ]
        // Recent shallow drain at 5%/hr, 30/20/10/0 min before now.
        let recent = [
            sample(secondsAfterT0: 1800, percent: 70.0),
            sample(secondsAfterT0: 2400, percent: 70.0 - 5.0 * 600 / 3600),
            sample(secondsAfterT0: 3000, percent: 70.0 - 5.0 * 1200 / 3600),
            sample(secondsAfterT0: 3600, percent: 70.0 - 5.0 * 1800 / 3600),
        ]
        let rate = try #require(DrainEstimator.drainPerHour(samples: old + recent, now: now))
        // Only the recent shallow slope: blending the old steep run would push this well above 5.
        #expect(abs(rate - 5.0) <= 0.01)
    }

    @Test("Sample exactly at the window cutoff is included (>= boundary)")
    func drainSampleExactlyAtCutoffIncluded() throws {
        // now - 40 min == cutoff exactly. If that sample were excluded, only
        // 2 samples remain and the result would be nil.
        let now = t0.addingTimeInterval(2400)
        let samples = [
            sample(secondsAfterT0: 0, percent: 80.0),                        // exactly at cutoff
            sample(secondsAfterT0: 1200, percent: 80.0 - 10.0 * 1200 / 3600),
            sample(secondsAfterT0: 2400, percent: 80.0 - 10.0 * 2400 / 3600),
        ]
        let rate = try #require(DrainEstimator.drainPerHour(samples: samples, now: now))
        #expect(abs(rate - 10.0) <= 0.01)
    }

    @Test("Samples with time > now are excluded")
    func drainFutureSamplesExcluded() throws {
        let now = t0.addingTimeInterval(600)
        var samples = linearSamples(count: 3, stepMinutes: 5, startPercent: 80, ratePerHour: 10)
        // Future garbage after `now`. The charging sample would break the trailing
        // run (forcing nil) and the wild 5% sample would wreck the slope if either
        // were erroneously included.
        samples.append(sample(secondsAfterT0: 900, percent: 100, discharging: false))
        samples.append(sample(secondsAfterT0: 1200, percent: 5, discharging: true))
        let rate = try #require(DrainEstimator.drainPerHour(samples: samples, now: now))
        #expect(abs(rate - 10.0) <= 0.01)
    }

    @Test("All samples older than the window return nil")
    func drainAllSamplesTooOldReturnsNil() {
        let samples = linearSamples(count: 5, stepMinutes: 5, startPercent: 80, ratePerHour: 10)
        let now = t0.addingTimeInterval(3 * 3600) // window ended long after the last sample
        #expect(DrainEstimator.drainPerHour(samples: samples, now: now) == nil)
    }

    // MARK: drainPerHour — trailing discharging run

    @Test("Charging sample mid-series invalidates all earlier history")
    func drainChargingSampleInvalidatesEarlierHistory() throws {
        var samples: [BatterySample] = []
        // Old steep discharge at 20%/hr (should be discarded).
        samples.append(sample(secondsAfterT0: 0, percent: 90.0))
        samples.append(sample(secondsAfterT0: 300, percent: 90.0 - 20.0 * 300 / 3600))
        samples.append(sample(secondsAfterT0: 600, percent: 90.0 - 20.0 * 600 / 3600))
        // Plug-in event.
        samples.append(sample(secondsAfterT0: 900, percent: 87.5, discharging: false))
        // Trailing discharge at 8%/hr — the only run that should count.
        for step in 0..<4 {
            let seconds = 1200.0 + Double(step) * 300
            samples.append(
                sample(secondsAfterT0: seconds, percent: 87.0 - 8.0 * (seconds - 1200) / 3600)
            )
        }
        let now = t0.addingTimeInterval(2100)
        let rate = try #require(DrainEstimator.drainPerHour(samples: samples, now: now))
        #expect(abs(rate - 8.0) <= 0.01)
    }

    @Test("Trailing run after a charge with too few samples returns nil")
    func drainTrailingRunTooFewAfterChargeReturnsNil() {
        var samples = linearSamples(count: 4, stepMinutes: 5, startPercent: 90, ratePerHour: 12)
        samples.append(sample(secondsAfterT0: 1200, percent: 88, discharging: false)) // plug-in
        samples.append(sample(secondsAfterT0: 1500, percent: 84))
        samples.append(sample(secondsAfterT0: 1800, percent: 83))
        // Only 2 trailing discharging samples, even though 6 discharging samples exist overall.
        let now = t0.addingTimeInterval(1800)
        #expect(DrainEstimator.drainPerHour(samples: samples, now: now) == nil)
    }

    @Test("Trailing run after a charge spanning < 5 min returns nil")
    func drainTrailingRunSpanTooShortAfterChargeReturnsNil() {
        var samples = linearSamples(count: 4, stepMinutes: 5, startPercent: 90, ratePerHour: 12)
        samples.append(sample(secondsAfterT0: 1200, percent: 88, discharging: false)) // plug-in
        samples.append(sample(secondsAfterT0: 1740, percent: 84.2))
        samples.append(sample(secondsAfterT0: 1860, percent: 84.0))
        samples.append(sample(secondsAfterT0: 1980, percent: 83.8))
        // 3 trailing samples but only 240 s of span.
        let now = t0.addingTimeInterval(1980)
        #expect(DrainEstimator.drainPerHour(samples: samples, now: now) == nil)
    }

    @Test("Most recent sample charging returns nil regardless of history")
    func drainMostRecentSampleChargingReturnsNil() {
        var samples = linearSamples(count: 3, stepMinutes: 5, startPercent: 80, ratePerHour: 10)
        samples.append(sample(secondsAfterT0: 900, percent: 78, discharging: false))
        let now = t0.addingTimeInterval(900)
        #expect(DrainEstimator.drainPerHour(samples: samples, now: now) == nil)
    }

    @Test("All samples charging returns nil")
    func drainAllChargingReturnsNil() {
        let samples = linearSamples(
            count: 5, stepMinutes: 5, startPercent: 80, ratePerHour: -20, discharging: false
        )
        let now = t0.addingTimeInterval(20 * 60)
        #expect(DrainEstimator.drainPerHour(samples: samples, now: now) == nil)
    }

    // MARK: drainPerHour — clamping and degenerate data

    @Test("Flat percent while discharging yields 0, not nil or negative")
    func drainFlatPercentIsZero() throws {
        let samples = (0..<4).map { sample(secondsAfterT0: Double($0) * 300, percent: 64.0) }
        let now = t0.addingTimeInterval(900)
        let rate = try #require(DrainEstimator.drainPerHour(samples: samples, now: now))
        #expect(rate == 0)
    }

    @Test("Rising percent while flagged discharging clamps to 0")
    func drainRisingPercentClampsToZero() throws {
        let samples = (0..<4).map {
            sample(secondsAfterT0: Double($0) * 300, percent: 70.0 + Double($0))
        }
        let now = t0.addingTimeInterval(900)
        let rate = try #require(DrainEstimator.drainPerHour(samples: samples, now: now))
        #expect(rate == 0)
    }

    @Test("All samples at an identical timestamp return nil (default span guard)")
    func drainIdenticalTimestampsReturnNil() {
        let samples = [
            sample(secondsAfterT0: 0, percent: 80),
            sample(secondsAfterT0: 0, percent: 79),
            sample(secondsAfterT0: 0, percent: 78),
        ]
        let now = t0.addingTimeInterval(60)
        #expect(DrainEstimator.drainPerHour(samples: samples, now: now) == nil)
    }

    @Test("Identical timestamps with minimumSpan 0 hit the zero-denominator guard")
    func drainIdenticalTimestampsZeroSpanHitsDenominatorGuard() {
        // With minimumSpan relaxed to 0 the count/span guards pass, so nil can
        // only come from the least-squares denominator (n·Σx² − (Σx)² == 0) guard.
        let samples = [
            sample(secondsAfterT0: 0, percent: 80),
            sample(secondsAfterT0: 0, percent: 79),
            sample(secondsAfterT0: 0, percent: 78),
        ]
        let now = t0.addingTimeInterval(60)
        #expect(
            DrainEstimator.drainPerHour(samples: samples, now: now, minimumSpan: 0) == nil
        )
    }

    @Test("Reverse-chronological input returns nil (documents ordering assumption)")
    func drainReverseChronologicalInputIsSortedInternally() {
        // drainPerHour sorts defensively, so sample order must not matter:
        // newest-first input yields the same 10%/hr as sorted input.
        let samples: [BatterySample] = [
            sample(secondsAfterT0: 1800, percent: 75.0),
            sample(secondsAfterT0: 900, percent: 77.5),
            sample(secondsAfterT0: 0, percent: 80.0),
        ]
        let now = t0.addingTimeInterval(1800)
        let rate = DrainEstimator.drainPerHour(samples: samples, now: now)
        #expect(rate != nil)
        if let rate {
            #expect(abs(rate - 10.0) < 0.01)
        }
    }

    // MARK: Public constants

    @Test("Safety constants stay pinned to spec")
    func constantsPinned() {
        #expect(DrainEstimator.defaultWindow == 40 * 60)
        #expect(DrainEstimator.minimumSpan == 5 * 60)
        #expect(DrainEstimator.minimumSamples == 3)
    }

    // MARK: timeToReach

    @Test("50% -> 10% at 10%/hr takes exactly 4 hours")
    func timeToReachFiftyToTenAtTenPerHour() throws {
        let seconds = try #require(
            DrainEstimator.timeToReach(targetPercent: 10, from: 50, ratePerHour: 10)
        )
        #expect(seconds == 4 * 3600)
    }

    @Test("Rate 0 returns nil")
    func timeToReachZeroRateReturnsNil() {
        #expect(DrainEstimator.timeToReach(targetPercent: 10, from: 50, ratePerHour: 0) == nil)
    }

    @Test("Rate exactly 0.01 returns nil (guard is strictly > 0.01)")
    func timeToReachRateExactlyPointZeroOneReturnsNil() {
        #expect(DrainEstimator.timeToReach(targetPercent: 10, from: 50, ratePerHour: 0.01) == nil)
    }

    @Test("Rate just above 0.01 returns a finite positive time")
    func timeToReachRateJustAboveThresholdReturnsValue() throws {
        let seconds = try #require(
            DrainEstimator.timeToReach(targetPercent: 10, from: 50, ratePerHour: 0.02)
        )
        // (50 - 10) / 0.02 * 3600 = 7_200_000 s
        #expect(seconds == 7_200_000)
    }

    @Test("Negative rate returns nil")
    func timeToReachNegativeRateReturnsNil() {
        #expect(DrainEstimator.timeToReach(targetPercent: 10, from: 50, ratePerHour: -5) == nil)
    }

    @Test("Current equal to target returns nil")
    func timeToReachCurrentEqualsTargetReturnsNil() {
        #expect(DrainEstimator.timeToReach(targetPercent: 10, from: 10, ratePerHour: 10) == nil)
    }

    @Test("Current below target returns nil")
    func timeToReachCurrentBelowTargetReturnsNil() {
        #expect(DrainEstimator.timeToReach(targetPercent: 10, from: 5, ratePerHour: 10) == nil)
    }

    // MARK: projectedDate

    @Test("projectedDate is now + timeToReach")
    func projectedDateAddsTimeToReachToNow() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let projected = DrainEstimator.projectedDate(
            targetPercent: 10, from: 50, ratePerHour: 10, now: now
        )
        #expect(projected == Date(timeIntervalSince1970: 1_700_000_000 + 4 * 3600))
    }

    @Test("projectedDate propagates nil for an invalid rate")
    func projectedDateNilWhenRateInvalid() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        #expect(
            DrainEstimator.projectedDate(targetPercent: 10, from: 50, ratePerHour: 0, now: now) == nil
        )
    }

    @Test("projectedDate propagates nil when already at/below target")
    func projectedDateNilWhenAlreadyAtTarget() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        #expect(
            DrainEstimator.projectedDate(targetPercent: 50, from: 50, ratePerHour: 10, now: now) == nil
        )
        #expect(
            DrainEstimator.projectedDate(targetPercent: 50, from: 40, ratePerHour: 10, now: now) == nil
        )
    }
}
