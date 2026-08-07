import Foundation

/// Exact parser for helper-owned one-shot wake lines from `pmset -g sched`.
///
/// It deliberately ignores other structurally valid event types, repeating
/// events, and system-owned wakes. Malformed lines, format drift, and ambiguous
/// `pmset` ownership throw: an empty result therefore proves a recognized
/// listing contained no matching wake instead of manufacturing absence from
/// parser silence. Duplicate exact renderings are preserved so callers cannot
/// mistake one remaining duplicate for authoritative absence.
public enum ScheduledWakeOutputParser {
    public enum ParserError: Error, Sendable, Equatable {
        case unsupportedFormat
        case malformedLine(String)
    }

    private enum Section {
        case scheduled
        case repeating
    }

    public static func parse(_ text: String) throws -> [String] {
        guard let eventExpression = try? NSRegularExpression(
            pattern: #"^\s*\[\d+\]\s+([A-Za-z][A-Za-z0-9_-]*)\s+at\s+(.+?)\s+by\s+'([^']+)'\s*$"#
        ), let renderedExpression = try? NSRegularExpression(
            pattern: #"^(?:0[1-9]|1[0-2])/(?:0[1-9]|[12]\d|3[01])/\d{2} (?:[01]\d|2[0-3]):[0-5]\d:[0-5]\d$"#
        ), let repeatingExpression = try? NSRegularExpression(
            pattern: #"^[A-Za-z][A-Za-z0-9_-]*\s+at\s+.+\s+every\s+.+$"#
        ) else {
            throw ParserError.unsupportedFormat
        }

        var section: Section?
        var sawScheduledHeader = false
        var result: [String] = []
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            if line == "Scheduled power events:" {
                sawScheduledHeader = true
                section = .scheduled
                continue
            }
            if line == "Repeating power events:" {
                section = .repeating
                continue
            }

            guard let section else {
                throw ParserError.unsupportedFormat
            }
            switch section {
            case .scheduled:
                let range = NSRange(line.startIndex..<line.endIndex, in: line)
                guard let match = eventExpression.firstMatch(in: line, range: range),
                      match.numberOfRanges == 4,
                      let typeRange = Range(match.range(at: 1), in: line),
                      let payloadRange = Range(match.range(at: 2), in: line),
                      let ownerRange = Range(match.range(at: 3), in: line) else {
                    throw ParserError.malformedLine(line)
                }

                let type = String(line[typeRange])
                let owner = String(line[ownerRange])
                guard type == "wake", owner == "pmset" else { continue }

                let rendered = String(line[payloadRange])
                let renderedRange = NSRange(
                    rendered.startIndex..<rendered.endIndex,
                    in: rendered
                )
                guard renderedExpression.firstMatch(
                    in: rendered,
                    range: renderedRange
                ) != nil, isValidCalendarDate(rendered) else {
                    throw ParserError.malformedLine(line)
                }
                result.append(rendered)
            case .repeating:
                let range = NSRange(line.startIndex..<line.endIndex, in: line)
                guard repeatingExpression.firstMatch(in: line, range: range) != nil,
                      !line.localizedCaseInsensitiveContains("pmset") else {
                    throw ParserError.malformedLine(line)
                }
            }
        }

        guard sawScheduledHeader else { throw ParserError.unsupportedFormat }
        return result
    }

    private static func isValidCalendarDate(_ rendered: String) -> Bool {
        let dateAndTime = rendered.split(separator: " ", omittingEmptySubsequences: false)
        guard dateAndTime.count == 2 else { return false }
        let date = dateAndTime[0].split(separator: "/", omittingEmptySubsequences: false)
        let time = dateAndTime[1].split(separator: ":", omittingEmptySubsequences: false)
        guard date.count == 3,
              time.count == 3,
              let month = Int(date[0]),
              let day = Int(date[1]),
              let shortYear = Int(date[2]),
              let hour = Int(time[0]),
              let minute = Int(time[1]),
              let second = Int(time[2]) else {
            return false
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2_000 + shortYear,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            second: second
        )
        guard let parsed = calendar.date(from: components) else { return false }
        let roundTrip = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: parsed
        )
        return roundTrip.year == components.year
            && roundTrip.month == components.month
            && roundTrip.day == components.day
            && roundTrip.hour == components.hour
            && roundTrip.minute == components.minute
            && roundTrip.second == components.second
    }
}
