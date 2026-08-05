/// Lifecycle context needed to present the system-wide sleep override without
/// confusing app intent with verified system state.
public enum SleepPresentationPhase: String, Codable, Sendable, Equatable {
    case disarmed
    case arming
    case armed
    case restoring
}

/// The only sleep-state claims the app and widget may present.
public enum SleepPresentationState: String, Codable, Sendable, Equatable {
    case verifiedNormal
    case verifyingArm
    case verifiedArmed
    case restoring
    case outsideOverride
    case unknown
}

/// Fail-closed presentation policy shared by the app and its widget mirror.
public enum SleepPresentationPolicy {
    public static func resolve(
        phase: SleepPresentationPhase,
        observedOverride: Bool?,
        helperSessionProven: Bool
    ) -> SleepPresentationState {
        switch phase {
        case .disarmed:
            switch observedOverride {
            case false: .verifiedNormal
            case true: .outsideOverride
            case nil: .unknown
            }
        case .arming:
            .verifyingArm
        case .armed:
            helperSessionProven && observedOverride == true ? .verifiedArmed : .unknown
        case .restoring:
            .restoring
        }
    }
}
