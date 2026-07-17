import Foundation

// MARK: - Cutoff configuration

/// Everything that decides *when Lidless stops keeping the Mac awake*.
/// Pure data; the engine interprets it. Defaults are the shipping defaults.
public struct CutoffConfig: Codable, Sendable, Equatable {
    // Battery floor — only enforced while discharging.
    public var batteryFloorEnabled: Bool = true
    public var batteryFloorPercent: Int = 10

    // Thermal protection.
    public var thermalEnabled: Bool = true
    /// Cut off when CPU_Speed_Limit drops below this percent.
    public var thermalSpeedLimitFloor: Int = 60
    /// Consecutive bad readings required before firing, to ride out blips.
    public var thermalStrikesRequired: Int = 2

    // Duration limit.
    public var durationEnabled: Bool = false
    public var durationSeconds: TimeInterval = 4 * 3600

    // Wall-clock off-time.
    public var offTimeEnabled: Bool = false
    public var offTime: HMTime = HMTime(hour: 7, minute: 0)

    public init() {}

    /// Arm-time guardrails (not persisted knobs; fixed product behavior).
    public static let armRefusalMargin = 2      // refuse to arm at/below floor + margin while discharging
    public static let armLowBatteryWarning = 30 // explicit warning below this percent
}

// MARK: - Session behavior (side effects, not cutoff decisions)

public struct BehaviorConfig: Codable, Sendable, Equatable {
    /// Force sleep (`pmset sleepnow`) after a cutoff when the lid is closed.
    public var sleepOnCutoff: Bool = true
    /// Post a macOS notification on every arm / disarm / cutoff.
    public var notifyOnStateChanges: Bool = true
    public var playCutoffSound: Bool = true
    /// Enable Low Power Mode while armed; prior state restored on disarm.
    public var lowPowerModeWhileArmed: Bool = false
    /// Keep network connections alive for remote-access use: enforce
    /// `tcpkeepalive 1` while armed; prior state restored on disarm.
    public var tcpKeepAliveWhileArmed: Bool = false
    /// Show time-to-cutoff next to the menu bar icon while armed.
    public var countdownInMenuBar: Bool = true

    public init() {}
}

// MARK: - Per-session overrides (presets)

/// Optional overrides layered on top of `CutoffConfig` for one session.
/// nil means "inherit from the base config".
public struct SessionOverrides: Codable, Sendable, Equatable {
    public var batteryFloorEnabled: Bool?
    public var batteryFloorPercent: Int?
    public var durationEnabled: Bool?
    public var durationSeconds: TimeInterval?
    public var offTimeEnabled: Bool?
    public var offTime: HMTime?

    public init(
        batteryFloorEnabled: Bool? = nil,
        batteryFloorPercent: Int? = nil,
        durationEnabled: Bool? = nil,
        durationSeconds: TimeInterval? = nil,
        offTimeEnabled: Bool? = nil,
        offTime: HMTime? = nil
    ) {
        self.batteryFloorEnabled = batteryFloorEnabled
        self.batteryFloorPercent = batteryFloorPercent
        self.durationEnabled = durationEnabled
        self.durationSeconds = durationSeconds
        self.offTimeEnabled = offTimeEnabled
        self.offTime = offTime
    }

    public static let none = SessionOverrides()
}

extension CutoffConfig {
    /// The config actually in force for a session: base + overrides.
    public func applying(_ overrides: SessionOverrides?) -> CutoffConfig {
        guard let o = overrides else { return self }
        var c = self
        if let v = o.batteryFloorEnabled { c.batteryFloorEnabled = v }
        if let v = o.batteryFloorPercent { c.batteryFloorPercent = v }
        if let v = o.durationEnabled { c.durationEnabled = v }
        if let v = o.durationSeconds { c.durationSeconds = v }
        if let v = o.offTimeEnabled { c.offTimeEnabled = v }
        if let v = o.offTime { c.offTime = v }
        return c
    }
}

// MARK: - Quick-arm presets

public enum ArmPreset: String, CaseIterable, Codable, Sendable, Identifiable {
    /// Keep awake until 7:00 AM, ignoring any duration limit.
    case untilMorning
    /// Keep awake for the next 4 hours, ignoring any off-time.
    case nextFourHours
    /// Run the battery down to 20%, ignoring time-based cutoffs.
    case untilTwentyPercent

    public var id: String { rawValue }

    /// Overrides this preset applies on top of the user's base config.
    /// Battery-floor and thermal safety nets are never weakened: presets
    /// may raise the floor but the base floor/thermal settings otherwise
    /// remain in force.
    public func overrides() -> SessionOverrides {
        switch self {
        case .untilMorning:
            SessionOverrides(
                durationEnabled: false,
                offTimeEnabled: true,
                offTime: HMTime(hour: 7, minute: 0)
            )
        case .nextFourHours:
            SessionOverrides(
                durationEnabled: true,
                durationSeconds: 4 * 3600,
                offTimeEnabled: false
            )
        case .untilTwentyPercent:
            SessionOverrides(
                batteryFloorEnabled: true,
                batteryFloorPercent: 20,
                durationEnabled: false,
                offTimeEnabled: false
            )
        }
    }
}
