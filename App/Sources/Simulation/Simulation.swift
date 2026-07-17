import Foundation
import LidlessCore
import os

/// Dry-run mode (`--simulate`): the full app — arming flow, cutoff engine,
/// sessions, notifications, UI — runs against synthetic battery/thermal
/// inputs and a fake helper. Nothing privileged is touched; the Simulator
/// pane in the main window drives the knobs.
@MainActor
@Observable
final class SimulationController {
    // Knobs.
    var batteryPercent: Double = 68
    var onBattery = true
    var charging = false
    /// Simulated drain speed while discharging.
    var drainPerHour: Double = 9
    /// Simulated seconds that pass per real second (speed up overnight runs).
    var timeScale: Double = 60
    var thermalWarningLevel = 0
    var cpuSpeedLimit = 100
    var processLevel: ProcessThermalLevel = .nominal
    var lidClosed = false

    fileprivate(set) var log: [String] = []

    func note(_ line: String) {
        log.append("\(Date().formatted(date: .omitted, time: .standard))  \(line)")
        if log.count > 200 { log.removeFirst(log.count - 200) }
    }

    /// Advance the simulated battery by `dt` real seconds.
    fileprivate func advance(by dt: TimeInterval) {
        let simSeconds = dt * timeScale
        if onBattery, !charging {
            batteryPercent = max(0, batteryPercent - drainPerHour * simSeconds / 3600)
        } else if charging {
            batteryPercent = min(100, batteryPercent + 25 * simSeconds / 3600)
        }
    }

    fileprivate func batterySnapshot(at date: Date) -> BatterySnapshot {
        BatterySnapshot(
            percent: Int(batteryPercent.rounded()),
            state: onBattery ? .battery : .ac,
            isCharging: charging,
            timeToEmptyMinutes: nil,
            sampledAt: date
        )
    }

    fileprivate func thermalReading(at date: Date) -> ThermalReading {
        ThermalReading(
            warningLevel: thermalWarningLevel,
            cpuSpeedLimit: cpuSpeedLimit,
            schedulerLimit: nil,
            availableCPUs: nil,
            sampledAt: date
        )
    }
}

// MARK: - Simulated monitors

@MainActor
final class SimulatedBatteryMonitor: BatteryMonitoring {
    private let controller: SimulationController
    private var timerTask: Task<Void, Never>?
    private(set) var current: BatterySnapshot
    var onChange: (@MainActor (BatterySnapshot) -> Void)?

    init(controller: SimulationController) {
        self.controller = controller
        self.current = controller.batterySnapshot(at: Date())
    }

    func start() {
        guard timerTask == nil else { return }
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                self.controller.advance(by: 1)
                let snapshot = self.controller.batterySnapshot(at: Date())
                let changed = snapshot.percent != self.current.percent
                    || snapshot.state != self.current.state
                    || snapshot.isCharging != self.current.isCharging
                self.current = snapshot
                if changed { self.onChange?(snapshot) }
            }
        }
    }

    func stop() {
        timerTask?.cancel()
        timerTask = nil
    }

    func refresh() {
        current = controller.batterySnapshot(at: Date())
    }
}

@MainActor
final class SimulatedThermalMonitor: ThermalMonitoring {
    private let controller: SimulationController
    var onChange: (@MainActor () -> Void)?

    init(controller: SimulationController) {
        self.controller = controller
    }

    var reading: ThermalReading? { controller.thermalReading(at: Date()) }
    var processLevel: ProcessThermalLevel { controller.processLevel }

    func start() {}
    func stop() {}
    func pollNow() async {
        onChange?()
    }
}

// MARK: - Simulated helper

/// Mirrors the real daemon's observable semantics (arm/disarm/status/
/// watchdog bookkeeping) without touching the system.
@MainActor
final class SimulatedHelper: HelperControlling {
    private let controller: SimulationController
    private let logger = Logger(subsystem: LidlessIDs.appBundleID, category: "simulated-helper")

    private(set) var installState: HelperInstallState = .simulated
    var onInterruption: (@MainActor () -> Void)?

    private var armed = false
    private var armedSince: Date?
    private var watchdogDeadline: Date?
    private var ttl: TimeInterval = HelperArmOptions.defaultWatchdogTTL

    /// What `PowerRegistry.sleepDisabled()` would report.
    private(set) var sleepDisabled = false

    init(controller: SimulationController) {
        self.controller = controller
    }

    func refreshInstallState() async {}

    func install() async throws {}

    func openApprovalSettings() {}

    func uninstall() async throws {
        armed = false
        sleepDisabled = false
        controller.note("helper: uninstalled (simulated)")
    }

    func status() async throws -> HelperStatus {
        HelperStatus(
            helperVersion: LidlessIDs.helperVersion,
            armed: armed,
            sleepDisabled: sleepDisabled,
            armedSince: armedSince,
            watchdogDeadline: watchdogDeadline
        )
    }

    func arm(_ options: HelperArmOptions) async throws -> HelperReply {
        armed = true
        sleepDisabled = true
        armedSince = Date()
        ttl = options.watchdogTTL
        watchdogDeadline = Date().addingTimeInterval(ttl)
        controller.note("helper: ARM (override on, ttl \(Int(ttl))s, lpm \(options.lowPowerMode), tcp \(options.tcpKeepAlive))")
        logger.info("simulated arm")
        return HelperReply(ok: true, status: try await status())
    }

    func heartbeat() async throws -> HelperReply {
        guard armed else {
            return HelperReply(ok: false, error: "no active session", status: try await status())
        }
        watchdogDeadline = Date().addingTimeInterval(ttl)
        return HelperReply(ok: true, status: try await status())
    }

    func disarm(_ options: HelperDisarmOptions) async throws -> HelperReply {
        armed = false
        sleepDisabled = false
        armedSince = nil
        watchdogDeadline = nil
        controller.note("helper: DISARM (\(options.reason))\(options.forceSleep ? " → pmset sleepnow" : "")")
        logger.info("simulated disarm")
        return HelperReply(ok: true, status: try await status())
    }

    func repairOverride() async throws -> HelperReply {
        sleepDisabled = false
        controller.note("helper: repair override → disablesleep 0")
        return HelperReply(ok: true, status: try await status())
    }

    func scheduleWake(_ date: Date?) async throws {
        if let date {
            controller.note("helper: schedule wake \(date.formatted(date: .abbreviated, time: .shortened))")
        } else {
            controller.note("helper: cancel scheduled wake")
        }
    }
}
