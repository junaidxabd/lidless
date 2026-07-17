import Foundation

/// All pmset text parsing lives here — the app and helper never regex pmset
/// output themselves. Formats differ between Intel and Apple Silicon and
/// across macOS releases, so every accessor is tolerant: absent keys parse
/// to nil, never to a guess.
public enum PMSetParser {

    // MARK: - `pmset -g therm`

    /// Intel output:
    /// ```
    /// Note: No thermal warning level has been recorded
    /// Note: No performance warning level has been recorded
    /// CPU Power notify
    ///         CPU_Scheduler_Limit     = 100
    ///         CPU_Available_CPUs      = 8
    ///         CPU_Speed_Limit         = 100
    /// ```
    /// Under load: `Thermal Warning Level = 1` replaces the first note.
    /// Apple Silicon typically emits only the notes.
    public static func parseTherm(_ text: String, sampledAt: Date) -> ThermalReading {
        var reading = ThermalReading(sampledAt: sampledAt)

        if firstMatch(in: text, pattern: #"(?i)no\s+thermal\s+warning\s+level"#) != nil {
            reading.warningLevel = 0
        }
        if let value = firstIntMatch(in: text, pattern: #"(?i)thermal\s+warning\s+level\s*[=:]\s*(-?\d+)"#) {
            reading.warningLevel = value
        }
        reading.cpuSpeedLimit = firstIntMatch(in: text, pattern: #"CPU_Speed_Limit\s*=\s*(-?\d+)"#)
        reading.schedulerLimit = firstIntMatch(in: text, pattern: #"CPU_Scheduler_Limit\s*=\s*(-?\d+)"#)
        reading.availableCPUs = firstIntMatch(in: text, pattern: #"CPU_Available_CPUs\s*=\s*(-?\d+)"#)
        return reading
    }

    // MARK: - `pmset -g custom`

    /// Output is sectioned per power source:
    /// ```
    /// Battery Power:
    ///  Sleep On Power Button 1
    ///  powermode            1
    ///  hibernatefile        /var/vm/sleepimage
    /// AC Power:
    ///  powermode            2
    /// ```
    /// Keys can contain spaces ("Sleep On Power Button"), so the *last*
    /// whitespace-separated token is the value and everything before it is
    /// the key. Returns `[section: [key: value]]` with section names trimmed
    /// of the trailing colon (e.g. "Battery Power", "AC Power").
    public static func parseCustom(_ text: String) -> [String: [String: String]] {
        var result: [String: [String: String]] = [:]
        var currentSection: String?

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            // Section headers are the un-indented "Battery Power:" style
            // lines; indented lines are always key/value settings.
            if line.hasSuffix(":"), rawLine.first != " ", rawLine.first != "\t" {
                currentSection = String(line.dropLast())
                result[currentSection!] = result[currentSection!] ?? [:]
                continue
            }

            guard let section = currentSection else { continue }
            let tokens = line.split(separator: " ", omittingEmptySubsequences: true)
            guard tokens.count >= 2, let value = tokens.last else { continue }
            let key = tokens.dropLast().joined(separator: " ")
            result[section]?[key] = String(value)
        }
        return result
    }

    /// Integer setting per power-source section, e.g. `intSetting("lowpowermode", ...)`
    /// → `["Battery Power": 0, "AC Power": 1]`.
    public static func intSetting(_ key: String, fromCustom text: String) -> [String: Int] {
        parseCustom(text).compactMapValues { section in
            section[key].flatMap { Int($0) }
        }
    }

    // MARK: - Helpers

    private static func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let matchRange = Range(match.range, in: text)
        else { return nil }
        return String(text[matchRange])
    }

    private static func firstIntMatch(in text: String, pattern: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: text)
        else { return nil }
        return Int(text[captureRange])
    }
}
