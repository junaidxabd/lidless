import Foundation
import IOKit

public enum ClamshellHardwareEvidence: Sendable, Equatable {
    case present
    case absent
    case unavailable
}

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

    /// Separates documented hardware absence from an unreadable registry.
    /// Apple's IOPM contract defines a missing AppleClamshellState property on
    /// a readable root domain as hardware with no clamshell. A missing root
    /// domain or a malformed property remains unavailable evidence.
    public static func clamshellHardwareEvidence() -> ClamshellHardwareEvidence {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOPMrootDomain")
        )
        guard service != 0 else { return .unavailable }
        defer { IOObjectRelease(service) }

        var unmanagedProperties: Unmanaged<CFMutableDictionary>?
        let result = IORegistryEntryCreateCFProperties(
            service,
            &unmanagedProperties,
            kCFAllocatorDefault,
            0
        )
        guard result == KERN_SUCCESS, let unmanagedProperties else {
            return .unavailable
        }
        let properties = unmanagedProperties.takeRetainedValue() as NSDictionary
        guard let raw = properties["AppleClamshellState"] else {
            return .absent
        }
        guard raw as? Bool != nil else {
            return .unavailable
        }
        return .present
    }
}
