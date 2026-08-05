import AppKit
import Foundation
import LidlessCore

/// Lid state, system-wide override readback, and sleep/wake transitions.
///
/// Lid state has no reliable public notification, so it's polled cheaply
/// (one IORegistry property read) by the app's tick loop via `refresh()`,
/// plus refreshed on every battery event and wake. Sleep/wake arrive from
/// NSWorkspace notifications.
@MainActor
final class SystemStateMonitor {
    private(set) var lidClosed = false
    /// nil = machine has no clamshell (desktop).
    private(set) var hasLid = true
    /// Actual `disablesleep` state, read back from the root domain. `nil`
    /// means the registry could not be read and must never imply normal sleep.
    private(set) var overrideActive: Bool?
    /// Advances on every registry read, including unchanged and failed reads,
    /// so AppState can distinguish fresh evidence from cached monitor bytes.
    private(set) var overrideRevision: UInt64 = 0

    var onWake: (@MainActor () -> Void)?
    var onWillSleep: (@MainActor () -> Void)?
    var onChange: (@MainActor () -> Void)?

    private var observers: [any NSObjectProtocol] = []

    func start() {
        refresh()
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
                self?.onWake?()
            }
        })
        observers.append(center.addObserver(
            forName: NSWorkspace.willSleepNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.onWillSleep?()
            }
        })
    }

    func stop() {
        let center = NSWorkspace.shared.notificationCenter
        for observer in observers {
            center.removeObserver(observer)
        }
        observers = []
    }

    func refresh() {
        let clamshell = PowerRegistry.clamshellClosed()
        let override = PowerRegistry.sleepDisabled()
        overrideRevision &+= 1
        let changed = clamshell != (hasLid ? lidClosed : nil) || override != overrideActive

        hasLid = clamshell != nil
        lidClosed = clamshell ?? false
        overrideActive = override
        if changed {
            onChange?()
        }
    }
}
