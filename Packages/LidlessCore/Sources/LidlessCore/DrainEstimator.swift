import Foundation

/// One battery observation in a session's curve.
public struct BatterySample: Codable, Sendable, Equatable {
    public var time: Date
    public var percent: Double
    public var isDischarging: Bool

    public init(time: Date, percent: Double, isDischarging: Bool) {
        self.time = time
        self.percent = percent
        self.isDischarging = isDischarging
    }
}

/// Estimates the battery drain rate from recent samples, and projects when a
/// given percentage will be reached. Pure math — the sampling cadence and
/// storage live in the app.
public enum DrainEstimator {

    public static let defaultWindow: TimeInterval = 40 * 60
    public static let minimumSpan: TimeInterval = 5 * 60
    public static let minimumSamples = 3

    /// Least-squares drain rate in percent per hour (positive = draining).
    ///
    /// Uses only the trailing run of *discharging* samples inside `window` —
    /// a plug-in event invalidates everything before it, because AC time tells
    /// us nothing about discharge slope. Returns nil until there is at least
    /// `minimumSamples` points spanning `minimumSpan`. A flat or rising trend
    /// while discharging clamps to 0 rather than reporting negative drain.
    public static func drainPerHour(
        samples: [BatterySample],
        now: Date,
        window: TimeInterval = defaultWindow,
        minimumSpan: TimeInterval = minimumSpan,
        minimumSamples: Int = minimumSamples
    ) -> Double? {
        let cutoff = now.addingTimeInterval(-window)
        // Callers append chronologically, but sort defensively — the
        // trailing-run scan below is positional and order bugs here would
        // silently corrupt the estimate.
        let recent = samples
            .filter { $0.time >= cutoff && $0.time <= now }
            .sorted { $0.time < $1.time }

        // Trailing discharging run: stop at the most recent non-discharging sample.
        var run: [BatterySample] = []
        for sample in recent.reversed() {
            if sample.isDischarging {
                run.append(sample)
            } else {
                break
            }
        }
        run.reverse()

        guard run.count >= minimumSamples,
              let first = run.first, let last = run.last,
              last.time.timeIntervalSince(first.time) >= minimumSpan
        else { return nil }

        // Least-squares slope of percent over seconds.
        let t0 = first.time
        let xs = run.map { $0.time.timeIntervalSince(t0) }
        let ys = run.map(\.percent)
        let n = Double(run.count)
        let sumX = xs.reduce(0, +)
        let sumY = ys.reduce(0, +)
        let sumXY = zip(xs, ys).reduce(0) { $0 + $1.0 * $1.1 }
        let sumXX = xs.reduce(0) { $0 + $1 * $1 }
        let denominator = n * sumXX - sumX * sumX
        guard denominator > 0 else { return nil }

        let slopePerSecond = (n * sumXY - sumX * sumY) / denominator
        return max(0, -slopePerSecond * 3600)
    }

    /// Seconds until `target` percent is reached at `ratePerHour`, from
    /// `currentPercent`. nil when the rate is zero/invalid or already at/below target.
    public static func timeToReach(
        targetPercent: Double,
        from currentPercent: Double,
        ratePerHour: Double
    ) -> TimeInterval? {
        guard ratePerHour > 0.01, currentPercent > targetPercent else { return nil }
        return (currentPercent - targetPercent) / ratePerHour * 3600
    }

    /// Projected wall-clock moment the battery hits `targetPercent`.
    public static func projectedDate(
        targetPercent: Double,
        from currentPercent: Double,
        ratePerHour: Double,
        now: Date
    ) -> Date? {
        timeToReach(targetPercent: targetPercent, from: currentPercent, ratePerHour: ratePerHour)
            .map(now.addingTimeInterval)
    }
}
