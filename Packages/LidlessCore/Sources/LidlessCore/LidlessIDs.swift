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

    /// Bumped whenever the XPC surface or helper behavior changes; the app
    /// re-registers the daemon when the running helper reports an older value.
    public static let helperVersion = 4

    public static let appGroupID = "group.com.lidless.shared"
    public static let urlScheme = "lidless"

    public static let manualFallbackCommand = "sudo pmset -a disablesleep 0"
}

/// Filesystem locations owned by the privileged helper (root).
///
/// The sentinel is the keystone of crash recovery: it exists exactly while the
/// sleep override is active. launchd watches it via `KeepAlive.PathState`, so a
/// crashed helper is relaunched while it exists, and the helper's first act on
/// any launch is to restore normal sleep if it finds one.
public enum HelperPaths {
    public static let workDirectory = "/var/db/lidless"
    /// Path is hard-coded in com.lidless.helper.plist (KeepAlive.PathState).
    public static let sentinel = "/var/db/lidless/override-active"
    public static let log = "/var/db/lidless/helper.log"
}
