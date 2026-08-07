import Foundation

/// Fail-closed admission and freshness rules for the `pmset -g therm` signal.
///
/// `ProcessInfo.thermalState` remains a useful independent pressure signal,
/// but it does not expose the configured CPU speed-limit threshold. An enabled
/// thermal guard therefore needs a recent, structurally meaningful pmset
/// sample instead of treating missing data as nominal.
public enum ThermalEvidenceSafety {
    /// Two 90-second poll intervals. The normal poll loop refreshes well before
    /// this boundary; a stalled loop cannot preserve a nominal sample forever.
    public static let maximumSampleAge: TimeInterval = 180

    /// No source may advance the debounce faster than this interval.
    /// ProcessInfo has no sample identity, while a distinct pmset sample that
    /// arrives inside the gate remains eligible once the interval elapses.
    public static let minimumStrikeInterval: TimeInterval = 45

    public static func accepted(
        _ reading: ThermalReading?,
        at now: Date
    ) -> ThermalReading? {
        guard let reading else { return nil }

        let age = now.timeIntervalSince(reading.sampledAt)
        guard age >= 0, age <= maximumSampleAge else { return nil }

        guard reading.warningLevel != nil || reading.cpuSpeedLimit != nil else {
            return nil
        }
        if let warningLevel = reading.warningLevel,
           !(0...100).contains(warningLevel) {
            return nil
        }
        if let cpuSpeedLimit = reading.cpuSpeedLimit,
           !(0...100).contains(cpuSpeedLimit) {
            return nil
        }
        if let schedulerLimit = reading.schedulerLimit,
           !(0...100).contains(schedulerLimit) {
            return nil
        }
        if let availableCPUs = reading.availableCPUs,
           availableCPUs <= 0 {
            return nil
        }
        return reading
    }

    public static func isUsable(
        _ reading: ThermalReading?,
        at now: Date
    ) -> Bool {
        accepted(reading, at: now) != nil
    }
}

/// Debounces two independent thermal sources without allowing an unchanged
/// pmset sample to block later ProcessInfo evidence.
public struct ThermalStrikeTracker: Sendable {
    public private(set) var count = 0

    private var lastViolatingPMSetSample: Date?
    private var lastViolatingObservationAt: Date?
    private var nextStrikeAllowedAt = Date.distantPast

    public init() {}

    @discardableResult
    public mutating func observe(
        config: CutoffConfig,
        thermal: ThermalReading?,
        processThermal: ProcessThermalLevel,
        at now: Date
    ) -> Int {
        let config = config.normalized()
        guard config.thermalEnabled else {
            reset()
            return count
        }

        let accepted = ThermalEvidenceSafety.accepted(thermal, at: now)
        let pmsetViolation = accepted.map {
            ($0.warningLevel ?? 0) > 0
                || ($0.cpuSpeedLimit.map { $0 < config.thermalSpeedLimitFloor } ?? false)
        } ?? false
        let processViolation = processThermal >= .serious

        guard pmsetViolation || processViolation else {
            reset()
            return count
        }

        let newPMSetSample = pmsetViolation
            && accepted?.sampledAt != lastViolatingPMSetSample

        let previousObservationAt = lastViolatingObservationAt
        lastViolatingObservationAt = now
        if let previousObservationAt, now < previousObservationAt {
            if newPMSetSample {
                lastViolatingPMSetSample = accepted?.sampledAt
            }
            count = max(count, config.thermalStrikesRequired)
            nextStrikeAllowedAt = now.addingTimeInterval(
                ThermalEvidenceSafety.minimumStrikeInterval
            )
            return count
        }

        guard now >= nextStrikeAllowedAt else { return count }

        let hasNewEvidence = newPMSetSample || processViolation

        if hasNewEvidence {
            if newPMSetSample {
                lastViolatingPMSetSample = accepted?.sampledAt
            }
            count += 1
            nextStrikeAllowedAt = now.addingTimeInterval(
                ThermalEvidenceSafety.minimumStrikeInterval
            )
        }
        return count
    }

    public mutating func reset() {
        count = 0
        lastViolatingPMSetSample = nil
        lastViolatingObservationAt = nil
        nextStrikeAllowedAt = .distantPast
    }
}
