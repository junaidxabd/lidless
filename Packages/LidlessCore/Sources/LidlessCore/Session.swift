import Foundation

// MARK: - How a session ended

public enum SessionEndReason: Codable, Sendable, Equatable, Hashable {
    case cutoff(CutoffReason)
    /// User disarmed (power button, menu, widget link, or quit-and-disarm).
    case manual
    case appQuit
    /// Helper watchdog expired because the app stopped checking in.
    case helperWatchdog
    /// Helper restarted (crash or upgrade) and restored sleep as a precaution.
    case helperRestored
    /// System slept anyway (user forced sleep); the override was released.
    case systemSlept
    case uninstalled

    public var isCutoff: Bool {
        if case .cutoff = self { return true }
        return false
    }
}

public enum SessionSource: Codable, Sendable, Equatable, Hashable {
    case manual
    case preset(ArmPreset)
    case schedule(windowID: UUID)
}

// MARK: - Session record

/// One keep-awake session, from arm to disarm, with its battery curve.
public struct KeepAwakeSession: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var startedAt: Date
    public var endedAt: Date?
    public var endReason: SessionEndReason?
    public var source: SessionSource

    public var startPercent: Int?
    public var endPercent: Int?
    /// Sampled roughly every 5 minutes while armed, plus arm/disarm edges.
    public var samples: [BatterySample]

    /// Snapshot of the cutoffs in force, for display ("Floor 10% · Until 7:00 AM").
    public var cutoffSummary: String
    public var lowPowerModeUsed: Bool
    public var tcpKeepAliveUsed: Bool

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date? = nil,
        endReason: SessionEndReason? = nil,
        source: SessionSource = .manual,
        startPercent: Int? = nil,
        endPercent: Int? = nil,
        samples: [BatterySample] = [],
        cutoffSummary: String = "",
        lowPowerModeUsed: Bool = false,
        tcpKeepAliveUsed: Bool = false
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.endReason = endReason
        self.source = source
        self.startPercent = startPercent
        self.endPercent = endPercent
        self.samples = samples
        self.cutoffSummary = cutoffSummary
        self.lowPowerModeUsed = lowPowerModeUsed
        self.tcpKeepAliveUsed = tcpKeepAliveUsed
    }

    public var duration: TimeInterval? {
        endedAt.map { $0.timeIntervalSince(startedAt) }
    }

    /// Total percentage points drained over the session (positive number).
    public var totalDrain: Double? {
        guard let start = startPercent, let end = endPercent, start >= end else { return nil }
        return Double(start - end)
    }

    /// Average drain over the whole session, percent per hour.
    public var averageDrainPerHour: Double? {
        guard let drain = totalDrain, let duration, duration > 600 else { return nil }
        return drain / (duration / 3600)
    }
}
