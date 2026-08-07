import Foundation

/// Stable identifiers shared between the app, the privileged helper, and the widget.
public enum LidlessIDs {
    public static let appBundleID = "com.lidless.app"
    public static let widgetBundleID = "com.lidless.app.widget"

    /// launchd label, mach service name, and the basename of the plist in
    /// Contents/Library/LaunchDaemons — all three must stay in sync.
    public static let helperLabel = "com.lidless.helper"
    public static let helperPlistName = "com.lidless.helper.plist"
    public static let helperMachService = "com.lidless.helper"

    /// Gates app-visible helper/XPC compatibility. This is not an attestation
    /// of executable freshness: backward-compatible internal fixes may retain
    /// the value, so callers must not infer which helper build is running.
    public static let helperVersion = 6

    /// Exact behavior contract required before this app accepts helper status
    /// as arm, restore, or ownership proof. Unlike the wire protocol
    /// version, this revision advances when a safety-critical helper behavior
    /// changes. It is self-reported compatibility evidence, not a cryptographic
    /// executable identity or a replacement/install receipt.
    public static let helperSafetyRevision = 8

    public static let appGroupID = "group.com.lidless.shared"
    public static let urlScheme = "lidless"

    public static let manualFallbackCommand = "sudo pmset -a disablesleep 0"
}

/// Filesystem locations owned by the privileged helper (root).
///
/// The sentinel conservatively marks that the helper may have modified system
/// state; it also exists during the durable pre-arm window and while recovery
/// evidence remains pending. `KeepAlive.PathState` requests keep/relaunch while
/// it exists. Actual launchd and crash-recovery behavior remain live gates.
public enum HelperPaths {
    public static let workDirectoryParent = "/var/db"
    public static let workDirectoryName = "lidless"
    public static let workDirectory =
        "\(workDirectoryParent)/\(workDirectoryName)"
    public static let sentinelFilename = "override-active"
    public static let durableMutationMarkerFilename = "mutation-in-flight.json"
    public static let scheduledWakeReconciliationMarkerFilename =
        "scheduled-wake-recovery-required.json"
    public static let scheduledWakeLedgerFilename = "scheduled-wake.json"
    /// Bound by tests to com.lidless.helper.plist (KeepAlive.PathState).
    public static let sentinel = "\(workDirectory)/\(sentinelFilename)"
    public static let durableMutationMarker =
        "\(workDirectory)/\(durableMutationMarkerFilename)"
    public static let scheduledWakeReconciliationMarker =
        "\(workDirectory)/\(scheduledWakeReconciliationMarkerFilename)"
    public static let log = "\(workDirectory)/helper.log"
}

/// A child process cannot survive a machine reboot. Process restart alone is
/// not equivalent: a reparented child from the same boot may still complete a
/// privileged mutation after its original helper exits.
public enum DurableMutationRecoverySafety {
    public static func priorChildExitIsProven(
        markerBootSessionUUID: UUID?,
        currentBootSessionUUID: UUID?
    ) -> Bool {
        guard let markerBootSessionUUID, let currentBootSessionUUID else {
            return false
        }
        return markerBootSessionUUID != currentBootSessionUUID
    }
}
