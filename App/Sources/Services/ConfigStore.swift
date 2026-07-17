import Foundation
import LidlessCore

enum AppPaths {
    static func supportDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("Lidless", isDirectory: true)
    }

    static func ensureSupportDirectory() -> URL {
        let url = supportDirectory()
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

/// All user preferences, persisted as one JSON document in Application
/// Support (not UserDefaults: one legible file the user can inspect, and
/// exactly one thing to delete at uninstall).
@MainActor
@Observable
final class ConfigStore {
    struct AppConfig: Codable, Equatable {
        var cutoffs = CutoffConfig()
        var behavior = BehaviorConfig()
        var schedules: [ScheduleWindow] = []
        var scheduleAutomationEnabled = false
        var onboardingComplete = false
    }

    private var config: AppConfig {
        didSet { if config != oldValue { persist() } }
    }

    var cutoffs: CutoffConfig {
        get { config.cutoffs }
        set { config.cutoffs = newValue }
    }

    var behavior: BehaviorConfig {
        get { config.behavior }
        set { config.behavior = newValue }
    }

    var schedules: [ScheduleWindow] {
        get { config.schedules }
        set { config.schedules = newValue }
    }

    var scheduleAutomationEnabled: Bool {
        get { config.scheduleAutomationEnabled }
        set { config.scheduleAutomationEnabled = newValue }
    }

    var onboardingComplete: Bool {
        get { config.onboardingComplete }
        set { config.onboardingComplete = newValue }
    }

    private static func fileURL() -> URL {
        AppPaths.supportDirectory().appendingPathComponent("config.json")
    }

    /// Simulation/dry-run must leave zero footprint: ephemeral stores never
    /// read or write the real user's config.
    private let ephemeral: Bool

    init(ephemeral: Bool = false) {
        self.ephemeral = ephemeral
        if !ephemeral,
           let data = try? Data(contentsOf: Self.fileURL()),
           let loaded = IPCCoding.decode(AppConfig.self, from: data) {
            config = loaded
        } else {
            config = AppConfig()
        }
    }

    private func persist() {
        guard !ephemeral else { return }
        _ = AppPaths.ensureSupportDirectory()
        try? IPCCoding.encoder().encode(config).write(to: Self.fileURL(), options: .atomic)
    }

    /// Uninstall support: removes every file the app ever wrote.
    static func deleteAllData() {
        try? FileManager.default.removeItem(at: AppPaths.supportDirectory())
        if let widgetData = WidgetStore.snapshotURL() {
            try? FileManager.default.removeItem(at: widgetData)
        }
    }
}
