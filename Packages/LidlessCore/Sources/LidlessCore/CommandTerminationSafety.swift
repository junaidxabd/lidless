/// Classifies what a timeout handler actually proved about a child process.
/// Accepting a signal is not proof that the process exited; only an observed
/// termination closes the window in which a mutating command can complete.
public enum CommandTerminationSafety {
    public enum Result: Sendable, Equatable {
        case exited
        case killedAndReaped
        case unproven
    }

    public static func classify(
        killAccepted: Bool,
        exitObserved: Bool
    ) -> Result {
        guard exitObserved else { return .unproven }
        return killAccepted ? .killedAndReaped : .exited
    }

    public static func hasUnresolvedMutation(
        killAccepted: Bool,
        exitObserved: Bool
    ) -> Bool {
        classify(
            killAccepted: killAccepted,
            exitObserved: exitObserved
        ) == .unproven
    }
}
