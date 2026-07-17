import Foundation
import Testing
@testable import LidlessCore

/// Exhaustive tests for `PMSetParser`, the only code allowed to interpret
/// `pmset` output. A wrong parse here feeds the cutoff engine bad data, so
/// every branch is pinned: Intel vs Apple Silicon `-g therm` shapes, warning
/// level casing/separator variants, the sectioned `-g custom` format, and the
/// nil-over-guess tolerance rules for absent or malformed fields.
@Suite("PMSetParser")
struct PMSetParserTests {

    // Fixed instants only — these tests never call Date().
    static let sampleDate = Date(timeIntervalSince1970: 1_752_768_000) // 2025-07-17 16:00:00 UTC
    static let otherDate = Date(timeIntervalSince1970: 1_700_000_000) // 2023-11-14 22:13:20 UTC

    // MARK: - `pmset -g therm` fixtures

    /// Intel MacBook Pro, nominal: the two Note lines plus the tab-indented
    /// `CPU Power notify` block (tab before the key, " \t" before "=").
    static let intelNominalTherm = """
        Note: No thermal warning level has been recorded
        Note: No performance warning level has been recorded
        CPU Power notify
        \tCPU_Scheduler_Limit \t= 100
        \tCPU_Available_CPUs \t= 8
        \tCPU_Speed_Limit \t= 100
        """

    /// Intel under sustained load: the thermal note is replaced by an
    /// explicit warning level and the CPU limits drop.
    static let intelThrottledTherm = """
        Thermal Warning Level = 2
        Note: No performance warning level has been recorded
        CPU Power notify
        \tCPU_Scheduler_Limit \t= 62
        \tCPU_Available_CPUs \t= 4
        \tCPU_Speed_Limit \t= 40
        """

    /// Apple Silicon: only the notes, no CPU Power notify block.
    static let appleSiliconTherm = """
        Note: No thermal warning level has been recorded
        Note: No performance warning level has been recorded
        """

    // MARK: - parseTherm

    @Test("Intel nominal output parses warning level 0 and the full CPU block")
    func thermIntelNominalFullOutput() {
        let reading = PMSetParser.parseTherm(Self.intelNominalTherm, sampledAt: Self.sampleDate)
        #expect(reading == ThermalReading(
            warningLevel: 0,
            cpuSpeedLimit: 100,
            schedulerLimit: 100,
            availableCPUs: 8,
            sampledAt: Self.sampleDate
        ))
    }

    @Test("Intel throttled output parses explicit warning level and reduced limits")
    func thermIntelThrottledOutput() {
        let reading = PMSetParser.parseTherm(Self.intelThrottledTherm, sampledAt: Self.otherDate)
        #expect(reading == ThermalReading(
            warningLevel: 2,
            cpuSpeedLimit: 40,
            schedulerLimit: 62,
            availableCPUs: 4,
            sampledAt: Self.otherDate
        ))

        // Lowercase "warning level" variant seen across macOS releases,
        // combined with a throttled speed limit.
        let lowercase = """
            Thermal warning level = 1
            CPU Power notify
            \tCPU_Speed_Limit \t= 40
            """
        let lowercaseReading = PMSetParser.parseTherm(lowercase, sampledAt: Self.sampleDate)
        #expect(lowercaseReading.warningLevel == 1)
        #expect(lowercaseReading.cpuSpeedLimit == 40)
    }

    @Test("warning level line matches case-insensitively with = or : separators", arguments: [
        "Thermal Warning Level = 1",
        "Thermal warning level = 1",
        "thermal warning level = 1",
        "THERMAL WARNING LEVEL = 1",
        "Thermal Warning Level=1",
        "Thermal   Warning   Level  =  1",
        "Thermal Warning Level: 1",
        "Thermal Warning Level : 1",
    ])
    func thermWarningLevelCaseAndSeparatorVariants(line: String) {
        let reading = PMSetParser.parseTherm(line, sampledAt: Self.sampleDate)
        #expect(reading.warningLevel == 1)
        #expect(reading.cpuSpeedLimit == nil)
    }

    @Test("nominal note line matches case-insensitively", arguments: [
        "Note: No thermal warning level has been recorded",
        "note: no thermal warning level has been recorded",
        "NOTE: NO THERMAL WARNING LEVEL HAS BEEN RECORDED",
    ])
    func thermNominalNoteCaseInsensitive(line: String) {
        #expect(PMSetParser.parseTherm(line, sampledAt: Self.sampleDate).warningLevel == 0)
    }

    @Test("Apple Silicon note-only output: warning level 0, all CPU fields nil")
    func thermAppleSiliconMinimalOutput() {
        let reading = PMSetParser.parseTherm(Self.appleSiliconTherm, sampledAt: Self.sampleDate)
        #expect(reading == ThermalReading(warningLevel: 0, sampledAt: Self.sampleDate))
        #expect(reading.cpuSpeedLimit == nil)
        #expect(reading.schedulerLimit == nil)
        #expect(reading.availableCPUs == nil)
    }

    @Test("empty or whitespace-only input parses every field to nil", arguments: [
        "",
        "   \n\t\n  ",
    ])
    func thermEmptyOrWhitespaceAllNil(text: String) {
        let reading = PMSetParser.parseTherm(text, sampledAt: Self.sampleDate)
        #expect(reading == ThermalReading(sampledAt: Self.sampleDate))
    }

    @Test("garbage text parses every field to nil without crashing")
    func thermGarbageAllNilNoCrash() {
        let garbage = """
            pmset: unrecognized argument
            Usage: pmset [-a | -b | -c | -u] <options>
            random = 42
            Speed_Limit = 99
            warning level: high
            100% !!! <<>> ===
            """
        let reading = PMSetParser.parseTherm(garbage, sampledAt: Self.otherDate)
        #expect(reading == ThermalReading(sampledAt: Self.otherDate))
    }

    @Test("explicit warning level overrides the nominal note regardless of line order", arguments: [
        "Note: No thermal warning level has been recorded\nThermal Warning Level = 1",
        "Thermal Warning Level = 1\nNote: No thermal warning level has been recorded",
    ])
    func thermExplicitLevelOverridesNote(text: String) {
        // The parser applies the note check first and the explicit value
        // second (code order, not text order), so the explicit level wins.
        #expect(PMSetParser.parseTherm(text, sampledAt: Self.sampleDate).warningLevel == 1)
    }

    @Test("first warning level line wins when several are present")
    func thermFirstWarningLevelLineWins() {
        let text = "Thermal Warning Level = 2\nThermal Warning Level = 9"
        #expect(PMSetParser.parseTherm(text, sampledAt: Self.sampleDate).warningLevel == 2)
    }

    @Test("CPU block without any note or warning line leaves warningLevel nil")
    func thermCPUBlockWithoutNotesLeavesWarningNil() {
        let text = """
            CPU Power notify
            \tCPU_Scheduler_Limit \t= 80
            \tCPU_Available_CPUs \t= 10
            \tCPU_Speed_Limit \t= 55
            """
        let reading = PMSetParser.parseTherm(text, sampledAt: Self.sampleDate)
        #expect(reading.warningLevel == nil)
        #expect(reading.cpuSpeedLimit == 55)
        #expect(reading.schedulerLimit == 80)
        #expect(reading.availableCPUs == 10)
    }

    @Test("negative values are captured (patterns allow a leading minus)")
    func thermNegativeValuesParse() {
        let text = """
            Thermal Warning Level = -1
            CPU Power notify
            \tCPU_Scheduler_Limit \t= -100
            \tCPU_Available_CPUs \t= -8
            \tCPU_Speed_Limit \t= -5
            """
        let reading = PMSetParser.parseTherm(text, sampledAt: Self.sampleDate)
        #expect(reading == ThermalReading(
            warningLevel: -1,
            cpuSpeedLimit: -5,
            schedulerLimit: -100,
            availableCPUs: -8,
            sampledAt: Self.sampleDate
        ))
    }

    @Test("CPU_* keys match case-sensitively; lowercase variants parse to nil")
    func thermCPUKeysAreCaseSensitive() {
        // Current behavior: the warning-level patterns carry (?i) but the
        // CPU_* patterns do not. Real pmset always emits the exact casing,
        // so lowercase keys are treated as unknown and parse to nil.
        let text = """
            Note: No thermal warning level has been recorded
            cpu power notify
            \tcpu_scheduler_limit \t= 100
            \tcpu_available_cpus \t= 8
            \tcpu_speed_limit \t= 100
            """
        let reading = PMSetParser.parseTherm(text, sampledAt: Self.sampleDate)
        #expect(reading.warningLevel == 0)
        #expect(reading.cpuSpeedLimit == nil)
        #expect(reading.schedulerLimit == nil)
        #expect(reading.availableCPUs == nil)
    }

    @Test("digits that overflow Int parse to nil instead of crashing")
    func thermIntOverflowParsesToNil() {
        // Matches the regexes but overflows Int, so Int(...) fails and the
        // fields stay nil (firstIntMatch's final conversion branch).
        let overflow = """
            Thermal Warning Level = 99999999999999999999999999
            CPU_Speed_Limit = 99999999999999999999999999
            """
        let reading = PMSetParser.parseTherm(overflow, sampledAt: Self.sampleDate)
        #expect(reading.warningLevel == nil)
        #expect(reading.cpuSpeedLimit == nil)

        // A failed numeric override leaves the note-derived 0 in place.
        let withNote = """
            Note: No thermal warning level has been recorded
            Thermal Warning Level = 99999999999999999999999999
            """
        #expect(PMSetParser.parseTherm(withNote, sampledAt: Self.sampleDate).warningLevel == 0)
    }

    @Test("sampledAt is passed through unchanged")
    func thermSampledAtPassedThrough() {
        #expect(PMSetParser.parseTherm(Self.intelNominalTherm, sampledAt: Self.sampleDate).sampledAt == Self.sampleDate)
        #expect(PMSetParser.parseTherm(Self.intelNominalTherm, sampledAt: Self.otherDate).sampledAt == Self.otherDate)
        let epoch = Date(timeIntervalSince1970: 0)
        #expect(PMSetParser.parseTherm("", sampledAt: epoch).sampledAt == epoch)
    }

    // MARK: - `pmset -g custom` fixtures

    /// Real two-section shape: single-space indent, space-padded columns,
    /// the same keys in both sections with differing values, a path value,
    /// and one key present only under Battery Power.
    static let customBothSections = """
        Battery Power:
         lidwake              1
         standbydelaylow      10800
         standby              1
         halfdim              1
         hibernatefile        /var/vm/sleepimage
         powernap             0
         gpuswitch            2
         disksleep            10
         sleep                1
         hibernatemode        3
         ttyskeepawake        1
         displaysleep         2
         highstandbythreshold 50
         acwake               0
         lessbright           1
         womp                 0
         networkoversleep     0
         standbydelayhigh     86400
         lowpowermode         0
        AC Power:
         lidwake              1
         standbydelaylow      10800
         standby              1
         halfdim              1
         hibernatefile        /var/vm/sleepimage
         powernap             1
         gpuswitch            2
         disksleep            10
         sleep                1
         hibernatemode        3
         ttyskeepawake        1
         displaysleep         10
         acwake               0
         lessbright           0
         womp                 1
         networkoversleep     0
         standbydelayhigh     86400
         lowpowermode         1
        """

    // MARK: - parseCustom

    @Test("realistic two-section output: sections keyed without colon, values correct")
    func customTwoSectionRealOutput() {
        let custom = PMSetParser.parseCustom(Self.customBothSections)
        #expect(Set(custom.keys) == ["Battery Power", "AC Power"])
        #expect(custom["Battery Power"]?.count == 19)
        #expect(custom["AC Power"]?.count == 18)
        // Same key in both sections keeps a distinct value per section.
        #expect(custom["Battery Power"]?["lowpowermode"] == "0")
        #expect(custom["AC Power"]?["lowpowermode"] == "1")
        #expect(custom["Battery Power"]?["displaysleep"] == "2")
        #expect(custom["AC Power"]?["displaysleep"] == "10")
        #expect(custom["Battery Power"]?["womp"] == "0")
        #expect(custom["AC Power"]?["womp"] == "1")
        // Path value survives the column padding.
        #expect(custom["Battery Power"]?["hibernatefile"] == "/var/vm/sleepimage")
        // Key present in only one section.
        #expect(custom["Battery Power"]?["highstandbythreshold"] == "50")
        #expect(custom["AC Power"]?["highstandbythreshold"] == nil)
    }

    @Test("blank lines, trailing header whitespace, and odd padding are tolerated")
    func customBlankLinesAndWeirdSpacing() {
        let messy =
            "Battery Power:   \n" +
            "\n" +
            "     lidwake              1\n" +
            "  displaysleep      2\n" +
            "\n" +
            "\n" +
            "AC Power:\t\n" +
            "lowpowermode 1\n" +
            " \t \n"
        let custom = PMSetParser.parseCustom(messy)
        #expect(custom == [
            "Battery Power": ["lidwake": "1", "displaysleep": "2"],
            "AC Power": ["lowpowermode": "1"],
        ])
    }

    @Test("keys containing spaces parse whole (last token is the value)")
    func customKeyWithSpacesParses() {
        // The reason for the last-token-is-value design: desktop Macs emit
        // multi-word keys like "Sleep On Power Button".
        let text = """
            AC Power:
             Sleep On Power Button 1
             lowpowermode          0
            """
        let custom = PMSetParser.parseCustom(text)
        #expect(custom == [
            "AC Power": ["Sleep On Power Button": "1", "lowpowermode": "0"]
        ])
        #expect(PMSetParser.intSetting("Sleep On Power Button", fromCustom: text) == ["AC Power": 1])

        // Runs of spaces inside a multi-word key collapse to single spaces
        // (tokens are re-joined with " ").
        let padded = "AC Power:\n Sleep  On  Power  Button 0"
        #expect(PMSetParser.parseCustom(padded)["AC Power"]?["Sleep On Power Button"] == "0")
    }

    @Test("a value containing spaces folds its head tokens into the key")
    func customSpaceValueFoldsIntoKey() {
        // CURRENT BEHAVIOR (suspected bug / documented limitation): because
        // the *last* token is taken as the value, a value with internal
        // spaces — e.g. a hibernatefile path on a volume named with spaces —
        // is mangled: the head of the value joins the key, and a lookup of
        // the real key ("hibernatefile") returns nil. Tolerable under the
        // nil-over-guess rule, but the setting becomes unreadable.
        let text = """
            AC Power:
             hibernatefile        /Volumes/Macintosh HD/vm/sleepimage
            """
        let custom = PMSetParser.parseCustom(text)
        #expect(custom["AC Power"]?["hibernatefile"] == nil)
        #expect(custom["AC Power"]?["hibernatefile /Volumes/Macintosh"] == "HD/vm/sleepimage")
    }

    @Test("a lone tab between spaces becomes a token joined into the key")
    func customSpaceTabSpaceTokenJoinsIntoKey() {
        // CURRENT BEHAVIOR: the key/value split is on spaces only, so a tab
        // surrounded by spaces survives as its own token and is joined into
        // the key. Real pmset -g custom output never mixes tabs into the
        // key/value padding, so this is unreachable in practice.
        let custom = PMSetParser.parseCustom("Battery Power:\n  displaysleep \t 2")
        #expect(custom == ["Battery Power": ["displaysleep \t": "2"]])
    }

    @Test("a line with a single token is dropped")
    func customSingleTokenLineDropped() {
        let text = """
            Battery Power:
             womp
             sleep 1
            """
        let custom = PMSetParser.parseCustom(text)
        #expect(custom == ["Battery Power": ["sleep": "1"]])
    }

    @Test("key/value lines before any section header are dropped")
    func customKeyValueBeforeAnySectionDropped() {
        let text = """
            lidwake 1
            Battery Power:
             sleep 10
            """
        let custom = PMSetParser.parseCustom(text)
        #expect(custom == ["Battery Power": ["sleep": "10"]])
    }

    @Test("a repeated section header merges into the existing section")
    func customRepeatedSectionMerges() {
        let text = """
            AC Power:
             womp 0
            Battery Power:
             sleep 1
            AC Power:
             disksleep 10
            """
        let custom = PMSetParser.parseCustom(text)
        #expect(custom == [
            "AC Power": ["womp": "0", "disksleep": "10"],
            "Battery Power": ["sleep": "1"],
        ])
    }

    @Test("duplicate key within a section: last occurrence wins")
    func customDuplicateKeyLastWins() {
        let text = """
            AC Power:
             sleep 1
             sleep 5
            """
        #expect(PMSetParser.parseCustom(text) == ["AC Power": ["sleep": "5"]])
    }

    @Test("a header with no settings yields a present-but-empty section")
    func customHeaderOnlySectionIsEmpty() {
        #expect(PMSetParser.parseCustom("AC Power:") == ["AC Power": [:]])
    }

    @Test("empty or whitespace-only input yields an empty dictionary", arguments: [
        "",
        "\n\n",
        "  \n\t\n ",
    ])
    func customEmptyOrWhitespaceInput(text: String) {
        #expect(PMSetParser.parseCustom(text) == [:])
    }

    @Test("an indented header line is treated as key/value data, not a section")
    func customIndentedHeaderTreatedAsKeyValue() {
        // Current behavior, documented deliberately: real pmset emits section
        // headers at column 0, so an indented "AC Power:" is NOT a header.
        // It falls through to key/value parsing ("AC" -> "Power:") and the
        // following settings stay attributed to the previous section.
        let text = """
            Battery Power:
             lowpowermode 0
              AC Power:
             lowpowermode 1
            """
        let custom = PMSetParser.parseCustom(text)
        #expect(custom == [
            "Battery Power": ["lowpowermode": "1", "AC": "Power:"]
        ])
        #expect(custom["AC Power"] == nil)
    }

    @Test("a tab-separated key/value pair (no space) is dropped")
    func customTabSeparatedPairDropped() {
        // Current behavior: the key/value split is on spaces only. Real
        // pmset -g custom pads with spaces, so a tab-only separator never
        // occurs in practice and such a line parses as a single token.
        let text = "AC Power:\n\tlidwake\t1"
        #expect(PMSetParser.parseCustom(text) == ["AC Power": [:]])
    }

    // MARK: - intSetting

    @Test("intSetting(lowpowermode) returns per-section integers")
    func intSettingLowPowerModePerSection() {
        #expect(PMSetParser.intSetting("lowpowermode", fromCustom: Self.customBothSections)
            == ["Battery Power": 0, "AC Power": 1])
        #expect(PMSetParser.intSetting("womp", fromCustom: Self.customBothSections)
            == ["Battery Power": 0, "AC Power": 1])
        // Key present in a single section only.
        #expect(PMSetParser.intSetting("highstandbythreshold", fromCustom: Self.customBothSections)
            == ["Battery Power": 50])
    }

    @Test("non-numeric value drops that section only")
    func intSettingDropsNonNumericValuePerSection() {
        let text = """
            Battery Power:
             lowpowermode         off
            AC Power:
             lowpowermode         1
            """
        #expect(PMSetParser.intSetting("lowpowermode", fromCustom: text) == ["AC Power": 1])
        // A path value is never an Int, so the key yields an empty map.
        #expect(PMSetParser.intSetting("hibernatefile", fromCustom: Self.customBothSections) == [:])
    }

    @Test("sections missing the key are dropped (compactMapValues semantics)")
    func intSettingDropsSectionsWithoutParseableKey() {
        let text = """
            Battery Power:
             lowpowermode         0
            AC Power:
             lidwake              1
            UPS Power:
            """
        // parseCustom keeps all three sections (UPS Power is empty)...
        #expect(Set(PMSetParser.parseCustom(text).keys) == ["Battery Power", "AC Power", "UPS Power"])
        // ...but intSetting keeps only sections where the key parses to Int.
        #expect(PMSetParser.intSetting("lowpowermode", fromCustom: text) == ["Battery Power": 0])
        #expect(PMSetParser.intSetting("nosuchkey", fromCustom: text) == [:])
    }

    @Test("numeric edge values: large, negative, zero-padded, and embedded spaces")
    func intSettingNumericEdges() {
        let text = """
            AC Power:
             standbydelayhigh     86400
             gpuswitch            -1
             sleep                007
             displaysleep         1 2
            """
        #expect(PMSetParser.intSetting("standbydelayhigh", fromCustom: text) == ["AC Power": 86400])
        #expect(PMSetParser.intSetting("gpuswitch", fromCustom: text) == ["AC Power": -1])
        #expect(PMSetParser.intSetting("sleep", fromCustom: text) == ["AC Power": 7])
        // CURRENT BEHAVIOR: "displaysleep 1 2" parses as key "displaysleep 1"
        // with value "2" (last token is the value), so the real key is
        // absent and reads nil rather than a wrong number.
        #expect(PMSetParser.parseCustom(text)["AC Power"]?["displaysleep"] == nil)
        #expect(PMSetParser.parseCustom(text)["AC Power"]?["displaysleep 1"] == "2")
        #expect(PMSetParser.intSetting("displaysleep", fromCustom: text) == [:])
        #expect(PMSetParser.intSetting("displaysleep 1", fromCustom: text) == ["AC Power": 2])
    }

    @Test("intSetting on empty input yields an empty dictionary")
    func intSettingEmptyInput() {
        #expect(PMSetParser.intSetting("lowpowermode", fromCustom: "") == [:])
    }
}
