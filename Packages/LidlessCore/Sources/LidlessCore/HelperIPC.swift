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
    /// Arming while a session is already active is rejected. An established
    /// session is renewed only by owner-bound heartbeats.
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

    /// Current structured schedule/cancel request. Risk-increasing schedules
    /// require an exact current client identity. Reply: `HelperReply`.
    func scheduleWakeRequest(
        _ requestJSON: Data,
        reply: @escaping @Sendable (Data) -> Void
    )

    /// Compatibility selector retained for installed clients. Current helpers
    /// return a fresh status plus a reviewed-removal-required refusal and
    /// issue no authorization or mutation. Reply: `HelperCleanupPreparation`.
    func prepareUninstall(_ reply: @escaping @Sendable (Data) -> Void)

    /// Compatibility selector retained for installed clients. Current helpers
    /// ignore the payload and refuse without restoration, wake, filesystem,
    /// or registration mutation. Reply: `HelperReply`.
    func commitUninstall(
        _ authorizationJSON: Data,
        reply: @escaping @Sendable (Data) -> Void
    )

    /// Legacy protocol-v6 selector. Current helpers refuse without mutation;
    /// it remains present so an older app receives a structured failure.
    func uninstall(_ reply: @escaping @Sendable (Data) -> Void)
}

// MARK: - Payloads

/// Self-declared client compatibility carried on risk-increasing requests.
/// XPC code-signing admission establishes the app's signed identity; this
/// exact pair separately prevents an older or future genuine client from
/// invoking behavior it does not share with the current helper.
public struct HelperClientIdentity: Codable, Sendable, Equatable {
    public var protocolVersion: Int
    public var safetyRevision: Int

    public init(protocolVersion: Int, safetyRevision: Int) {
        self.protocolVersion = protocolVersion
        self.safetyRevision = safetyRevision
    }

    public static let current = HelperClientIdentity(
        protocolVersion: LidlessIDs.helperVersion,
        safetyRevision: LidlessIDs.helperSafetyRevision
    )
}

public struct HelperArmOptions: Codable, Sendable, Equatable {
    /// The app heartbeats every ~10s; the helper restores sleep if none
    /// arrives for this long.
    public var watchdogTTL: TimeInterval
    public var lowPowerMode: Bool
    public var tcpKeepAlive: Bool
    /// Missing only for legacy payloads, which the helper must refuse before
    /// any risk-increasing mutation.
    public var clientIdentity: HelperClientIdentity?

    public init(
        watchdogTTL: TimeInterval = HelperArmOptions.defaultWatchdogTTL,
        lowPowerMode: Bool = false,
        tcpKeepAlive: Bool = false,
        clientIdentity: HelperClientIdentity? = .current
    ) {
        self.watchdogTTL = watchdogTTL
        self.lowPowerMode = lowPowerMode
        self.tcpKeepAlive = tcpKeepAlive
        self.clientIdentity = clientIdentity
    }

    public static let defaultWatchdogTTL: TimeInterval = 45
    public static let heartbeatInterval: TimeInterval = 10
    /// Watchdog TTLs outside this range are clamped by the helper — the app
    /// can never talk the helper into an unsupervised override.
    public static let watchdogTTLRange: ClosedRange<TimeInterval> = 45...120
}

public struct HelperDisarmOptions: Codable, Sendable, Equatable {
    public var forceSleep: Bool
    /// For the helper log, e.g. "battery floor 10%".
    public var reason: String
    /// Required only when `forceSleep` is true. Ordinary restore remains
    /// available to legacy clients because it can only reduce override risk.
    public var clientIdentity: HelperClientIdentity?

    public init(
        forceSleep: Bool,
        reason: String,
        clientIdentity: HelperClientIdentity? = .current
    ) {
        self.forceSleep = forceSleep
        self.reason = reason
        self.clientIdentity = clientIdentity
    }
}

public struct HelperScheduleWakeRequest: Codable, Sendable, Equatable {
    /// A desired RTC wake, or `nil` to cancel Lidless-managed wake events.
    public var desiredDate: Date?
    /// Missing only for legacy encoded requests. Scheduling requires the exact
    /// current identity; cancellation remains available without it.
    public var clientIdentity: HelperClientIdentity?

    public init(
        desiredDate: Date?,
        clientIdentity: HelperClientIdentity? = .current
    ) {
        self.desiredDate = desiredDate
        self.clientIdentity = clientIdentity
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

/// Opaque capability tying a cleanup commit to one helper process lifetime.
/// It is not an identity attestation; its only purpose is to make a helper
/// restart or XPC reconnect to a replacement process fail closed.
public struct HelperCleanupAuthorization: Codable, Sendable, Equatable {
    public var helperInstanceID: UUID

    public init(helperInstanceID: UUID) {
        self.helperInstanceID = helperInstanceID
    }
}

/// Non-cleanup first phase of helper removal. `authorization` is present only
/// when this process is willing to accept a matching commit.
public struct HelperCleanupPreparation: Codable, Sendable, Equatable {
    public var ok: Bool
    public var error: String?
    public var authorization: HelperCleanupAuthorization?
    public var status: HelperStatus

    public init(
        ok: Bool,
        error: String? = nil,
        authorization: HelperCleanupAuthorization? = nil,
        status: HelperStatus
    ) {
        self.ok = ok
        self.error = error
        self.authorization = authorization
        self.status = status
    }
}

// MARK: - Sentinel

/// Created exclusively at `HelperPaths.sentinel`, metadata-checked, fully
/// written, and accepted only after successful file/directory F_FULLFSYNC
/// requests and checked closes. After a Lidless mutation, deletion requires
/// verified restoration plus the same directory barrier; an unused prepared
/// marker may instead be removed after a proven pre-mutation rejection. Its
/// existence means "the system may be in a modified state". A crash during the
/// direct write may leave a partial/corrupt marker; when present, it forces
/// normal-sleep recovery rather than being decoded as trusted state. No
/// risk-increasing enable mutation occurs until every barrier succeeds. These
/// barriers fail closed but cannot prove that every physical device honors
/// cache-flush requests. A complete record carries everything needed to undo
/// the helper's optional changes with no other information:
///
/// - Helper launch (requested crash restart via `KeepAlive.PathState`, or boot
///   via `RunAtLoad`): trusted/restorable sentinel → restore prior state and
///   delete; corrupt/untrusted evidence → force ordinary sleep and stay pending.
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
