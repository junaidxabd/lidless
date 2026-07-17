import Foundation
import IOKit

/// Unprivileged reads from the power-management root domain. This is how the
/// app *verifies* the override state instead of trusting what it believes it
/// set — the "never silently on" indicator is driven from here, and the
/// helper uses the same reads for post-`pmset` verification.
public enum PowerRegistry {

    public static func rootDomainBool(_ key: String) -> Bool? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        guard let raw = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0) else {
            return nil
        }
        return raw.takeRetainedValue() as? Bool
    }

    /// Actual current value of `pmset disablesleep` (the system-wide sleep
    /// override). nil = unreadable, treat as unknown rather than false.
    public static func sleepDisabled() -> Bool? {
        rootDomainBool("SleepDisabled")
    }

    /// Physical lid state. nil on desktops (no clamshell).
    public static func clamshellClosed() -> Bool? {
        rootDomainBool("AppleClamshellState")
    }
}
