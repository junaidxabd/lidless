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
    /// Actual `disablesleep` state, read back from the root domain.
    private(set) var overrideActive = false

    var onWake: (@MainActor () -> Void)?
    var onWillSleep: (@MainActor () -> Void)?
    var onChange: (@MainActor () -> Void)?

    private var observers: [any NSObjectProtocol] = []

    func start() {
        refresh()
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { _ in
            Task { @MainActor [weak self] in
                self?.refresh()
                self?.onWake?()
            }
        })
        observers.append(center.addObserver(
            forName: NSWorkspace.willSleepNotification, object: nil, queue: .main
        ) { _ in
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
        let override = PowerRegistry.sleepDisabled() ?? false
        let changed = clamshell != (hasLid ? lidClosed : nil) || override != overrideActive

        hasLid = clamshell != nil
        lidClosed = clamshell ?? false
        overrideActive = override
        if changed {
            onChange?()
        }
    }
}
