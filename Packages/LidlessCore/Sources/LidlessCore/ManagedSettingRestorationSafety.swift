/// Pure policy for the helper-owned Low Power Mode and `tcpkeepalive`
/// mutations recorded in an override sentinel.
///
/// Lidless may mutate only power-source scopes whose numeric prior was
/// captured. Restoration completes only after every captured value is visible
/// in a fresh `pmset -g custom` readback. An invalid legacy/corrupt snapshot is
/// therefore recovery work, never permission to discard the sentinel.
public enum ManagedSettingRestorationSafety {
    public enum Scope: String, CaseIterable, Sendable, Equatable {
        case battery = "Battery Power"
        case ac = "AC Power"
        case ups = "UPS Power"

        public var pmsetFlag: String {
            switch self {
            case .battery: "-b"
            case .ac: "-c"
            case .ups: "-u"
            }
        }
    }

    public struct SettingMutation: Sendable, Equatable {
        public var key: String
        public var value: Int

        public init(key: String, value: Int) {
            self.key = key
            self.value = value
        }
    }

    /// All settings for one power source are grouped into one bounded pmset
    /// invocation. Scope and setting order are deterministic.
    public struct ScopedMutation: Sendable, Equatable {
        public var scope: Scope
        public var settings: [SettingMutation]

        public init(scope: Scope, settings: [SettingMutation]) {
            self.scope = scope
            self.settings = settings
        }
    }

    public enum Target: Sendable, Equatable {
        case activation
        case restoration
    }

    /// Battery, AC, and UPS are the complete pmset power-source command set.
    public static let maximumScopeCommandCount = Scope.allCases.count

    private static let lowPowerModeKeys = ["lowpowermode", "powermode"]
    private static let managedKeys = Set(lowPowerModeKeys + ["tcpkeepalive"])

    /// Captures numeric values only from scopes that the helper can later
    /// address individually. An absent/unsupported/unparseable setting yields
    /// nil so the corresponding optional mutation is skipped.
    public static func capturedPriors(
        for key: String,
        fromCustom text: String
    ) -> [String: Int]? {
        guard managedKeys.contains(key) else { return nil }
        guard let parsed = try? PMSetParser.parseCustomStrict(text) else {
            return nil
        }
        var priors: [String: Int] = [:]
        for scope in Scope.allCases {
            guard let rawValue = parsed[scope.rawValue]?[key],
                  let value = Int(rawValue)
            else { continue }
            priors[scope.rawValue] = value
        }
        return priors.isEmpty ? nil : priors
    }

    /// Produces an all-or-nothing valid plan from sentinel state. Returning
    /// nil means the snapshot is internally inconsistent or names a scope/key
    /// the helper cannot safely restore.
    public static func plan(
        for record: OverrideSentinel,
        target: Target
    ) -> [ScopedMutation]? {
        if record.version != OverrideSentinel.currentVersion {
            // Version 1 remains safely recoverable only when it contains no
            // optional state. Its `-a` activation could otherwise have
            // mutated scopes absent from the recorded prior dictionaries.
            let isPlainVersionOne = record.version == 1
                && record.lowPowerModeKey == nil
                && record.priorLowPowerMode == nil
                && record.priorTCPKeepAlive == nil
            return target == .restoration && isPlainVersionOne ? [] : nil
        }

        var settingsByScope: [Scope: [SettingMutation]] = [:]

        func append(key: String, priors: [Scope: Int]) {
            for scope in Scope.allCases {
                guard let prior = priors[scope] else { continue }
                let value = target == .activation ? 1 : prior
                settingsByScope[scope, default: []].append(
                    SettingMutation(key: key, value: value)
                )
            }
        }

        switch (record.lowPowerModeKey, record.priorLowPowerMode) {
        case (nil, nil):
            break
        case let (key?, priors?):
            guard lowPowerModeKeys.contains(key),
                  let validated = validatedPriors(priors)
            else { return nil }
            append(key: key, priors: validated)
        default:
            return nil
        }

        if let priors = record.priorTCPKeepAlive {
            guard let validated = validatedPriors(priors) else { return nil }
            append(key: "tcpkeepalive", priors: validated)
        }

        return Scope.allCases.compactMap { scope in
            guard var settings = settingsByScope[scope], !settings.isEmpty else {
                return nil
            }
            settings.sort { $0.key < $1.key }
            return ScopedMutation(scope: scope, settings: settings)
        }
    }

    /// Empty plans need no custom readback. Every non-empty plan requires a
    /// newly read value for every scope/key and an exact numeric match.
    public static func isProven(
        for record: OverrideSentinel,
        target: Target,
        fromCustom text: String?
    ) -> Bool {
        guard let plan = plan(for: record, target: target) else {
            return false
        }
        guard !plan.isEmpty else { return true }
        guard let text else { return false }

        guard let observed = try? PMSetParser.parseCustomStrict(text) else {
            return false
        }
        for scopedMutation in plan {
            guard !scopedMutation.settings.isEmpty else { return false }
            for setting in scopedMutation.settings {
                guard let rawValue = observed[scopedMutation.scope.rawValue]?[setting.key],
                      let value = Int(rawValue),
                      value == setting.value
                else { return false }
            }
        }
        return true
    }

    /// Compatibility spelling retained for recovery call sites and historical
    /// tests; both activation and restoration now use the same exact proof.
    public static func isRestorationProven(
        for record: OverrideSentinel,
        fromCustom text: String?
    ) -> Bool {
        isProven(
            for: record,
            target: .restoration,
            fromCustom: text
        )
    }

    private static func validatedPriors(
        _ priors: [String: Int]
    ) -> [Scope: Int]? {
        guard !priors.isEmpty else { return nil }
        var validated: [Scope: Int] = [:]
        for (section, value) in priors {
            guard let scope = Scope(rawValue: section) else { return nil }
            validated[scope] = value
        }
        return validated
    }
}
