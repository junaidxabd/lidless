import Foundation
import Testing
@testable import LidlessCore

// MARK: - Fixed instants
//
// All instants are epoch seconds verified externally with
// `TZ=America/Los_Angeles date -r <epoch>`. January dates are PST (UTC-8).
// Monday 2026-01-05 is a Monday, so weekdays that week are:
// Sun Jan 4 (1), Mon Jan 5 (2), Tue Jan 6 (3), Wed Jan 7 (4),
// Thu Jan 8 (5), Fri Jan 9 (6), Sat Jan 10 (7).

private func d(_ epoch: TimeInterval) -> Date { Date(timeIntervalSince1970: epoch) }

private enum Jan {
    static let sun0900 = d(1_767_546_000) // Sun 2026-01-04 09:00 PST
    static let sunNoon = d(1_767_556_800) // Sun 2026-01-04 12:00 PST
    static let mon0859 = d(1_767_632_340) // Mon 2026-01-05 08:59 PST
    static let mon0900 = d(1_767_632_400) // Mon 2026-01-05 09:00 PST
    static let mon1000 = d(1_767_636_000) // Mon 2026-01-05 10:00 PST
    static let monNoon = d(1_767_643_200) // Mon 2026-01-05 12:00 PST
    static let mon1659 = d(1_767_661_140) // Mon 2026-01-05 16:59 PST
    static let mon1700 = d(1_767_661_200) // Mon 2026-01-05 17:00 PST
    static let mon1800 = d(1_767_664_800) // Mon 2026-01-05 18:00 PST
    static let mon2000 = d(1_767_672_000) // Mon 2026-01-05 20:00 PST
    static let mon2100 = d(1_767_675_600) // Mon 2026-01-05 21:00 PST
    static let mon2200 = d(1_767_679_200) // Mon 2026-01-05 22:00 PST
    static let mon2259 = d(1_767_682_740) // Mon 2026-01-05 22:59 PST
    static let mon2300 = d(1_767_682_800) // Mon 2026-01-05 23:00 PST
    static let tue0100 = d(1_767_690_000) // Tue 2026-01-06 01:00 PST
    static let tue0200 = d(1_767_693_600) // Tue 2026-01-06 02:00 PST
    static let tue0300 = d(1_767_697_200) // Tue 2026-01-06 03:00 PST
    static let tue0400 = d(1_767_700_800) // Tue 2026-01-06 04:00 PST
    static let tue0700 = d(1_767_711_600) // Tue 2026-01-06 07:00 PST
    static let tue0859 = d(1_767_718_740) // Tue 2026-01-06 08:59 PST
    static let tue0900 = d(1_767_718_800) // Tue 2026-01-06 09:00 PST
    static let tueNoon = d(1_767_729_600) // Tue 2026-01-06 12:00 PST
    static let tue2300 = d(1_767_769_200) // Tue 2026-01-06 23:00 PST
    static let wed0700 = d(1_767_798_000) // Wed 2026-01-07 07:00 PST
    static let wed0900 = d(1_767_805_200) // Wed 2026-01-07 09:00 PST
    static let thu2300 = d(1_767_942_000) // Thu 2026-01-08 23:00 PST
    static let fri0200 = d(1_767_952_800) // Fri 2026-01-09 02:00 PST
    static let fri0700 = d(1_767_970_800) // Fri 2026-01-09 07:00 PST
    static let fri2300 = d(1_768_028_400) // Fri 2026-01-09 23:00 PST
    static let sat0200 = d(1_768_039_200) // Sat 2026-01-10 02:00 PST
    static let sat0700 = d(1_768_057_200) // Sat 2026-01-10 07:00 PST
    static let nextMon0900 = d(1_768_237_200) // Mon 2026-01-12 09:00 PST
}

private enum Dst {
    // US spring forward: Sun 2026-03-08, 02:00 PST jumps to 03:00 PDT.
    static let marSat2300 = d(1_772_953_200) // Sat 2026-03-07 23:00:00 PST (UTC-8)
    static let marSun0030 = d(1_772_958_600) // Sun 2026-03-08 00:30:00 PST (before the jump)
    static let marSun0700 = d(1_772_978_400) // Sun 2026-03-08 07:00:00 PDT (UTC-7)
    // US fall back: Sun 2026-11-01, 02:00 PDT falls back to 01:00 PST.
    static let novSat2300 = d(1_793_512_800) // Sat 2026-10-31 23:00:00 PDT
    static let novSun0030 = d(1_793_518_200) // Sun 2026-11-01 00:30:00 PDT (before fall-back)
    static let novSun0700 = d(1_793_545_200) // Sun 2026-11-01 07:00:00 PST
}

@Suite("ScheduleEngine")
struct ScheduleEngineTests {

    /// Explicit gregorian calendar pinned to America/Los_Angeles so DST
    /// transitions land on known dates regardless of the host machine.
    let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return c
    }()

    private func window(
        weekdays: Set<Int>,
        start: (h: Int, m: Int),
        end: (h: Int, m: Int),
        enabled: Bool = true
    ) -> ScheduleWindow {
        ScheduleWindow(
            enabled: enabled,
            weekdays: weekdays,
            start: HMTime(hour: start.h, minute: start.m),
            end: HMTime(hour: end.h, minute: end.m)
        )
    }

    // MARK: Weeknights preset (Sun–Thu 23:00–07:00, wraps midnight)

    @Test func weeknightsPresetShape() {
        let w = ScheduleWindow.weeknights()
        #expect(w.enabled)
        #expect(w.weekdays == [1, 2, 3, 4, 5])
        #expect(w.start == HMTime(hour: 23, minute: 0))
        #expect(w.end == HMTime(hour: 7, minute: 0))
        #expect(w.wrapsMidnight)
    }

    @Test func weeknightsActiveTuesdayTwoAMViaMondayOccurrence() throws {
        let w = ScheduleWindow.weeknights()
        let occ = try #require(ScheduleEngine.activeOccurrence(windows: [w], at: Jan.tue0200, calendar: cal))
        // Tuesday 02:00 is covered by MONDAY's occurrence (weekday of the start day).
        #expect(occ == ScheduleEngine.Occurrence(windowID: w.id, start: Jan.mon2300, end: Jan.tue0700))
    }

    @Test func weeknightsStartInclusiveAtMondayElevenPMSharp() throws {
        let w = ScheduleWindow.weeknights()
        let occ = try #require(ScheduleEngine.activeOccurrence(windows: [w], at: Jan.mon2300, calendar: cal))
        #expect(occ.start == Jan.mon2300)
        #expect(occ.end == Jan.tue0700)
    }

    @Test func weeknightsInactiveOneMinuteBeforeStart() {
        let w = ScheduleWindow.weeknights()
        // Monday 22:59 — the prior (Sunday) occurrence ended Mon 07:00.
        #expect(ScheduleEngine.activeOccurrence(windows: [w], at: Jan.mon2259, calendar: cal) == nil)
    }

    @Test func weeknightsInactiveSaturdayTwoAM() {
        let w = ScheduleWindow.weeknights()
        // Sat 02:00 would need a FRIDAY-starting occurrence; Friday (6) is not in the set.
        #expect(ScheduleEngine.activeOccurrence(windows: [w], at: Jan.sat0200, calendar: cal) == nil)
    }

    @Test func weeknightsActiveFridayTwoAMViaThursdayOccurrence() throws {
        let w = ScheduleWindow.weeknights()
        let occ = try #require(ScheduleEngine.activeOccurrence(windows: [w], at: Jan.fri0200, calendar: cal))
        #expect(occ.start == Jan.thu2300) // Thursday (5) is in the set
        #expect(occ.end == Jan.fri0700)
    }

    @Test func fridayOnlyWrapWindowActiveSaturdayMorning() throws {
        // weekdays refer to the START day: a Friday window covers early Saturday.
        let w = window(weekdays: [6], start: (23, 0), end: (7, 0))
        let occ = try #require(ScheduleEngine.activeOccurrence(windows: [w], at: Jan.sat0200, calendar: cal))
        #expect(occ == ScheduleEngine.Occurrence(windowID: w.id, start: Jan.fri2300, end: Jan.sat0700))
    }

    // MARK: Non-wrapping window (09:00–17:00)

    @Test func dayWindowActiveInsideWithConcreteDates() throws {
        let w = window(weekdays: [2], start: (9, 0), end: (17, 0))
        let occ = try #require(ScheduleEngine.activeOccurrence(windows: [w], at: Jan.monNoon, calendar: cal))
        #expect(occ == ScheduleEngine.Occurrence(windowID: w.id, start: Jan.mon0900, end: Jan.mon1700))
    }

    @Test func dayWindowStartInclusive() throws {
        let w = window(weekdays: [2], start: (9, 0), end: (17, 0))
        let occ = try #require(ScheduleEngine.activeOccurrence(windows: [w], at: Jan.mon0900, calendar: cal))
        #expect(occ.start == Jan.mon0900)
    }

    @Test func dayWindowEndExclusive() {
        let w = window(weekdays: [2], start: (9, 0), end: (17, 0))
        // 17:00 sharp is OUTSIDE (date < end is strict) …
        #expect(ScheduleEngine.activeOccurrence(windows: [w], at: Jan.mon1700, calendar: cal) == nil)
        // … while 16:59 is still inside.
        #expect(ScheduleEngine.activeOccurrence(windows: [w], at: Jan.mon1659, calendar: cal) != nil)
    }

    @Test func dayWindowInactiveOutside() {
        let w = window(weekdays: [2], start: (9, 0), end: (17, 0))
        #expect(ScheduleEngine.activeOccurrence(windows: [w], at: Jan.mon0859, calendar: cal) == nil)
        #expect(ScheduleEngine.activeOccurrence(windows: [w], at: Jan.mon1800, calendar: cal) == nil)
        // Right time of day, wrong weekday (Sunday = 1 not in {2}).
        #expect(ScheduleEngine.activeOccurrence(windows: [w], at: Jan.sunNoon, calendar: cal) == nil)
    }

    // MARK: wrapsMidnight classification

    @Test func wrapsMidnightClassification() {
        // end < start → wraps.
        #expect(window(weekdays: [2], start: (23, 0), end: (7, 0)).wrapsMidnight)
        // end == start → wraps (treated as a full 24h window).
        #expect(window(weekdays: [2], start: (9, 0), end: (9, 0)).wrapsMidnight)
        // end > start → does not wrap.
        #expect(!window(weekdays: [2], start: (9, 0), end: (17, 0)).wrapsMidnight)
        // One-minute margins around equality.
        #expect(window(weekdays: [2], start: (9, 0), end: (8, 59)).wrapsMidnight)
        #expect(!window(weekdays: [2], start: (9, 0), end: (9, 1)).wrapsMidnight)
    }

    @Test func fullDayWrapOccurrenceLastsTwentyFourHours() throws {
        // end == start → occurrence spans exactly one day (Mon 09:00 → Tue 09:00).
        let w = window(weekdays: [2], start: (9, 0), end: (9, 0))
        let occ = try #require(ScheduleEngine.activeOccurrence(windows: [w], at: Jan.mon2000, calendar: cal))
        #expect(occ.start == Jan.mon0900)
        #expect(occ.end == Jan.tue0900)
        #expect(occ.end.timeIntervalSince(occ.start) == 24 * 3600)
        // Still active at Tue 08:59, over (end-exclusive) at Tue 09:00, not yet at Mon 08:59.
        #expect(ScheduleEngine.activeOccurrence(windows: [w], at: Jan.tue0859, calendar: cal) != nil)
        #expect(ScheduleEngine.activeOccurrence(windows: [w], at: Jan.tue0900, calendar: cal) == nil)
        #expect(ScheduleEngine.activeOccurrence(windows: [w], at: Jan.mon0859, calendar: cal) == nil)
    }

    @Test func backToBackFullDayOccurrencesHandOffAtBoundary() throws {
        // Mon+Tue full-day windows: at exactly Tue 09:00 the Monday occurrence has
        // ended (exclusive) and the Tuesday occurrence has begun (inclusive).
        let w = window(weekdays: [2, 3], start: (9, 0), end: (9, 0))
        let occ = try #require(ScheduleEngine.activeOccurrence(windows: [w], at: Jan.tue0900, calendar: cal))
        #expect(occ.start == Jan.tue0900)
        #expect(occ.end == Jan.wed0900)
    }

    // MARK: Overlap resolution — latest end wins

    @Test func overlappingWindowsLatestEndWins() throws {
        let a = window(weekdays: [2], start: (9, 0), end: (17, 0))
        let b = window(weekdays: [2], start: (10, 0), end: (18, 0))
        // Both cover Mon 12:00; b ends later so b must win, regardless of array order.
        let occ1 = try #require(ScheduleEngine.activeOccurrence(windows: [a, b], at: Jan.monNoon, calendar: cal))
        #expect(occ1.windowID == b.id)
        #expect(occ1 == ScheduleEngine.Occurrence(windowID: b.id, start: Jan.mon1000, end: Jan.mon1800))
        let occ2 = try #require(ScheduleEngine.activeOccurrence(windows: [b, a], at: Jan.monNoon, calendar: cal))
        #expect(occ2.windowID == b.id)
    }

    @Test func overlappingWrapAndInnerWindowLatestEndWins() throws {
        // Weeknights (ends Tue 07:00) vs a short Tue 01:00–03:00 window: at Tue 02:00
        // both are active; disarming at 03:00 would be wrong, so weeknights wins.
        let long = ScheduleWindow.weeknights()
        let short = window(weekdays: [3], start: (1, 0), end: (3, 0))
        let occ = try #require(ScheduleEngine.activeOccurrence(windows: [short, long], at: Jan.tue0200, calendar: cal))
        #expect(occ.windowID == long.id)
        #expect(occ.end == Jan.tue0700)
    }

    // MARK: activeOccurrence — ignored windows

    @Test func activeOccurrenceIgnoresDisabledEmptyAndAbsentWindows() {
        var disabled = ScheduleWindow.weeknights()
        disabled.enabled = false
        #expect(ScheduleEngine.activeOccurrence(windows: [disabled], at: Jan.tue0200, calendar: cal) == nil)

        let noDays = window(weekdays: [], start: (23, 0), end: (7, 0))
        #expect(ScheduleEngine.activeOccurrence(windows: [noDays], at: Jan.tue0200, calendar: cal) == nil)

        #expect(ScheduleEngine.activeOccurrence(windows: [], at: Jan.tue0200, calendar: cal) == nil)
    }

    @Test func invalidWeekdayNumbersNeverMatch() {
        // Calendar weekdays are 1…7; 0 and 8 can never match any day.
        let w = window(weekdays: [0, 8], start: (9, 0), end: (17, 0))
        #expect(ScheduleEngine.activeOccurrence(windows: [w], at: Jan.monNoon, calendar: cal) == nil)
        #expect(ScheduleEngine.nextStart(windows: [w], after: Jan.monNoon, calendar: cal) == nil)
        #expect(ScheduleEngine.nextTransition(windows: [w], after: Jan.monNoon, calendar: cal) == nil)
    }

    // MARK: nextStart

    @Test func nextStartIsStrictlyAfterDate() throws {
        let w = ScheduleWindow.weeknights()
        // Exactly at Monday's start: that occurrence must NOT be returned (> is strict);
        // the next start is Tuesday 23:00.
        let occ = try #require(ScheduleEngine.nextStart(windows: [w], after: Jan.mon2300, calendar: cal))
        #expect(occ.start > Jan.mon2300)
        #expect(occ.start == Jan.tue2300)
        #expect(occ.end == Jan.wed0700)
    }

    @Test func nextStartFromInsideActiveWindowReturnsNextOccurrence() throws {
        let w = ScheduleWindow.weeknights()
        // Tue 02:00 is inside Monday's occurrence; nextStart must skip it.
        let occ = try #require(ScheduleEngine.nextStart(windows: [w], after: Jan.tue0200, calendar: cal))
        #expect(occ.start == Jan.tue2300)
        #expect(occ.start != Jan.mon2300)
    }

    @Test func nextStartJustBeforeStartReturnsThatStart() throws {
        let w = ScheduleWindow.weeknights()
        let occ = try #require(ScheduleEngine.nextStart(windows: [w], after: Jan.mon2259, calendar: cal))
        #expect(occ == ScheduleEngine.Occurrence(windowID: w.id, start: Jan.mon2300, end: Jan.tue0700))
    }

    @Test func nextStartPicksEarliestAcrossWindows() throws {
        let late = ScheduleWindow.weeknights() // next start Mon 23:00
        let early = window(weekdays: [2], start: (21, 0), end: (22, 0))
        let occ = try #require(ScheduleEngine.nextStart(windows: [late, early], after: Jan.monNoon, calendar: cal))
        #expect(occ.windowID == early.id)
        #expect(occ.start == Jan.mon2100)
        #expect(occ.end == Jan.mon2200)
    }

    @Test func nextStartSpansMultiDayGap() throws {
        // Monday-only window queried on Tuesday noon → next Monday, 6 days out.
        let w = window(weekdays: [2], start: (9, 0), end: (17, 0))
        let occ = try #require(ScheduleEngine.nextStart(windows: [w], after: Jan.tueNoon, calendar: cal))
        #expect(occ.start == Jan.nextMon0900)
    }

    @Test func nextStartIgnoresDisabledAndEmptyWeekdayWindows() {
        var disabled = ScheduleWindow.weeknights()
        disabled.enabled = false
        #expect(ScheduleEngine.nextStart(windows: [disabled], after: Jan.monNoon, calendar: cal) == nil)

        let noDays = window(weekdays: [], start: (23, 0), end: (7, 0))
        #expect(ScheduleEngine.nextStart(windows: [noDays], after: Jan.monNoon, calendar: cal) == nil)
    }

    @Test func nextStartWithNoWindowsIsNil() {
        #expect(ScheduleEngine.nextStart(windows: [], after: Jan.monNoon, calendar: cal) == nil)
    }

    // MARK: nextTransition

    @Test func nextTransitionFromInsideWindowIsItsEnd() {
        let w = ScheduleWindow.weeknights()
        // Inside Monday's occurrence at Tue 02:00 and nothing starts before Tue 07:00.
        #expect(ScheduleEngine.nextTransition(windows: [w], after: Jan.tue0200, calendar: cal) == Jan.tue0700)
    }

    @Test func nextTransitionPrefersEarlierStartOverCurrentEnd() {
        // A second window starting Tue 03:00 beats the active window's 07:00 end.
        let w = ScheduleWindow.weeknights()
        let extra = window(weekdays: [3], start: (3, 0), end: (4, 0))
        #expect(ScheduleEngine.nextTransition(windows: [w, extra], after: Jan.tue0200, calendar: cal) == Jan.tue0300)
    }

    @Test func nextTransitionFromOutsideIsNextStart() {
        let w = ScheduleWindow.weeknights()
        // Mon 12:00: Sunday's occurrence ended 07:00 (in the past); next boundary is Mon 23:00 start.
        #expect(ScheduleEngine.nextTransition(windows: [w], after: Jan.monNoon, calendar: cal) == Jan.mon2300)
    }

    @Test func nextTransitionIsStrictlyAfterDate() {
        let w = ScheduleWindow.weeknights()
        // Exactly on the Mon 23:00 boundary → next boundary is the Tue 07:00 end.
        #expect(ScheduleEngine.nextTransition(windows: [w], after: Jan.mon2300, calendar: cal) == Jan.tue0700)
    }

    @Test func nextTransitionNilWhenNoUsableWindows() {
        #expect(ScheduleEngine.nextTransition(windows: [], after: Jan.monNoon, calendar: cal) == nil)
        var disabled = ScheduleWindow.weeknights()
        disabled.enabled = false
        #expect(ScheduleEngine.nextTransition(windows: [disabled], after: Jan.monNoon, calendar: cal) == nil)
    }

    // MARK: DST awareness (America/Los_Angeles)

    @Test func dstSpringForwardNightIsSevenHoursWallClockAnchored() throws {
        // Saturday 23:00 → Sunday 07:00 across the 2026-03-08 spring-forward.
        // Both endpoints land on their LOCAL wall-clock times, so the elapsed
        // duration is 7h (02:00–03:00 never happens), not a naive 8h.
        let w = window(weekdays: [7], start: (23, 0), end: (7, 0))
        let occ = try #require(ScheduleEngine.activeOccurrence(windows: [w], at: Dst.marSun0030, calendar: cal))
        #expect(occ.start == Dst.marSat2300) // Sat 23:00 PST == 07:00 UTC
        #expect(occ.end == Dst.marSun0700)   // Sun 07:00 PDT == 14:00 UTC
        #expect(occ.end.timeIntervalSince(occ.start) == 7 * 3600)
    }

    @Test func dstFallBackNightIsNineHoursWallClockAnchored() throws {
        // Saturday 23:00 → Sunday 07:00 across the 2026-11-01 fall-back:
        // the 01:00–02:00 hour repeats, so the same wall-clock window lasts 9h.
        let w = window(weekdays: [7], start: (23, 0), end: (7, 0))
        let occ = try #require(ScheduleEngine.activeOccurrence(windows: [w], at: Dst.novSun0030, calendar: cal))
        #expect(occ.start == Dst.novSat2300) // Sat 23:00 PDT
        #expect(occ.end == Dst.novSun0700)   // Sun 07:00 PST
        #expect(occ.end.timeIntervalSince(occ.start) == 9 * 3600)
    }

    // MARK: occurrence generation horizon (internal)

    @Test func occurrencesCoverYesterdayThroughPlusSevenDays() {
        // A daily window generates exactly one occurrence per day offset -1…7 (9 total),
        // which is what lets activeOccurrence see yesterday's wrap and nextStart
        // find any weekly window within the horizon.
        let w = window(weekdays: [1, 2, 3, 4, 5, 6, 7], start: (9, 0), end: (17, 0))
        let all = ScheduleEngine.occurrences(windows: [w], around: Jan.monNoon, calendar: cal)
        #expect(all.count == 9)
        #expect(all.map(\.start).min() == Jan.sun0900)      // Sun Jan 4, offset -1
        #expect(all.map(\.start).max() == Jan.nextMon0900)  // Mon Jan 12, offset +7
    }
}
