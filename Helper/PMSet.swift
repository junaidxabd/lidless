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

    /// A hung pmset (wedged powerd) must never wedge the daemon's serial
    /// supervision queue — the watchdog, restore retries, and SIGTERM all
    /// live there. Every invocation gets a hard deadline; on expiry the
    /// child is killed and the call fails like any other pmset error, which
    /// the restore-retry loop already handles.
    @discardableResult
    static func run(_ arguments: [String], timeout: TimeInterval = 20) throws -> String {
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
            kill(process.processIdentifier, SIGKILL)
            _ = exited.wait(timeout: .now() + 2)
            throw CommandError(arguments: arguments, status: -1, output: "timed out after \(Int(timeout))s")
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

    /// pmset flag for a `pmset -g custom` section name.
    static func scopeFlag(forSection section: String) -> String? {
        switch section {
        case "Battery Power": "-b"
        case "AC Power": "-c"
        case "UPS Power": "-u"
        default: nil
        }
    }

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

    static func setEverywhere(key: String, value: Int) throws {
        try run(["-a", key, String(value)])
    }

    /// Restore a per-section snapshot captured at arm time. Best-effort per
    /// section; throws only if every section fails.
    static func restore(key: String, sections: [String: Int]) throws {
        var lastError: Error?
        var succeededAny = sections.isEmpty
        for (section, value) in sections {
            guard let flag = scopeFlag(forSection: section) else { continue }
            do {
                try run([flag, key, String(value)])
                succeededAny = true
            } catch {
                lastError = error
            }
        }
        if !succeededAny, let lastError { throw lastError }
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
