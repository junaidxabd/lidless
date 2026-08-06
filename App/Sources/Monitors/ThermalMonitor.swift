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
    /// Completes only after a poll whose request began at or after the stated
    /// boundary. A periodic request already in flight is awaited, then reused
    /// only when its conservative start timestamp satisfies that boundary.
    func pollNow(notBefore: Date) async
}

@MainActor
final class PMSetThermalMonitor: ThermalMonitoring {
    static let pollInterval: TimeInterval = 90

    private(set) var reading: ThermalReading?
    private(set) var processLevel: ProcessThermalLevel = .nominal
    var onChange: (@MainActor () -> Void)?

    private var pollTask: Task<Void, Never>?
    private var inFlightPoll: (
        id: UUID,
        startedAt: Date,
        task: Task<Void, Never>
    )?
    private var observer: (any NSObjectProtocol)?

    func start() {
        guard pollTask == nil else { return }

        processLevel = Self.level(from: ProcessInfo.processInfo.thermalState)
        onChange?()
        observer = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
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
                await self?.pollNow(notBefore: .distantPast)
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

    func pollNow(notBefore: Date) async {
        // A safety-boundary caller may arrive behind the periodic request.
        // Await older work so commands never overlap, then start a new sample
        // instead of relabeling the older output with a later timestamp.
        while let inFlight = inFlightPoll {
            await inFlight.task.value
            if inFlightPoll?.id == inFlight.id {
                inFlightPoll = nil
            }
            if inFlight.startedAt >= notBefore {
                return
            }
        }

        let id = UUID()
        let startedAt = Date()
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.performPoll(sampledAt: startedAt)
        }
        inFlightPoll = (id, startedAt, task)
        await task.value
        if inFlightPoll?.id == id {
            inFlightPoll = nil
        }
    }

    private func performPoll(sampledAt: Date) async {
        processLevel = Self.level(from: ProcessInfo.processInfo.thermalState)
        let output = try? await ProcessRunner.run("/usr/bin/pmset", ["-g", "therm"])
        // The command can remain in flight for its bounded timeout. Sample the
        // independent pressure signal again at completion for arm admission.
        processLevel = Self.level(from: ProcessInfo.processInfo.thermalState)
        guard let output else {
            reading = nil
            onChange?()
            return
        }
        let parsed = PMSetParser.parseTherm(output, sampledAt: sampledAt)
        reading = ThermalEvidenceSafety.accepted(parsed, at: Date())
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
