import Foundation

/// A recurring keep-awake window, e.g. weeknights 23:00–07:00.
///
/// `weekdays` uses `Calendar.weekday` numbering (1 = Sunday … 7 = Saturday)
/// and refers to the day the window *starts*: a Friday 23:00–07:00 window is
/// still active early Saturday morning.
public struct ScheduleWindow: Codable, Sendable, Equatable, Hashable, Identifiable {
    public var id: UUID
    public var enabled: Bool
    public var weekdays: Set<Int>
    public var start: HMTime
    /// When `end <= start` the window wraps past midnight into the next day.
    public var end: HMTime

    public init(
        id: UUID = UUID(),
        enabled: Bool = true,
        weekdays: Set<Int>,
        start: HMTime,
        end: HMTime
    ) {
        self.id = id
        self.enabled = enabled
        self.weekdays = weekdays
        self.start = start
        self.end = end
    }

    public var wrapsMidnight: Bool { end.minutesFromMidnight <= start.minutesFromMidnight }

    /// Weeknights preset: Sun–Thu 23:00 → 07:00 (armed overnight before workdays).
    public static func weeknights() -> ScheduleWindow {
        ScheduleWindow(
            weekdays: [1, 2, 3, 4, 5],
            start: HMTime(hour: 23, minute: 0),
            end: HMTime(hour: 7, minute: 0)
        )
    }
}

public enum ScheduleEngine {

    /// One concrete occurrence of a window on the calendar.
    public struct Occurrence: Sendable, Equatable {
        public var windowID: UUID
        public var start: Date
        public var end: Date

        public init(windowID: UUID, start: Date, end: Date) {
            self.windowID = windowID
            self.start = start
            self.end = end
        }
    }

    /// The occurrence covering `date`, if any. Overlapping windows resolve to
    /// the one that ends latest, so automation never disarms while any window
    /// still wants the machine awake.
    public static func activeOccurrence(
        windows: [ScheduleWindow],
        at date: Date,
        calendar: Calendar
    ) -> Occurrence? {
        occurrences(windows: windows, around: date, calendar: calendar)
            .filter { $0.start <= date && date < $0.end }
            .max { $0.end < $1.end }
    }

    /// The next occurrence starting strictly after `date` (within 8 days).
    public static func nextStart(
        windows: [ScheduleWindow],
        after date: Date,
        calendar: Calendar
    ) -> Occurrence? {
        occurrences(windows: windows, around: date, calendar: calendar)
            .filter { $0.start > date }
            .min { $0.start < $1.start }
    }

    /// The next moment automation state can change (a start or an end),
    /// used to schedule re-evaluation precisely instead of polling hard.
    public static func nextTransition(
        windows: [ScheduleWindow],
        after date: Date,
        calendar: Calendar
    ) -> Date? {
        let all = occurrences(windows: windows, around: date, calendar: calendar)
        let boundaries = all.flatMap { [$0.start, $0.end] }.filter { $0 > date }
        return boundaries.min()
    }

    /// All concrete occurrences with starts from yesterday through +7 days.
    /// Times are resolved per-day with the calendar, so DST shifts land where
    /// the user expects ("07:00" means 07:00 local, whatever the offset).
    static func occurrences(
        windows: [ScheduleWindow],
        around date: Date,
        calendar: Calendar
    ) -> [Occurrence] {
        var result: [Occurrence] = []
        let anchor = calendar.startOfDay(for: date)

        for window in windows where window.enabled && !window.weekdays.isEmpty {
            for dayOffset in -1...7 {
                guard let day = calendar.date(byAdding: .day, value: dayOffset, to: anchor),
                      window.weekdays.contains(calendar.component(.weekday, from: day)),
                      let start = window.start.onSameDay(as: day, calendar: calendar)
                else { continue }

                let endDay = window.wrapsMidnight
                    ? calendar.date(byAdding: .day, value: 1, to: day)
                    : day
                guard let endDay, let end = window.end.onSameDay(as: endDay, calendar: calendar),
                      end > start
                else { continue }

                result.append(Occurrence(windowID: window.id, start: start, end: end))
            }
        }
        return result
    }
}
