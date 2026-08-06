import Foundation
import IOKit
import LidlessCore

/// The helper's only mutation surface: `/usr/bin/pmset` invocations plus
/// read-back verification against the power-management root domain. All
/// calls are blocking and must run on the daemon's serial state queue.
enum PMSet {

    struct CommandError: Error, CustomStringConvertible {
        let arguments: [String]
        let status: Int32
        let output: String

        var description: String {
            "pmset \(arguments.joined(separator: " ")) failed (\(status)): \(output.trimmingCharacters(in: .whitespacesAndNewlines))"
        }
    }

    struct ManagedSettingPlanError: Error, CustomStringConvertible {
        let scope: ManagedSettingRestorationSafety.Scope

        var description: String {
            "managed-setting plan for \(scope.rawValue) contained no settings"
        }
    }

    /// A hung pmset (wedged powerd) must never consume the daemon's minimum
    /// watchdog lifetime: the watchdog, connection invalidation, restore
    /// retries, and SIGTERM all share the serial state queue. The timeout and
    /// forced-reap grace are pinned by a tested core policy.
    @discardableResult
    static func run(
        _ arguments: [String],
        timeout: TimeInterval = HelperSupervisionTiming.pmsetCommandTimeout
    ) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        let exited = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in exited.signal() }
        try process.run()

        if exited.wait(timeout: .now() + timeout) == .timedOut {
            let killResult = kill(process.processIdentifier, SIGKILL)
            let killErrno = killResult == 0 ? 0 : errno
            let reapResult = exited.wait(
                timeout: .now() + HelperSupervisionTiming.forcedTerminationGrace
            )
            let killAccepted = killResult == 0 || killErrno == ESRCH
            var detail = "timed out after \(Int(timeout))s"
            if !killAccepted {
                detail += "; SIGKILL failed with errno \(killErrno)"
            }
            if reapResult == .timedOut {
                detail += "; child exit was not observed within \(Int(HelperSupervisionTiming.forcedTerminationGrace))s"
            }
            throw CommandError(arguments: arguments, status: -1, output: detail)
        }

        // Read after exit: pmset output is far below the 64KB pipe buffer,
        // so the child can never block writing before it exits.
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw CommandError(arguments: arguments, status: process.terminationStatus, output: output)
        }
        return output
    }

    // MARK: - Sleep override

    static func setSleepDisabled(_ disabled: Bool) throws {
        try run(["-a", "disablesleep", disabled ? "1" : "0"])
    }

    /// Actual current value of the override, read from IOPMrootDomain.
    /// nil when the property can't be read (treat as unknown, not false).
    static func readSleepDisabled() -> Bool? {
        PowerRegistry.sleepDisabled()
    }

    static func sleepNow() throws {
        try run(["sleepnow"])
    }

    // MARK: - Managed settings (Low Power Mode, tcpkeepalive)

    /// The key managing Low Power Mode on this system, discovered from
    /// current settings: "lowpowermode" (older) or "powermode" (newer).
    /// nil when the machine supports neither.
    static func lowPowerModeKey(fromCustom text: String) -> String? {
        let parsed = PMSetParser.parseCustom(text)
        for key in ["lowpowermode", "powermode"] where parsed.values.contains(where: { $0[key] != nil }) {
            return key
        }
        return nil
    }

    static func readCustom() throws -> String {
        try run(["-g", "custom"])
    }

    /// Applies one command per captured power-source scope. A scope's settings
    /// are grouped into one invocation, and any failed invocation fails the
    /// whole attempt so the sentinel-backed restore loop can retry.
    static func apply(
        _ plan: [ManagedSettingRestorationSafety.ScopedMutation]
    ) throws {
        for scopedMutation in plan {
            guard !scopedMutation.settings.isEmpty else {
                throw ManagedSettingPlanError(scope: scopedMutation.scope)
            }
            var arguments = [scopedMutation.scope.pmsetFlag]
            for setting in scopedMutation.settings {
                arguments.append(setting.key)
                arguments.append(String(setting.value))
            }
            try run(arguments)
        }
    }

    // MARK: - Scheduled wake

    private static func wakeDateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "MM/dd/yy HH:mm:ss"
        return formatter
    }

    /// Returns the rendered date string handed to pmset — the caller must
    /// keep it and cancel with exactly that string (re-rendering after a
    /// timezone change would not match the scheduled event).
    static func scheduleWake(at date: Date) throws -> String {
        let rendered = wakeDateFormatter().string(from: date)
        try run(["schedule", "wake", rendered])
        return rendered
    }

    static func cancelWake(rendered: String) throws {
        try run(["schedule", "cancel", "wake", rendered])
    }

}
