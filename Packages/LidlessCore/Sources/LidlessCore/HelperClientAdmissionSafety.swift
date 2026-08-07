/// Server-side admission for operations whose client compatibility matters.
/// This complements, and never replaces, the XPC code-signing requirement.
public enum HelperClientOperation: Sendable, CaseIterable {
    case arm
    case scheduleWake
    case forceSleep
    case restoreNormalSleep
    case cancelWake
    case repairOverride
}

public enum HelperClientAdmissionSafety {
    public static func allows(
        _ operation: HelperClientOperation,
        identity: HelperClientIdentity?
    ) -> Bool {
        switch operation {
        case .arm, .scheduleWake, .forceSleep:
            identity == .current
        case .restoreNormalSleep, .cancelWake, .repairOverride:
            true
        }
    }
}
