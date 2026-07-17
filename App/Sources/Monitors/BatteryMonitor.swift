import Foundation
import IOKit.ps
import LidlessCore

/// Event-driven battery state. Real implementation rides IOKit power-source
/// notifications; the simulator conforms to the same protocol for dry runs.
@MainActor
protocol BatteryMonitoring: AnyObject {
    var current: BatterySnapshot { get }
    var onChange: (@MainActor (BatterySnapshot) -> Void)? { get set }
    func start()
    func stop()
    /// Synchronous re-read; the tick loop's freeze-proof fallback alongside
    /// the event source.
    func refresh()
}

@MainActor
final class IOPSBatteryMonitor: BatteryMonitoring {
    private(set) var current: BatterySnapshot = .unknown(at: Date())
    var onChange: (@MainActor (BatterySnapshot) -> Void)?

    private var runLoopSource: CFRunLoopSource?

    func start() {
        guard runLoopSource == nil else { return }
        refresh()

        let context = Unmanaged.passUnretained(self).toOpaque()
        // The callback fires on the run loop the source is scheduled on —
        // the main run loop — so hopping straight to MainActor is sound.
        let callback: IOPowerSourceCallbackType = { context in
            guard let context else { return }
            let monitor = Unmanaged<IOPSBatteryMonitor>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated {
                monitor.refresh()
            }
        }

        guard let source = IOPSNotificationCreateRunLoopSource(callback, context)?.takeRetainedValue() else {
            // No notification source (should not happen); the app's tick loop
            // still refreshes via `refresh()` calls.
            return
        }
        // .commonModes, not .defaultMode: events must keep flowing while a
        // menu or modal tracking loop is up.
        CFRunLoopAddSource(CFRunLoopGetMain(), source, CFRunLoopMode.commonModes)
        runLoopSource = source
    }

    func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, CFRunLoopMode.commonModes)
        }
        runLoopSource = nil
    }

    func refresh() {
        let snapshot = Self.read(at: Date())
        let changed = snapshot.percent != current.percent
            || snapshot.state != current.state
            || snapshot.isCharging != current.isCharging
        current = snapshot
        if changed {
            onChange?(snapshot)
        }
    }

    /// One IOKit read of the internal battery, normalized.
    static func read(at date: Date) -> BatterySnapshot {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef]
        else {
            return .unknown(at: date)
        }

        for source in list {
            guard let description = IOPSGetPowerSourceDescription(blob, source)?
                .takeUnretainedValue() as? [String: Any],
                description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType
            else { continue }

            var percent: Int?
            if let capacity = description[kIOPSCurrentCapacityKey] as? Int {
                let maxCapacity = description[kIOPSMaxCapacityKey] as? Int ?? 100
                percent = maxCapacity > 0 ? Int((Double(capacity) / Double(maxCapacity) * 100).rounded()) : capacity
            }

            let onAC = (description[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
            let isCharging = description[kIOPSIsChargingKey] as? Bool ?? false
            var timeToEmpty = description[kIOPSTimeToEmptyKey] as? Int
            if let value = timeToEmpty, value <= 0 { timeToEmpty = nil }

            return BatterySnapshot(
                percent: percent,
                state: onAC ? .ac : .battery,
                isCharging: isCharging,
                timeToEmptyMinutes: timeToEmpty,
                sampledAt: date
            )
        }

        // No internal battery: desktop. Always on AC, battery cutoffs dormant.
        return BatterySnapshot(percent: nil, state: .ac, isCharging: false, sampledAt: date)
    }
}
