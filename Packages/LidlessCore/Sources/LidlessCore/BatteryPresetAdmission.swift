/// Admission policy for presets whose stop condition depends on an internal
/// battery. Keeping this decision in the core makes telemetry transitions
/// testable without constructing the app's UI state.
public enum BatteryPresetAdmission {
    public static func isAttainable(
        source: SessionSource,
        battery: BatterySnapshot
    ) -> Bool {
        if case .preset(.untilTwentyPercent) = source {
            return battery.state != .noBattery
        }
        return true
    }
}
