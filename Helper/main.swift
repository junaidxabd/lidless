import Foundation

// LidlessHelper — the privileged daemon behind Lidless.
// Managed by launchd via SMAppService; see com.lidless.helper.plist.
// It exists to run four pmset operations safely: disablesleep, sleepnow,
// low-power-mode, tcpkeepalive — and to guarantee the first of those is
// always undone. All policy lives in the app.

let daemon = HelperDaemon()
daemon.start()
dispatchMain()
