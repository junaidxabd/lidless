/// The privileged mutation used by one non-sleep restoration generation.
///
/// If a repair attempt returns without complete proof, every subsequent
/// attempt must remain a repair. Downgrading it to a plain disarm can never
/// create the recovery sentinel needed to restore an override Lidless does not
/// yet own. Repair is also deliberately unable to inherit session-finalization,
/// force-sleep, or outside-ownership escape semantics from ordinary disarm.
public enum NonSleepRestoreActuation: Sendable, Equatable {
    case disarm
    case repairOverride

    public func allowsConfiguration(
        forceSleepRequested: Bool,
        finalizesSession: Bool,
        allowsUnownedExternalOverrideCompletion: Bool
    ) -> Bool {
        switch self {
        case .disarm:
            true
        case .repairOverride:
            !forceSleepRequested
                && !finalizesSession
                && !allowsUnownedExternalOverrideCompletion
        }
    }
}
