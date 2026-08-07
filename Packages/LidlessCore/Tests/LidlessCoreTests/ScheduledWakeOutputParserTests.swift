import Testing
@testable import LidlessCore

@Suite("Scheduled wake pmset output parser")
struct ScheduledWakeOutputParserTests {
    @Test func returnsOnlyExactManualWakeRenderings() throws {
        let output = """
            Scheduled power events:
             [0]  wake at 08/08/26 06:30:00 by 'com.apple.alarm.user-visible-Weekly Usage Report'
             [1]  wakeorpoweron at 08/08/26 06:45:00 by 'pmset'
             [2]  wake at 08/08/26 07:00:00 by 'pmset'
             [3]  poweron at 08/08/26 07:15:00 by 'pmset'
             [4]  shutdown at 08/08/26 07:30:00 by 'pmset'
             [5]  wake at 08/08/26 08:00:00 by 'pmset'
            Repeating power events:
              wakepoweron at 7:00AM every day
            """

        #expect(try ScheduledWakeOutputParser.parse(output) == [
            "08/08/26 07:00:00",
            "08/08/26 08:00:00"
        ])
    }

    @Test func preservesDuplicateExactDatesForConservativeAbsenceProof() throws {
        let output = """
            Scheduled power events:
             [7]  wake at 08/08/26 07:00:00 by 'pmset'
             [8]  wake at 08/08/26 07:00:00 by 'pmset'
            """

        #expect(try ScheduledWakeOutputParser.parse(output) == [
            "08/08/26 07:00:00",
            "08/08/26 07:00:00"
        ])
    }

    @Test func malformedIndexedOrPmsetOwnedLinesCannotProveAbsence() {
        let malformedLines = [
            "wake at 08/08/26 07:00:00 by 'pmset'",
            "[0] wake at 8/8/26 07:00:00 by 'pmset'",
            "[0] wake at 08/08/26 7:00:00 by 'pmset'",
            "[0] wake at 08/08/26 07:00 by 'pmset'",
            "[x] wake at 08/08/26 07:00:00 by 'pmset'",
            "[0] wake at 08/08/26 07:00:00 by pmset",
            "[0] wake at 08/08/26 07:00:00 by 'pmset' trailing",
            "[0] wake at 13/08/26 07:00:00 by 'pmset'",
            "[0] wake at 02/30/26 07:00:00 by 'pmset'",
            "[0] wake at 08/08/26 24:00:00 by 'pmset'"
        ]

        for line in malformedLines {
            let output = "Scheduled power events:\n \(line)"
            do {
                _ = try ScheduledWakeOutputParser.parse(output)
                #expect(Bool(false), "Malformed event output cannot prove absence")
            } catch let error as ScheduledWakeOutputParser.ParserError {
                #expect(error == .malformedLine(line))
            } catch {
                #expect(Bool(false), "Unexpected parser error: \(error)")
            }
        }
    }

    @Test func timezoneTextMakesAnOwnedWakeUnprovableInsteadOfAbsent() {
        let output = """
            Scheduled power events:
             [0] wake at 08/08/26 07:00:00 UTC by 'pmset'
             [1] wake at 08/08/26 10:00:00 by 'pmset'
            """

        do {
            _ = try ScheduledWakeOutputParser.parse(output)
            #expect(Bool(false), "Timezone-decorated ownership is not exact absence proof")
        } catch let error as ScheduledWakeOutputParser.ParserError {
            #expect(error == .malformedLine(
                "[0] wake at 08/08/26 07:00:00 UTC by 'pmset'"
            ))
        } catch {
            #expect(Bool(false), "Unexpected parser error: \(error)")
        }
    }

    @Test func whitespaceAndCRLFAreAcceptedWithoutChangingTheRenderedIdentity() throws {
        let output = "Scheduled power events:\r\n\t[12]\t wake   at  12/31/26 23:59:59   by   'pmset'\t\r\n"

        #expect(try ScheduledWakeOutputParser.parse(output) == ["12/31/26 23:59:59"])
    }

    @Test func recognizedEmptyAndUnrelatedListingsProveNoOwnedWake() throws {
        #expect(try ScheduledWakeOutputParser.parse(
            "Scheduled power events:\n"
        ).isEmpty)

        let unrelated = """
            Scheduled power events:
             [0] wake at 08/08/26 06:30:00 by 'com.apple.alarm.user-visible-Weekly Usage Report'
             [1] wakeorpoweron at 08/08/26 06:45:00 by 'pmset'
            Repeating power events:
              wakepoweron at 7:00AM every day
            """
        #expect(try ScheduledWakeOutputParser.parse(unrelated).isEmpty)
    }

    @Test func emptyOrFormatDriftOutputIsUnknownNotAnEmptySchedule() {
        let unsupported = [
            "",
            "Repeating power events:\n  wakepoweron at 7:00AM every day",
            "Scheduled power events version 2:\n  event wake 08/08/26 07:00:00 owner pmset",
            "[0] wake at 08/08/26 07:00:00 by 'pmset'"
        ]

        for output in unsupported {
            do {
                _ = try ScheduledWakeOutputParser.parse(output)
                #expect(Bool(false), "Unsupported output cannot prove an empty schedule")
            } catch let error as ScheduledWakeOutputParser.ParserError {
                #expect(error == .unsupportedFormat)
            } catch {
                #expect(Bool(false), "Unexpected parser error: \(error)")
            }
        }
    }
}
