import Foundation

/// The exact risk-relevant settings authorized by one arm confirmation.
public struct ArmIntentPlan: Equatable, Sendable {
    public var cutoffs: CutoffConfig
    public var helperOptions: HelperArmOptions
    /// A scheduled arm is authorized only for this concrete live window.
    /// Manual and preset intents keep this nil.
    public var scheduledOccurrence: ScheduleEngine.Occurrence?

    public init(
        cutoffs: CutoffConfig,
        helperOptions: HelperArmOptions,
        scheduledOccurrence: ScheduleEngine.Occurrence? = nil
    ) {
        self.cutoffs = cutoffs
        self.helperOptions = helperOptions
        self.scheduledOccurrence = scheduledOccurrence
    }
}

/// Prevents a queued confirmation task from authorizing an arm intent that
/// replaced the one that created the task or whose safety plan changed.
public enum ArmIntentConfirmationSafety {
    public static func authorizes(
        expectedIntentID: UUID,
        currentIntentID: UUID,
        confirmedPlan: ArmIntentPlan,
        currentPlan: ArmIntentPlan
    ) -> Bool {
        expectedIntentID == currentIntentID && confirmedPlan == currentPlan
    }
}
