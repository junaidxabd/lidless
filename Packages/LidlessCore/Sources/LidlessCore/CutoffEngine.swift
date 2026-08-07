import Foundation

// MARK: - Cutoff reasons

public enum CutoffReason: Codable, Sendable, Equatable, Hashable {
    case thermal(detail: String)
    case thermalTelemetryUnavailable
    case batteryTelemetryUnavailable
    case batteryFloor(percent: Int, floor: Int)
    case offTime
    case durationElapsed
    case scheduleEnded

    /// Stable ordering: safety cutoffs outrank convenience cutoffs.
    public var priority: Int {
        switch self {
        case .thermal: 0
        case .thermalTelemetryUnavailable: 1
        case .batteryTelemetryUnavailable: 2
        case .batteryFloor: 3
        case .offTime: 4
        case .durationElapsed: 5
        case .scheduleEnded: 6
        }
    }
}

/// A time-based cutoff whose firing moment is known in advance.
public struct PlannedCutoff: Sendable, Equatable {
    public enum Kind: String, Sendable, Codable {
        case offTime
        case duration
        case scheduleEnd
    }

    public var kind: Kind
    public var date: Date

    public init(kind: Kind, date: Date) {
        self.kind = kind
        self.date = date
    }
}

// MARK: - Arm-time assessment

public enum ArmAssessment: Sendable, Equatable {
    case ok
    /// Battery is low-ish; arming is allowed but the UI must warn with a projection.
    case lowBatteryWarning(percent: Int)
    /// At or under the floor (plus margin) while discharging; arming is refused.
    case refusedBelowFloor(percent: Int, floor: Int)
    /// The configured floor cannot be enforced without readable battery data.
    case refusedBatteryTelemetryUnavailable
    /// The configured thermal guard cannot be enforced without a fresh,
    /// structurally meaningful pmset sample.
    case refusedThermalTelemetryUnavailable
    /// Current thermal pressure already violates the configured guard.
    case refusedThermalPressure(detail: String)

    public var allowsArm: Bool {
        switch self {
        case .ok, .lowBatteryWarning:
            return true
        case .refusedBelowFloor,
             .refusedBatteryTelemetryUnavailable,
             .refusedThermalTelemetryUnavailable,
             .refusedThermalPressure:
            return false
        }
    }
}

// MARK: - Evaluation result

public struct CutoffEvaluation: Sendable, Equatable {
    /// Reasons that fired at this instant, highest priority first.
    /// Non-empty means: restore normal sleep now.
    public var fired: [CutoffReason]
    /// Whether this reading violates the thermal thresholds (pre-debounce).
    /// The caller feeds consecutive-violation counts back in as `thermalStrikes`.
    public var thermalViolation: Bool
    /// Earliest known time-based cutoff, for countdown UI. nil if none configured.
    public var nextTimeCutoff: PlannedCutoff?

    public init(fired: [CutoffReason], thermalViolation: Bool, nextTimeCutoff: PlannedCutoff?) {
        self.fired = fired
        self.thermalViolation = thermalViolation
        self.nextTimeCutoff = nextTimeCutoff
    }
}

// MARK: - Engine

/// Pure decision logic: no clocks, no IO, no state. Everything it needs is a
/// parameter, so every branch is unit-testable and the dry-run simulator gets
/// identical behavior for free.
public enum CutoffEngine {

    /// Should arming be allowed right now?
    ///
    /// Rules:
    /// - A successfully observed battery-less desktop → ok; no battery drains.
    /// - Missing, malformed, stale, or future-dated thermal evidence with an
    ///   enabled thermal guard → refused because its thresholds are unprovable.
    /// - Fresh thermal evidence that already violates a configured threshold,
    ///   or serious ProcessInfo pressure → refused instead of arming hot.
    /// - Missing, malformed, or source-unknown evidence with an enabled floor
    ///   → refused because the cutoff could not be enforced.
    /// - On AC → ok even at 3%: the floor only governs discharge, and if the
    ///   machine is later unplugged below the floor, the cutoff fires then.
    /// - Discharging at/below floor + margin → refused.
    /// - Discharging below the warning threshold → allowed with explicit warning.
    public static func assessArm(
        config: CutoffConfig,
        battery: BatterySnapshot,
        thermal: ThermalReading?,
        processThermal: ProcessThermalLevel,
        at now: Date
    ) -> ArmAssessment {
        let config = config.normalized()
        guard !config.thermalEnabled
                || ThermalEvidenceSafety.isUsable(thermal, at: now) else {
            return .refusedThermalTelemetryUnavailable
        }
        if isThermalViolation(
            config: config,
            thermal: thermal,
            processThermal: processThermal,
            at: now
        ) {
            return .refusedThermalPressure(detail: thermalDetail(
                config: config,
                thermal: thermal,
                processThermal: processThermal,
                at: now
            ))
        }
        guard battery.hasUsableSafetyEvidence else {
            return config.batteryFloorEnabled
                ? .refusedBatteryTelemetryUnavailable
                : .ok
        }
        guard let percent = battery.percent, battery.isDischarging else { return .ok }
        if config.batteryFloorEnabled,
           percent <= config.batteryFloorPercent + CutoffConfig.armRefusalMargin {
            return .refusedBelowFloor(percent: percent, floor: config.batteryFloorPercent)
        }
        if percent < CutoffConfig.armLowBatteryWarning {
            return .lowBatteryWarning(percent: percent)
        }
        return .ok
    }

    /// Time-based cutoffs implied by `config` for a session armed at `armedAt`.
    ///
    /// The off-time is the first occurrence strictly after `armedAt`: arming at
    /// 23:00 with a 07:00 off-time fires at 07:00 tomorrow; arming at 06:00
    /// fires at 07:00 today.
    public static func plannedCutoffs(
        config: CutoffConfig,
        armedAt: Date,
        calendar: Calendar
    ) -> [PlannedCutoff] {
        let config = config.normalized()
        var planned: [PlannedCutoff] = []
        if config.durationEnabled, config.durationSeconds > 0 {
            planned.append(PlannedCutoff(kind: .duration, date: armedAt.addingTimeInterval(config.durationSeconds)))
        }
        if config.offTimeEnabled, let fire = config.offTime.nextOccurrence(after: armedAt, calendar: calendar) {
            planned.append(PlannedCutoff(kind: .offTime, date: fire))
        }
        return planned.sorted { $0.date < $1.date }
    }

    /// Does this thermal picture violate the configured thresholds?
    public static func isThermalViolation(
        config: CutoffConfig,
        thermal: ThermalReading?,
        processThermal: ProcessThermalLevel,
        at now: Date
    ) -> Bool {
        let config = config.normalized()
        guard config.thermalEnabled else { return false }
        let accepted = ThermalEvidenceSafety.accepted(thermal, at: now)
        if let level = accepted?.warningLevel, level > 0 { return true }
        if let speed = accepted?.cpuSpeedLimit,
           speed < config.thermalSpeedLimitFloor { return true }
        if processThermal >= .serious { return true }
        return false
    }

    /// Evaluate one tick of an armed session.
    ///
    /// - Parameter thermalStrikes: consecutive violating readings *before* this
    ///   one. Serious process pressure and pmset violations retain the configured
    ///   debounce; critical process pressure fires immediately.
    public static func evaluate(
        config: CutoffConfig,
        armedAt: Date,
        now: Date,
        battery: BatterySnapshot,
        thermal: ThermalReading?,
        processThermal: ProcessThermalLevel = .nominal,
        thermalStrikes: Int = 0,
        calendar: Calendar
    ) -> CutoffEvaluation {
        let config = config.normalized()
        var fired: [CutoffReason] = []

        // Thermal — highest priority.
        let acceptedThermal = ThermalEvidenceSafety.accepted(thermal, at: now)
        let violation = isThermalViolation(
            config: config,
            thermal: acceptedThermal,
            processThermal: processThermal,
            at: now
        )
        let isImmediateCriticalPressure = processThermal == .critical
        let reachesDebounce = thermalStrikes >= config.thermalStrikesRequired - 1
        if violation, isImmediateCriticalPressure || reachesDebounce {
            fired.append(.thermal(detail: thermalDetail(
                config: config,
                thermal: acceptedThermal,
                processThermal: processThermal,
                at: now
            )))
        }
        if config.thermalEnabled, acceptedThermal == nil {
            fired.append(.thermalTelemetryUnavailable)
        }

        // A configured floor is a safety promise. If its evidence disappears,
        // restore instead of silently running with no enforceable floor.
        if config.batteryFloorEnabled {
            if !battery.hasUsableSafetyEvidence {
                fired.append(.batteryTelemetryUnavailable)
            } else if let percent = battery.percent,
                      battery.isDischarging,
                      percent <= config.batteryFloorPercent {
                fired.append(.batteryFloor(
                    percent: percent,
                    floor: config.batteryFloorPercent
                ))
            }
        }

        // Time-based cutoffs.
        let planned = plannedCutoffs(config: config, armedAt: armedAt, calendar: calendar)
        for cutoff in planned where now >= cutoff.date {
            switch cutoff.kind {
            case .offTime: fired.append(.offTime)
            case .duration: fired.append(.durationElapsed)
            case .scheduleEnd: fired.append(.scheduleEnded)
            }
        }

        fired.sort { $0.priority < $1.priority }
        let next = planned.first { $0.date > now }

        return CutoffEvaluation(fired: fired, thermalViolation: violation, nextTimeCutoff: next)
    }

    /// Human-readable description of what tripped the thermal cutoff.
    /// Attribution mirrors `isThermalViolation`: only a signal that actually
    /// violates its threshold is named as the trigger.
    public static func thermalDetail(
        config: CutoffConfig,
        thermal: ThermalReading?,
        processThermal: ProcessThermalLevel,
        at now: Date
    ) -> String {
        let config = config.normalized()
        let accepted = ThermalEvidenceSafety.accepted(thermal, at: now)
        if let level = accepted?.warningLevel, level > 0 {
            return "Thermal warning level \(level)"
        }
        if let speed = accepted?.cpuSpeedLimit,
           speed < config.thermalSpeedLimitFloor {
            return "CPU limited to \(speed)%"
        }
        switch processThermal {
        case .critical: return "System thermal state critical"
        case .serious: return "System thermal state serious"
        default: return "Thermal pressure"
        }
    }
}
