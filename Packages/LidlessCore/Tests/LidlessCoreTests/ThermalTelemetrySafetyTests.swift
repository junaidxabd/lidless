import Foundation
import Testing
@testable import LidlessCore

@Suite("Thermal telemetry safety")
struct ThermalTelemetrySafetyTests {
    private let now = Date(timeIntervalSince1970: 1_785_000_000)

    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    private func config(thermalEnabled: Bool = true) -> CutoffConfig {
        var value = CutoffConfig()
        value.batteryFloorEnabled = false
        value.thermalEnabled = thermalEnabled
        value.thermalStrikesRequired = 1
        return value
    }

    private func battery() -> BatterySnapshot {
        BatterySnapshot(
            percent: 80,
            state: .ac,
            isCharging: false,
            sampledAt: now
        )
    }

    private func reading(
        warningLevel: Int? = 0,
        cpuSpeedLimit: Int? = nil,
        sampledAt: Date? = nil
    ) -> ThermalReading {
        ThermalReading(
            warningLevel: warningLevel,
            cpuSpeedLimit: cpuSpeedLimit,
            sampledAt: sampledAt ?? now
        )
    }

    private func evaluation(
        thermal: ThermalReading?,
        processThermal: ProcessThermalLevel = .nominal,
        thermalEnabled: Bool = true
    ) -> CutoffEvaluation {
        CutoffEngine.evaluate(
            config: config(thermalEnabled: thermalEnabled),
            armedAt: now,
            now: now,
            battery: battery(),
            thermal: thermal,
            processThermal: processThermal,
            thermalStrikes: 0,
            calendar: calendar
        )
    }

    private func repositoryFile(_ relativePath: String) throws -> String {
        var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let fileManager = FileManager.default

        while directory.path != "/" {
            let candidate = directory.appendingPathComponent(relativePath)
            if fileManager.fileExists(atPath: candidate.path) {
                return try String(contentsOf: candidate, encoding: .utf8)
            }
            directory.deleteLastPathComponent()
        }

        throw CocoaError(.fileNoSuchFile)
    }

    @Test func enabledGuardCannotTreatUnavailableEvidenceAsHealthy() {
        let unavailable: [ThermalReading?] = [
            nil,
            reading(warningLevel: nil),
            reading(sampledAt: now.addingTimeInterval(-24 * 60 * 60)),
            reading(sampledAt: now.addingTimeInterval(1)),
            reading(warningLevel: -1),
            reading(warningLevel: 0, cpuSpeedLimit: 101),
            ThermalReading(
                warningLevel: 0,
                schedulerLimit: 101,
                sampledAt: now
            ),
            ThermalReading(
                warningLevel: 0,
                availableCPUs: 0,
                sampledAt: now
            ),
        ]

        for sample in unavailable {
            let result = evaluation(thermal: sample)
            #expect(result.fired == [.thermalTelemetryUnavailable])
        }
    }

    @Test func unavailableEvidenceRefusesANewThermalProtectedArm() {
        let assessment = CutoffEngine.assessArm(
            config: config(),
            battery: battery(),
            thermal: nil,
            processThermal: .nominal,
            at: now
        )
        #expect(assessment == .refusedThermalTelemetryUnavailable)
    }

    @Test func freshViolatingEvidenceCannotStartAThermalProtectedArm() {
        let warning = CutoffEngine.assessArm(
            config: config(),
            battery: battery(),
            thermal: reading(warningLevel: 1),
            processThermal: .nominal,
            at: now
        )
        let throttled = CutoffEngine.assessArm(
            config: config(),
            battery: battery(),
            thermal: reading(warningLevel: 0, cpuSpeedLimit: 59),
            processThermal: .nominal,
            at: now
        )
        let processPressure = CutoffEngine.assessArm(
            config: config(),
            battery: battery(),
            thermal: reading(),
            processThermal: .serious,
            at: now
        )

        #expect(warning == .refusedThermalPressure(
            detail: "Thermal warning level 1"
        ))
        #expect(throttled == .refusedThermalPressure(
            detail: "CPU limited to 59%"
        ))
        #expect(processPressure == .refusedThermalPressure(
            detail: "System thermal state serious"
        ))
    }

    @Test func criticalProcessPressureFiresWithoutDebounce() {
        var protected = config()
        protected.thermalStrikesRequired = 5

        let result = CutoffEngine.evaluate(
            config: protected,
            armedAt: now,
            now: now,
            battery: battery(),
            thermal: reading(),
            processThermal: .critical,
            thermalStrikes: 0,
            calendar: calendar
        )

        #expect(result.fired == [
            .thermal(detail: "System thermal state critical"),
        ])
        #expect(result.thermalViolation)
    }

    @Test func seriousProcessPressureRetainsConfiguredDebounce() {
        var protected = config()
        protected.thermalStrikesRequired = 5

        let result = CutoffEngine.evaluate(
            config: protected,
            armedAt: now,
            now: now,
            battery: battery(),
            thermal: reading(),
            processThermal: .serious,
            thermalStrikes: 0,
            calendar: calendar
        )

        #expect(result.fired.isEmpty)
        #expect(result.thermalViolation)
    }

    @Test func seriousPressureFailsClosedWhenWallClockMovesBackward() {
        var tracker = ThermalStrikeTracker()
        var protected = config()
        protected.thermalStrikesRequired = 5

        #expect(tracker.observe(
            config: protected,
            thermal: reading(),
            processThermal: .serious,
            at: now
        ) == 1)

        let rolledBack = now.addingTimeInterval(-1)
        let strikeCount = tracker.observe(
            config: protected,
            thermal: reading(sampledAt: rolledBack),
            processThermal: .serious,
            at: rolledBack
        )
        #expect(strikeCount == protected.thermalStrikesRequired)

        let result = CutoffEngine.evaluate(
            config: protected,
            armedAt: rolledBack,
            now: rolledBack,
            battery: battery(),
            thermal: reading(sampledAt: rolledBack),
            processThermal: .serious,
            thermalStrikes: max(0, strikeCount - 1),
            calendar: calendar
        )
        #expect(result.fired == [
            .thermal(detail: "System thermal state serious"),
        ])
    }

    @Test func criticalProcessPressureFiresAlongsideUnavailablePMSetEvidence() {
        var protected = config()
        protected.thermalStrikesRequired = 5
        let unavailable: [ThermalReading?] = [
            nil,
            reading(sampledAt: now.addingTimeInterval(-24 * 60 * 60)),
        ]

        for sample in unavailable {
            let result = CutoffEngine.evaluate(
                config: protected,
                armedAt: now,
                now: now,
                battery: battery(),
                thermal: sample,
                processThermal: .critical,
                thermalStrikes: 0,
                calendar: calendar
            )

            #expect(result.fired == [
                .thermal(detail: "System thermal state critical"),
                .thermalTelemetryUnavailable,
            ])
            #expect(result.thermalViolation)
        }
    }

    @Test func disabledGuardDoesNotInventAThermalFailure() {
        let result = evaluation(thermal: nil, thermalEnabled: false)
        #expect(result.fired.isEmpty)
        #expect(CutoffEngine.assessArm(
            config: config(thermalEnabled: false),
            battery: battery(),
            thermal: nil,
            processThermal: .critical,
            at: now
        ).allowsArm)
    }

    @Test func staleHotSampleCannotMasqueradeAsCurrentThermalEvidence() {
        let stale = reading(
            warningLevel: 1,
            sampledAt: now.addingTimeInterval(-24 * 60 * 60)
        )
        let result = evaluation(thermal: stale)
        #expect(result.fired == [.thermalTelemetryUnavailable])
    }

    @Test func freshnessAndStructureHaveExactFailClosedBoundaries() {
        let nominal = reading()
        #expect(ThermalEvidenceSafety.isUsable(nominal, at: now))
        #expect(ThermalEvidenceSafety.isUsable(
            reading(sampledAt: now.addingTimeInterval(-ThermalEvidenceSafety.maximumSampleAge)),
            at: now
        ))
        #expect(!ThermalEvidenceSafety.isUsable(
            reading(sampledAt: now.addingTimeInterval(-ThermalEvidenceSafety.maximumSampleAge - 0.001)),
            at: now
        ))
        #expect(!ThermalEvidenceSafety.isUsable(
            reading(sampledAt: now.addingTimeInterval(0.001)),
            at: now
        ))
        #expect(!ThermalEvidenceSafety.isUsable(
            ThermalReading(warningLevel: nil, sampledAt: now),
            at: now
        ))
    }

    @Test func recognizedMalformedOrContradictoryPMSetFieldsFailClosed() {
        let invalidOutputs = [
            """
            Note: No thermal warning level has been recorded
            Thermal Warning Level = 99999999999999999999999999
            """,
            """
            Note: No thermal warning level has been recorded
            CPU_Speed_Limit = nope
            """,
            """
            Thermal Warning Level = 0
            Thermal Warning Level = 1
            """,
            """
            Note: No thermal warning level has been recorded
            CPU_Scheduler_Limit = 100 trailing
            """,
            """
            Note: No thermal warning level has been recorded
            CPU_Available_CPUs = -99999999999999999999999999
            """,
        ]

        for output in invalidOutputs {
            let parsed = PMSetParser.parseTherm(output, sampledAt: now)
            #expect(!ThermalEvidenceSafety.isUsable(parsed, at: now))
        }
    }

    @Test func processPressureProgressesPastAnUnchangedViolatingPMSetSample() {
        var tracker = ThermalStrikeTracker()
        var protected = config()
        protected.thermalStrikesRequired = 2
        let hotPMSet = reading(warningLevel: 1)

        #expect(tracker.observe(
            config: protected,
            thermal: hotPMSet,
            processThermal: .nominal,
            at: now
        ) == 1)
        #expect(tracker.observe(
            config: protected,
            thermal: hotPMSet,
            processThermal: .serious,
            at: now.addingTimeInterval(15)
        ) == 1)
        #expect(tracker.observe(
            config: protected,
            thermal: hotPMSet,
            processThermal: .serious,
            at: now.addingTimeInterval(45)
        ) == 2)
        #expect(tracker.observe(
            config: protected,
            thermal: hotPMSet,
            processThermal: .serious,
            at: now.addingTimeInterval(60)
        ) == 2)
        #expect(tracker.observe(
            config: protected,
            thermal: hotPMSet,
            processThermal: .serious,
            at: now.addingTimeInterval(90)
        ) == 3)
    }

    @Test func strikeTrackerCountsDistinctEvidenceAndResetsOnRecovery() {
        var tracker = ThermalStrikeTracker()
        var protected = config()
        protected.thermalStrikesRequired = 3
        let first = reading(warningLevel: 1)
        let second = reading(
            warningLevel: 1,
            sampledAt: now.addingTimeInterval(30)
        )

        #expect(tracker.observe(
            config: protected,
            thermal: first,
            processThermal: .nominal,
            at: now
        ) == 1)
        #expect(tracker.observe(
            config: protected,
            thermal: first,
            processThermal: .nominal,
            at: now.addingTimeInterval(15)
        ) == 1)
        #expect(tracker.observe(
            config: protected,
            thermal: second,
            processThermal: .nominal,
            at: now.addingTimeInterval(30)
        ) == 1)
        #expect(tracker.observe(
            config: protected,
            thermal: second,
            processThermal: .nominal,
            at: now.addingTimeInterval(45)
        ) == 2)
        #expect(tracker.observe(
            config: protected,
            thermal: reading(sampledAt: now.addingTimeInterval(31)),
            processThermal: .nominal,
            at: now.addingTimeInterval(31)
        ) == 0)

        protected.thermalEnabled = false
        #expect(tracker.observe(
            config: protected,
            thermal: second,
            processThermal: .critical,
            at: now.addingTimeInterval(32)
        ) == 0)
    }

    @Test func telemetryCutoffPreservesItsCodableIdentity() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let encoded = try encoder.encode(CutoffReason.thermalTelemetryUnavailable)
        #expect(try decoder.decode(CutoffReason.self, from: encoded)
                == .thermalTelemetryUnavailable)
    }

    @Test func monitorPublishesInitialStateAndEveryPollFailure() throws {
        let monitor = try repositoryFile("App/Sources/Monitors/ThermalMonitor.swift")
        #expect(monitor.contains("processLevel = Self.level(from: ProcessInfo.processInfo.thermalState)\n        onChange?()"))
        #expect(monitor.contains("reading = nil"))
        #expect(monitor.contains("guard let output"))
        #expect(monitor.contains("reading = ThermalEvidenceSafety.accepted(parsed, at: Date())"))
        #expect(monitor.contains("inFlightPoll"))
        #expect(monitor.contains("await inFlight.task.value"))
        #expect(monitor.contains("while let inFlight = inFlightPoll"))
        #expect(monitor.contains("inFlight.startedAt >= notBefore"))
        #expect(monitor.contains("performPoll(sampledAt: startedAt)"))
        #expect(monitor.contains("else {\n            reading = nil\n            onChange?()\n            return\n        }"))
    }

    @Test func appRequiresThermalEvidenceAtEverySafetyBoundary() throws {
        let app = try repositoryFile("App/Sources/AppState.swift")
        #expect(app.contains("thermal = thermalMonitor.reading\n        processThermal = thermalMonitor.processLevel"))
        #expect(app.contains("await thermalMonitor.pollNow(notBefore: thermalBoundaryAt)"))
        #expect(app.contains("refusedThermalTelemetryUnavailable"))
        #expect(app.contains("refusedThermalPressure"))
        #expect(app.contains("processThermal: processThermal"))
        #expect(app.contains("thermalStrikeTracker.observe("))

        let postArmStart = try #require(app.range(
            of: "let postArmAssessment = CutoffEngine.assessArm("
        ))
        let postArmEnd = try #require(app.range(
            of: "completionError: \"The keep-awake request was restored because its confirmed safety plan or evidence changed while arming.\"",
            range: postArmStart.upperBound..<app.endIndex
        ))
        let postArm = app[postArmStart.lowerBound..<postArmEnd.upperBound]
        #expect(postArm.contains("processThermal: processThermal"))
        #expect(postArm.contains("beginRestore(PendingRestore("))

        let handlerStart = try #require(app.range(of: "private func thermalDidChange()"))
        let handlerEnd = try #require(app.range(
            of: "private func systemStateDidChange()",
            range: handlerStart.upperBound..<app.endIndex
        ))
        let handler = app[handlerStart.lowerBound..<handlerEnd.lowerBound]
        #expect(handler.contains("refreshPendingProjection()"))
    }
}
