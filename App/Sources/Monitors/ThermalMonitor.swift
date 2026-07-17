import Foundation
import LidlessCore

/// Thermal picture from two sources: `pmset -g therm` polled every 90s
/// (warning level + CPU speed limit — the spec'd signals) and
/// `ProcessInfo.thermalState` (event-driven, catches pressure between polls).
@MainActor
protocol ThermalMonitoring: AnyObject {
    var reading: ThermalReading? { get }
    var processLevel: ProcessThermalLevel { get }
    var onChange: (@MainActor () -> Void)? { get set }
    func start()
    func stop()
    func pollNow() async
}

@MainActor
final class PMSetThermalMonitor: ThermalMonitoring {
    static let pollInterval: TimeInterval = 90

    private(set) var reading: ThermalReading?
    private(set) var processLevel: ProcessThermalLevel = .nominal
    var onChange: (@MainActor () -> Void)?

    private var pollTask: Task<Void, Never>?
    private var observer: (any NSObjectProtocol)?

    func start() {
        guard pollTask == nil else { return }

        processLevel = Self.level(from: ProcessInfo.processInfo.thermalState)
        observer = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            // Notification arrives on the main queue; re-enter the actor
            // explicitly to keep Swift 6 happy.
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.processLevel = Self.level(from: ProcessInfo.processInfo.thermalState)
                self.onChange?()
            }
        }

        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.pollNow()
                try? await Task.sleep(for: .seconds(Self.pollInterval))
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        observer = nil
    }

    func pollNow() async {
        guard let output = try? await ProcessRunner.run("/usr/bin/pmset", ["-g", "therm"]) else {
            return
        }
        reading = PMSetParser.parseTherm(output, sampledAt: Date())
        onChange?()
    }

    static func level(from state: ProcessInfo.ThermalState) -> ProcessThermalLevel {
        switch state {
        case .nominal: .nominal
        case .fair: .fair
        case .serious: .serious
        case .critical: .critical
        @unknown default: .serious
        }
    }
}
