import Foundation

public enum WidgetEvidenceFreshness: Sendable, Equatable {
    case fresh
    case expired
    case rejectedFuture
}

/// State the app publishes for the widget, via the shared app-group container.
/// The widget is a pure mirror: it renders this and never computes policy.
public struct WidgetSnapshot: Codable, Sendable, Equatable {
    public var armed: Bool
    /// Headline under the state, e.g. "Until 7:00 AM" or "Sleeping normally".
    public var statusLine: String
    public var batteryPercent: Int?
    public var isCharging: Bool
    public var drainPerHour: Double?
    /// Earliest projected cutoff (time-based or battery projection).
    public var projectedCutoff: Date?
    public var projectedCutoffLabel: String?
    /// Actual system-wide override state, for the "never silently on" promise.
    public var overrideActive: Bool
    /// `true` only when the app obtained a readable registry value. Optional
    /// so snapshots from older app builds decode as unknown, never as proof.
    public var overrideStateVerified: Bool?
    /// Canonical presentation state at publication time. Optional for wire
    /// compatibility; an older snapshot without it is always treated as
    /// unknown rather than reconstructed from incomplete legacy fields.
    public var sleepPresentation: SleepPresentationState?
    /// Recent battery curve (trailing ~4h, capped) for the sparkline.
    public var recentSamples: [BatterySample]
    public var updatedAt: Date

    public init(
        armed: Bool,
        statusLine: String,
        batteryPercent: Int?,
        isCharging: Bool,
        drainPerHour: Double? = nil,
        projectedCutoff: Date? = nil,
        projectedCutoffLabel: String? = nil,
        overrideActive: Bool = false,
        overrideStateVerified: Bool? = nil,
        sleepPresentation: SleepPresentationState? = nil,
        recentSamples: [BatterySample] = [],
        updatedAt: Date
    ) {
        self.armed = armed
        self.statusLine = statusLine
        self.batteryPercent = batteryPercent
        self.isCharging = isCharging
        self.drainPerHour = drainPerHour
        self.projectedCutoff = projectedCutoff
        self.projectedCutoffLabel = projectedCutoffLabel
        self.overrideActive = overrideActive
        self.overrideStateVerified = overrideStateVerified
        self.sleepPresentation = sleepPresentation
        self.recentSamples = recentSamples
        self.updatedAt = updatedAt
    }

    /// App snapshots are expected at least once a minute. Twenty minutes is a
    /// deliberately generous validity window; beyond it, the widget has no
    /// live evidence and must stop making either OFF or AWAKE claims.
    public static let freshnessLifetime: TimeInterval = 20 * 60
    /// Small scheduling/serialization skew is tolerated. A timestamp farther
    /// in the future indicates clock rollback or corrupt evidence.
    public static let futureTimestampTolerance: TimeInterval = 60

    public func evidenceFreshness(at date: Date) -> WidgetEvidenceFreshness {
        let age = date.timeIntervalSince(updatedAt)
        guard age.isFinite else { return .rejectedFuture }
        if age < -Self.futureTimestampTolerance { return .rejectedFuture }
        if age > Self.freshnessLifetime { return .expired }
        return .fresh
    }

    public func isFresh(at date: Date) -> Bool {
        evidenceFreshness(at: date) == .fresh
    }

    public func effectiveSleepPresentation(at date: Date) -> SleepPresentationState {
        guard isFresh(at: date), let sleepPresentation else { return .unknown }

        // The canonical field is still serialized evidence, not authority by
        // itself. Verified success states must agree with both the raw proof
        // and the legacy armed bit; contradictory or partial snapshots fail
        // closed so corrupt bytes cannot manufacture OFF or AWAKE.
        switch sleepPresentation {
        case .verifiedNormal:
            guard overrideStateVerified == true, !overrideActive, !armed else {
                return .unknown
            }
        case .verifiedArmed:
            guard overrideStateVerified == true, overrideActive, armed else {
                return .unknown
            }
        case .outsideOverride:
            guard overrideStateVerified == true, overrideActive, !armed else {
                return .unknown
            }
        case .verifyingArm, .restoring:
            guard !armed else { return .unknown }
        case .unknown:
            return .unknown
        }

        return sleepPresentation
    }
}

/// Reads/writes the widget snapshot in the app-group container. Both sides
/// tolerate absence: a fresh install renders the widget's placeholder.
public enum WidgetStore {
    public static let maxSamples = 48
    public static let currentSnapshotFileName = "widget-snapshot-v2.json"
    public static let legacySnapshotFileName = "widget-snapshot.json"

    public static func containerURL() -> URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: LidlessIDs.appGroupID
        )
    }

    public static func snapshotURL() -> URL? {
        containerURL()?.appendingPathComponent(currentSnapshotFileName, isDirectory: false)
    }

    public static func allSnapshotURLs() -> [URL] {
        guard let containerURL = containerURL() else { return [] }
        return [
            containerURL.appendingPathComponent(currentSnapshotFileName, isDirectory: false),
            containerURL.appendingPathComponent(legacySnapshotFileName, isDirectory: false),
        ]
    }

    public static func load() -> WidgetSnapshot? {
        guard let url = snapshotURL(), let data = try? Data(contentsOf: url) else { return nil }
        return IPCCoding.decode(WidgetSnapshot.self, from: data)
    }

    @discardableResult
    public static func save(_ snapshot: WidgetSnapshot) -> Bool {
        guard let containerURL = containerURL() else { return false }
        return save(snapshot, in: containerURL)
    }

    @discardableResult
    static func save(_ snapshot: WidgetSnapshot, in containerURL: URL) -> Bool {
        let url = containerURL.appendingPathComponent(currentSnapshotFileName, isDirectory: false)
        let legacyURL = containerURL.appendingPathComponent(legacySnapshotFileName, isDirectory: false)
        var trimmed = snapshot
        if trimmed.recentSamples.count > maxSamples {
            trimmed.recentSamples = Array(trimmed.recentSamples.suffix(maxSamples))
        }
        do {
            try FileManager.default.createDirectory(
                at: containerURL,
                withIntermediateDirectories: true
            )
            // The v1 schema cannot represent UNKNOWN. Remove it before making
            // v2 visible so an older extension reload fails to an empty state
            // instead of decoding unknown proof as ordinary OFF.
            if FileManager.default.fileExists(atPath: legacyURL.path) {
                try FileManager.default.removeItem(at: legacyURL)
            }
            try IPCCoding.encoder().encode(trimmed).write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }
}
