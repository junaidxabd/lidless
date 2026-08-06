/// Pure fail-closed decisions for removing privileged helper supervision.
///
/// Removing an enabled registration also removes launchd's recovery
/// supervision. Authorization therefore requires exact evidence that normal
/// sleep was restored before the client may request deregistration.
public enum HelperRemovalSafety {
    public enum RegistrationState: Sendable, Equatable {
        /// The daemon is registered and may have supervised an override.
        case enabled
        /// The service is explicitly not registered.
        case inactive
        /// A future or otherwise unclassified service state.
        case unknown
    }

    /// The authorized next step after classifying the registration. An
    /// explicitly inactive service has no registration left to remove, so it
    /// completes without invoking the deregistration API.
    public enum RegistrationRemovalAction: Sendable, Equatable {
        case unregister
        case alreadyInactive
    }

    public static func removalAction(
        _ registrationState: RegistrationState,
        helperReply: HelperReply?,
        independentlyObserved: Bool?
    ) -> RegistrationRemovalAction? {
        switch registrationState {
        case .enabled:
            guard let helperReply,
                  SleepOverrideSafety.isReviewedCleanupCompatibleHelper(
                    helperReply.status
                  ),
                  SleepOverrideSafety.isRestoreProven(
                      helperReply,
                      independentlyObserved: independentlyObserved
                  )
            else { return nil }
            return .unregister
        case .inactive:
            guard SleepOverrideSafety.isVerified(
                expected: false,
                observed: independentlyObserved
            ) else { return nil }
            return .alreadyInactive
        case .unknown:
            return nil
        }
    }
}
