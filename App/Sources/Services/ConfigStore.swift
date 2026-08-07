import Foundation
import LidlessCore

enum AppPaths {
    static func supportDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("Lidless", isDirectory: true)
    }

    static func ensureSupportDirectory() throws -> URL {
        let url = supportDirectory()
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

enum StorePersistenceResult: Equatable {
    case notAttempted
    case succeeded
    case failed(String)

    var errorMessage: String? {
        guard case .failed(let message) = self else { return nil }
        return message
    }
}

/// All user preferences, persisted as one JSON document in Application
/// Support (not UserDefaults: one legible file the user can inspect and back
/// up independently of any privileged-helper lifecycle).
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

    private(set) var lastPersistenceError: String?
    private(set) var lastLoadResult: StorePersistenceResult = .notAttempted
    private(set) var lastSaveResult: StorePersistenceResult = .notAttempted

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
        config = AppConfig()
        guard !ephemeral else { return }

        let url = Self.fileURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            lastLoadResult = .succeeded
            return
        }
        do {
            let data = try Data(contentsOf: url)
            config = try IPCCoding.decoder().decode(AppConfig.self, from: data)
            lastLoadResult = .succeeded
        } catch {
            let message = "Settings could not be loaded (\(error.localizedDescription)). Lidless is using safe defaults; check access to Application Support."
            lastLoadResult = .failed(message)
            lastPersistenceError = message
        }
    }

    @discardableResult
    private func persist() -> StorePersistenceResult {
        guard !ephemeral else { return .notAttempted }
        do {
            _ = try AppPaths.ensureSupportDirectory()
            let data = try IPCCoding.encoder().encode(config)
            try data.write(to: Self.fileURL(), options: .atomic)
            return recordSave(.succeeded)
        } catch {
            let message = "Settings could not be saved (\(error.localizedDescription)). Changes remain active for this run; check access to Application Support."
            return recordSave(.failed(message))
        }
    }

    /// Explicit local-data reset support. This does not remove or alter the
    /// privileged helper and is not exposed as automatic helper cleanup.
    @discardableResult
    func deleteAllData() -> StorePersistenceResult {
        guard !ephemeral else { return .notAttempted }
        do {
            let support = AppPaths.supportDirectory()
            if FileManager.default.fileExists(atPath: support.path) {
                try FileManager.default.removeItem(at: support)
            }
            for widgetData in WidgetStore.allSnapshotURLs()
            where FileManager.default.fileExists(atPath: widgetData.path) {
                try FileManager.default.removeItem(at: widgetData)
            }
            return recordSave(.succeeded)
        } catch {
            let message = "Lidless data could not be fully deleted (\(error.localizedDescription)). Check Application Support before retrying."
            return recordSave(.failed(message))
        }
    }

    @discardableResult
    private func recordSave(
        _ result: StorePersistenceResult
    ) -> StorePersistenceResult {
        lastSaveResult = result
        lastPersistenceError = result.errorMessage
        return result
    }
}
