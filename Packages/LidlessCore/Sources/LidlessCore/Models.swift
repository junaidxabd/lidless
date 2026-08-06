import Foundation

// MARK: - Power

public enum PowerSourceState: String, Codable, Sendable {
    case ac
    case battery
    /// A fully classified power-source enumeration plus independent readable
    /// hardware-topology evidence found no internal battery. This is distinct
    /// from an AC-powered battery whose percentage could not be read.
    case noBattery
    case unknown
}

/// A point-in-time reading of the battery, from IOKit power-source
/// notifications (or the simulator in dry-run mode).
public struct BatterySnapshot: Codable, Sendable, Equatable {
    /// 0–100. A nil percentage is usable only with `.noBattery`; every other
    /// nil/unknown combination is unavailable evidence.
    public var percent: Int?
    public var state: PowerSourceState
    public var isCharging: Bool
    /// System's own estimate, minutes; nil when unknown or not discharging.
    public var timeToEmptyMinutes: Int?
    public var sampledAt: Date

    public init(
        percent: Int?,
        state: PowerSourceState,
        isCharging: Bool,
        timeToEmptyMinutes: Int? = nil,
        sampledAt: Date
    ) {
        self.percent = percent
        self.state = state
        self.isCharging = isCharging
        self.timeToEmptyMinutes = timeToEmptyMinutes
        self.sampledAt = sampledAt
    }

    public var hasBattery: Bool { percent != nil }

    /// Whether a floor-protected session can make a truthful battery decision.
    /// A successful no-internal-battery result is usable because no battery can
    /// drain. Missing, malformed, or source-unknown readings fail closed.
    public var hasUsableSafetyEvidence: Bool {
        switch (percent, state, isCharging) {
        case (nil, .noBattery, false):
            return true
        case (.some(let percent), .ac, _),
             (.some(let percent), .battery, false):
            return (0...100).contains(percent)
        default:
            return false
        }
    }

    /// True only when actively draining: on battery power and not charging.
    /// This is the condition that keeps the battery-floor cutoff live;
    /// plugging in makes it false and suspends the countdown.
    public var isDischarging: Bool { state == .battery && !isCharging }

    public static func unknown(at date: Date) -> BatterySnapshot {
        BatterySnapshot(percent: nil, state: .unknown, isCharging: false, sampledAt: date)
    }

    public static func noBattery(at date: Date) -> BatterySnapshot {
        BatterySnapshot(percent: nil, state: .noBattery, isCharging: false, sampledAt: date)
    }
}

// MARK: - Thermal

/// Parsed from `pmset -g therm`. Any field can be absent — Apple Silicon
/// machines often report only the warning level, Intel machines report all.
public struct ThermalReading: Codable, Sendable, Equatable {
    /// 0 = nominal. Any value > 0 is a system thermal warning.
    public var warningLevel: Int?
    /// Percent, 100 = unthrottled.
    public var cpuSpeedLimit: Int?
    public var schedulerLimit: Int?
    public var availableCPUs: Int?
    public var sampledAt: Date

    public init(
        warningLevel: Int? = nil,
        cpuSpeedLimit: Int? = nil,
        schedulerLimit: Int? = nil,
        availableCPUs: Int? = nil,
        sampledAt: Date
    ) {
        self.warningLevel = warningLevel
        self.cpuSpeedLimit = cpuSpeedLimit
        self.schedulerLimit = schedulerLimit
        self.availableCPUs = availableCPUs
        self.sampledAt = sampledAt
    }
}

/// Mirror of `ProcessInfo.ThermalState`, kept in the core so the cutoff
/// engine stays importable from the daemon and tests without AppKit.
public enum ProcessThermalLevel: Int, Codable, Sendable, Comparable {
    case nominal = 0
    case fair = 1
    case serious = 2
    case critical = 3

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

// MARK: - Wall-clock time of day

/// A time of day with no date attached ("7:00 AM"), safe to persist.
public struct HMTime: Codable, Sendable, Equatable, Hashable {
    public var hour: Int
    public var minute: Int

    public init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    public var minutesFromMidnight: Int { hour * 60 + minute }

    /// The first moment strictly after `date` that matches this time of day.
    public func nextOccurrence(after date: Date, calendar: Calendar) -> Date? {
        calendar.nextDate(
            after: date,
            matching: DateComponents(hour: hour, minute: minute, second: 0),
            matchingPolicy: .nextTime,
            direction: .forward
        )
    }

    /// `date`'s day at this time of day.
    public func onSameDay(as date: Date, calendar: Calendar) -> Date? {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date)
    }
}
