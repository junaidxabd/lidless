import Foundation

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
        self.recentSamples = recentSamples
        self.updatedAt = updatedAt
    }
}

/// Reads/writes the widget snapshot in the app-group container. Both sides
/// tolerate absence: a fresh install renders the widget's placeholder.
public enum WidgetStore {
    public static let maxSamples = 48

    public static func containerURL() -> URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: LidlessIDs.appGroupID
        )
    }

    public static func snapshotURL() -> URL? {
        containerURL()?.appendingPathComponent("widget-snapshot.json", isDirectory: false)
    }

    public static func load() -> WidgetSnapshot? {
        guard let url = snapshotURL(), let data = try? Data(contentsOf: url) else { return nil }
        return IPCCoding.decode(WidgetSnapshot.self, from: data)
    }

    @discardableResult
    public static func save(_ snapshot: WidgetSnapshot) -> Bool {
        guard let url = snapshotURL() else { return false }
        var trimmed = snapshot
        if trimmed.recentSamples.count > maxSamples {
            trimmed.recentSamples = Array(trimmed.recentSamples.suffix(maxSamples))
        }
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try IPCCoding.encoder().encode(trimmed).write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }
}
