import Foundation

/// Typed evidence from one entry in an operating-system power-source list.
/// The app translates IOKit dictionaries into this enum; the safety-critical
/// normalization stays pure and executable in the core test suite.
public enum BatteryPowerSourceReading: Sendable, Equatable {
    case internalBattery(
        currentCapacity: Int?,
        maximumCapacity: Int?,
        state: PowerSourceState,
        isCharging: Bool,
        timeToEmptyMinutes: Int?
    )
    case other
    case unavailable

    /// Classifies raw operating-system strings without guessing. Only the two
    /// documented source types and the two usable internal-battery power
    /// states are accepted; absent or novel values remain unavailable.
    public static func classify(
        type: String?,
        internalBatteryType: String,
        alternatePowerSourceType: String,
        currentCapacity: Int?,
        maximumCapacity: Int?,
        sourceState: String?,
        acPowerState: String,
        batteryPowerState: String,
        isCharging: Bool?,
        timeToEmptyMinutes: Int?
    ) -> Self {
        guard let type else { return .unavailable }
        if type == alternatePowerSourceType {
            return .other
        }
        guard type == internalBatteryType else {
            return .unavailable
        }

        let state: PowerSourceState
        switch sourceState {
        case acPowerState:
            state = .ac
        case batteryPowerState:
            state = .battery
        default:
            return .unavailable
        }

        return .internalBattery(
            currentCapacity: currentCapacity,
            maximumCapacity: maximumCapacity,
            state: state,
            // Missing charging evidence is conservatively treated as not
            // charging, so a battery-powered source remains discharging.
            isCharging: isCharging ?? false,
            timeToEmptyMinutes: timeToEmptyMinutes
        )
    }
}

public enum BatterySnapshotNormalizer {
    /// Produces one safety snapshot from a complete power-source enumeration
    /// and, for absence only, independent hardware-topology proof. Any
    /// unclassifiable entry contaminates absence proof. Multiple internal
    /// batteries are also left unavailable rather than combined incorrectly.
    public static func normalize(
        _ readings: [BatteryPowerSourceReading],
        noInternalBatteryProven: Bool = false,
        at date: Date
    ) -> BatterySnapshot {
        var internalBattery: BatteryPowerSourceReading?

        for reading in readings {
            switch reading {
            case .unavailable:
                return .unknown(at: date)
            case .other:
                continue
            case .internalBattery:
                guard internalBattery == nil else {
                    return .unknown(at: date)
                }
                internalBattery = reading
            }
        }

        guard case let .internalBattery(
            currentCapacity,
            maximumCapacity,
            state,
            isCharging,
            timeToEmptyMinutes
        ) = internalBattery else {
            // Enumeration absence alone is not hardware-absence proof; the
            // caller must also supply independent hardware evidence.
            return noInternalBatteryProven
                ? .noBattery(at: date)
                : .unknown(at: date)
        }

        guard let currentCapacity,
              let maximumCapacity,
              maximumCapacity > 0,
              currentCapacity >= 0,
              currentCapacity <= maximumCapacity,
              state == .ac || state == .battery,
              state != .battery || !isCharging else {
            return .unknown(at: date)
        }

        // Bounds are proven before floating-point conversion, so even
        // adversarial Int extremes cannot create an out-of-range Int trap.
        let fraction = Double(currentCapacity) / Double(maximumCapacity)
        guard fraction.isFinite, (0...1).contains(fraction) else {
            return .unknown(at: date)
        }
        let percent = Int((fraction * 100).rounded())

        let usableTimeToEmpty = timeToEmptyMinutes.flatMap { value in
            // The estimate is presentation-only. Discard impossible/extreme
            // values rather than carrying an untrusted Int into date math.
            (1...(7 * 24 * 60)).contains(value) ? value : nil
        }
        return BatterySnapshot(
            percent: percent,
            state: state,
            isCharging: isCharging,
            timeToEmptyMinutes: usableTimeToEmpty,
            sampledAt: date
        )
    }
}
