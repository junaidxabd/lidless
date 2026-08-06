import Foundation

// MARK: - XPC protocol

/// The privileged helper's entire surface. Payloads are JSON `Data` of the
/// Codable types below rather than NSSecureCoding classes — one encoding for
/// XPC, the sentinel file, and logs.
///
/// Every reply carries a fresh `HelperStatus` so the app can re-verify actual
/// system state (not just believed state) after each operation.
@objc(LidlessHelperXPC)
public protocol LidlessHelperXPC {
    /// Liveness + version probe. Reply: `HelperStatus` JSON.
    func ping(_ reply: @escaping @Sendable (Data) -> Void)

    /// Enable the sleep override. Reply: `HelperReply` JSON.
    /// Idempotent: arming while armed refreshes options and the watchdog.
    func arm(_ optionsJSON: Data, reply: @escaping @Sendable (Data) -> Void)

    /// Push the watchdog deadline out. Reply: `HelperReply` JSON; `ok` is
    /// false if no session is active (app should reconcile).
    func heartbeat(_ reply: @escaping @Sendable (Data) -> Void)

    /// Restore normal sleep. Reply: `HelperReply` JSON.
    /// With `forceSleep`, the helper runs `pmset sleepnow` after replying,
    /// so the app has a moment to post its notification first.
    func disarm(_ optionsJSON: Data, reply: @escaping @Sendable (Data) -> Void)

    /// Restore `disablesleep 0` even if this helper didn't set it — the
    /// in-app fix for an override left behind by other tools. Reply: `HelperReply`.
    func repairOverride(_ reply: @escaping @Sendable (Data) -> Void)

    /// Schedule (epoch > 0) or cancel (epoch == 0) an RTC wake for schedule
    /// automation, via `pmset schedule wake`. Reply: `HelperReply`.
    func scheduleWake(_ epoch: Double, reply: @escaping @Sendable (Data) -> Void)

    /// Restore all managed pmset state, remove the helper's on-disk data,
    /// and cancel any scheduled wake. The app deregisters the daemon after
    /// this succeeds. Reply: `HelperReply`.
    func uninstall(_ reply: @escaping @Sendable (Data) -> Void)
}

// MARK: - Payloads

public struct HelperArmOptions: Codable, Sendable, Equatable {
    /// The app heartbeats every ~10s; the helper restores sleep if none
    /// arrives for this long.
    public var watchdogTTL: TimeInterval
    public var lowPowerMode: Bool
    public var tcpKeepAlive: Bool

    public init(
        watchdogTTL: TimeInterval = HelperArmOptions.defaultWatchdogTTL,
        lowPowerMode: Bool = false,
        tcpKeepAlive: Bool = false
    ) {
        self.watchdogTTL = watchdogTTL
        self.lowPowerMode = lowPowerMode
        self.tcpKeepAlive = tcpKeepAlive
    }

    public static let defaultWatchdogTTL: TimeInterval = 45
    public static let heartbeatInterval: TimeInterval = 10
    /// Watchdog TTLs outside this range are clamped by the helper — the app
    /// can never talk the helper into an unsupervised override.
    public static let watchdogTTLRange: ClosedRange<TimeInterval> = 15...120
}

public struct HelperDisarmOptions: Codable, Sendable, Equatable {
    public var forceSleep: Bool
    /// For the helper log, e.g. "battery floor 10%".
    public var reason: String

    public init(forceSleep: Bool, reason: String) {
        self.forceSleep = forceSleep
        self.reason = reason
    }
}

public struct HelperStatus: Codable, Sendable, Equatable {
    public var helperVersion: Int
    /// Exact safety behavior revision declared by the responding helper.
    /// Optional for same-protocol helpers built before this field existed;
    /// missing or mismatched values cannot authorize a safety transition.
    public var helperSafetyRevision: Int?
    public var armed: Bool
    /// Actual current value of the system-wide override (read back from the
    /// power-management root domain), not what the helper believes it set.
    public var sleepDisabled: Bool
    /// `true` only when `sleepDisabled` came from a successful registry read.
    /// Optional for wire compatibility with an older helper; missing is not
    /// proof and must be treated as unverified by safety-sensitive callers.
    public var sleepStateVerified: Bool?
    /// The helper failed to prove restoration of sleep or another
    /// helper-managed pmset value and is retaining its sentinel while
    /// retrying. Optional for wire compatibility; missing is unknown.
    public var restorePending: Bool?
    public var armedSince: Date?
    public var watchdogDeadline: Date?
    public var scheduledWake: Date?

    public init(
        helperVersion: Int,
        helperSafetyRevision: Int?,
        armed: Bool,
        sleepDisabled: Bool,
        sleepStateVerified: Bool? = nil,
        restorePending: Bool? = nil,
        armedSince: Date? = nil,
        watchdogDeadline: Date? = nil,
        scheduledWake: Date? = nil
    ) {
        self.helperVersion = helperVersion
        self.helperSafetyRevision = helperSafetyRevision
        self.armed = armed
        self.sleepDisabled = sleepDisabled
        self.sleepStateVerified = sleepStateVerified
        self.restorePending = restorePending
        self.armedSince = armedSince
        self.watchdogDeadline = watchdogDeadline
        self.scheduledWake = scheduledWake
    }
}

public struct HelperReply: Codable, Sendable, Equatable {
    public var ok: Bool
    public var error: String?
    public var status: HelperStatus

    public init(ok: Bool, error: String? = nil, status: HelperStatus) {
        self.ok = ok
        self.error = error
        self.status = status
    }
}

// MARK: - Sentinel

/// Written atomically to `HelperPaths.sentinel` the instant before the
/// override is enabled; deleted the instant after it is restored. Its
/// existence means "the system may be in a modified state", and it carries
/// everything needed to undo that state with no other information:
///
/// - Helper launch (crash restart via `KeepAlive.PathState`, or boot via
///   `RunAtLoad`): sentinel present → restore prior state, delete sentinel.
/// - Watchdog expiry: same.
/// - Version 2 scopes optional mutations exactly to the numeric prior values
///   below, making restore idempotent and non-destructive even when the user
///   had unusual pmset settings before arming.
public struct OverrideSentinel: Codable, Sendable, Equatable {
    /// Version 2 means optional pmset mutations are scoped exactly to the
    /// captured power sources. Version 1 used `-a`; its optional metadata
    /// cannot prove that every mutated source has a recorded prior.
    public static let currentVersion = 2

    public var version: Int
    public var armedAt: Date
    public var watchdogTTL: TimeInterval
    public var watchdogDeadline: Date

    /// Legacy wire field recording the value before the override. v5 refuses
    /// to arm over an external override and always restores ordinary sleep;
    /// the field remains so older on-disk sentinels can still be decoded.
    public var priorSleepDisabled: Bool
    /// Prior Low Power Mode value per pmset section ("Battery Power"/"AC
    /// Power"), nil when LPM automation was off for this session.
    public var priorLowPowerMode: [String: Int]?
    /// The pmset key that manages Low Power Mode on this system —
    /// "lowpowermode" on older releases, "powermode" on newer ones. Restore
    /// must write back through the same key the priors were captured from.
    public var lowPowerModeKey: String?
    /// Prior `tcpkeepalive` per section, nil when network-alive was off.
    public var priorTCPKeepAlive: [String: Int]?

    public init(
        version: Int = OverrideSentinel.currentVersion,
        armedAt: Date,
        watchdogTTL: TimeInterval,
        watchdogDeadline: Date,
        priorSleepDisabled: Bool,
        priorLowPowerMode: [String: Int]? = nil,
        lowPowerModeKey: String? = nil,
        priorTCPKeepAlive: [String: Int]? = nil
    ) {
        self.version = version
        self.armedAt = armedAt
        self.watchdogTTL = watchdogTTL
        self.watchdogDeadline = watchdogDeadline
        self.priorSleepDisabled = priorSleepDisabled
        self.priorLowPowerMode = priorLowPowerMode
        self.lowPowerModeKey = lowPowerModeKey
        self.priorTCPKeepAlive = priorTCPKeepAlive
    }
}

// MARK: - JSON coding shared by app & helper

public enum IPCCoding {
    public static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    public static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }

    public static func encode<T: Encodable>(_ value: T) -> Data {
        (try? encoder().encode(value)) ?? Data()
    }

    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) -> T? {
        try? decoder().decode(type, from: data)
    }
}
