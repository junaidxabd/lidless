import Foundation
import Testing
@testable import LidlessCore

@Suite("Battery telemetry safety")
struct BatteryTelemetrySafetyTests {
    private let now = Date(timeIntervalSince1970: 1_784_120_400)

    private var floorEnabled: CutoffConfig {
        var config = CutoffConfig()
        config.batteryFloorEnabled = true
        config.batteryFloorPercent = 10
        config.thermalEnabled = false
        return config
    }

    private var floorDisabled: CutoffConfig {
        var config = floorEnabled
        config.batteryFloorEnabled = false
        return config
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }

    private func sourceReading(
        type: String? = "InternalBattery",
        currentCapacity: Int? = 50,
        maximumCapacity: Int? = 100,
        sourceState: String? = "Battery Power",
        isCharging: Bool? = false,
        timeToEmptyMinutes: Int? = 60
    ) -> BatteryPowerSourceReading {
        BatteryPowerSourceReading.classify(
            type: type,
            internalBatteryType: "InternalBattery",
            alternatePowerSourceType: "UPS",
            currentCapacity: currentCapacity,
            maximumCapacity: maximumCapacity,
            sourceState: sourceState,
            acPowerState: "AC Power",
            batteryPowerState: "Battery Power",
            isCharging: isCharging,
            timeToEmptyMinutes: timeToEmptyMinutes
        )
    }

    private func battery(
        percent: Int?,
        state: PowerSourceState,
        charging: Bool = false
    ) -> BatterySnapshot {
        BatterySnapshot(
            percent: percent,
            state: state,
            isCharging: charging,
            sampledAt: now
        )
    }

    private var unverifiedReadings: [BatterySnapshot] {
        [
            .unknown(at: now),
            battery(percent: nil, state: .ac),
            battery(percent: nil, state: .battery),
            battery(percent: 50, state: .unknown),
            battery(percent: 50, state: .noBattery),
            battery(percent: nil, state: .noBattery, charging: true),
            battery(percent: -1, state: .battery),
            battery(percent: 101, state: .ac),
        ]
    }

    private func assess(
        config: CutoffConfig,
        battery: BatterySnapshot
    ) -> ArmAssessment {
        CutoffEngine.assessArm(
            config: config,
            battery: battery,
            thermal: nil,
            processThermal: .nominal,
            at: now
        )
    }

    @Test func enabledFloorRefusesArmWithoutUsableBatteryEvidence() {
        for reading in unverifiedReadings {
            let assessment = assess(
                config: floorEnabled,
                battery: reading
            )
            #expect(assessment == .refusedBatteryTelemetryUnavailable)
            #expect(!assessment.allowsArm)
        }
    }

    @Test func enabledFloorEndsAnArmedSessionWhenBatteryEvidenceIsLost() {
        for reading in unverifiedReadings {
            let evaluation = CutoffEngine.evaluate(
                config: floorEnabled,
                armedAt: now,
                now: now.addingTimeInterval(60),
                battery: reading,
                thermal: nil,
                calendar: calendar
            )
            #expect(evaluation.fired == [.batteryTelemetryUnavailable])
        }
    }

    @Test func explicitFloorOptOutDoesNotInventATelemetryCutoff() {
        for reading in unverifiedReadings {
            #expect(assess(
                config: floorDisabled,
                battery: reading
            ) == .ok)
            let evaluation = CutoffEngine.evaluate(
                config: floorDisabled,
                armedAt: now,
                now: now.addingTimeInterval(60),
                battery: reading,
                thermal: nil,
                calendar: calendar
            )
            #expect(evaluation.fired.isEmpty)
        }
    }

    @Test func provenBatteryAbsenceDoesNotCreateAFictitiousFloor() {
        let noBattery = BatterySnapshot.noBattery(at: now)
        #expect(noBattery.hasUsableSafetyEvidence)
        #expect(assess(
            config: floorEnabled,
            battery: noBattery
        ) == .ok)
        let evaluation = CutoffEngine.evaluate(
            config: floorEnabled,
            armedAt: now,
            now: now.addingTimeInterval(60),
            battery: noBattery,
            thermal: nil,
            calendar: calendar
        )
        #expect(evaluation.fired.isEmpty)
    }

    @Test func enumerationAbsenceNeedsIndependentHardwareProof() {
        let empty = BatterySnapshotNormalizer.normalize([], at: now)
        #expect(empty == .unknown(at: now))

        let ups = sourceReading(type: "UPS", sourceState: nil)
        let upsOnly = BatterySnapshotNormalizer.normalize([ups], at: now)
        #expect(upsOnly == .unknown(at: now))

        let provenEmpty = BatterySnapshotNormalizer.normalize(
            [],
            noInternalBatteryProven: true,
            at: now
        )
        #expect(provenEmpty == .noBattery(at: now))
        let provenUPSOnly = BatterySnapshotNormalizer.normalize(
            [ups],
            noInternalBatteryProven: true,
            at: now
        )
        #expect(provenUPSOnly == .noBattery(at: now))

        let validBattery = sourceReading()
        let contaminated = BatterySnapshotNormalizer.normalize(
            [validBattery, .unavailable],
            at: now
        )
        #expect(contaminated == .unknown(at: now))
        #expect(BatterySnapshotNormalizer.normalize(
            [validBattery, validBattery],
            at: now
        ) == .unknown(at: now))
        #expect(BatterySnapshotNormalizer.normalize(
            [validBattery, ups],
            at: now
        ).state == .battery)
        #expect(BatterySnapshotNormalizer.normalize(
            [ups, validBattery],
            at: now
        ).state == .battery)
    }

    @Test func malformedTypesAndPowerStatesStayUnavailable() {
        #expect(sourceReading(type: nil) == .unavailable)
        #expect(sourceReading(type: "NovelPowerSource") == .unavailable)
        #expect(sourceReading(sourceState: nil) == .unavailable)
        #expect(sourceReading(sourceState: "Off Line") == .unavailable)

        let ac = BatterySnapshotNormalizer.normalize(
            [sourceReading(sourceState: "AC Power", isCharging: true)],
            at: now
        )
        #expect(ac.percent == 50)
        #expect(ac.state == .ac)
        #expect(ac.isCharging)

        let discharging = BatterySnapshotNormalizer.normalize(
            [sourceReading(isCharging: nil)],
            at: now
        )
        #expect(discharging.state == .battery)
        #expect(discharging.isDischarging)
        #expect(BatterySnapshotNormalizer.normalize(
            [sourceReading(isCharging: true)],
            at: now
        ) == .unknown(at: now))
    }

    @Test func invalidAndExtremeCapacitiesCannotBecomeSafetyEvidence() {
        let invalid: [BatteryPowerSourceReading] = [
            sourceReading(currentCapacity: nil),
            sourceReading(maximumCapacity: nil),
            sourceReading(currentCapacity: -1),
            sourceReading(currentCapacity: 1, maximumCapacity: 0),
            sourceReading(currentCapacity: 101, maximumCapacity: 100),
            sourceReading(currentCapacity: Int.max, maximumCapacity: 1),
            sourceReading(currentCapacity: Int.min, maximumCapacity: Int.max),
        ]
        for reading in invalid {
            #expect(BatterySnapshotNormalizer.normalize(
                [reading],
                at: now
            ) == .unknown(at: now))
        }

        let boundedExtreme = BatterySnapshotNormalizer.normalize(
            [sourceReading(
                currentCapacity: Int.max,
                maximumCapacity: Int.max
            )],
            at: now
        )
        #expect(boundedExtreme.percent == 100)
        #expect(boundedExtreme.hasUsableSafetyEvidence)
    }

    @Test func extremeTimeEstimateCannotOverflowArmProjection() throws {
        let snapshot = BatterySnapshotNormalizer.normalize(
            [sourceReading(timeToEmptyMinutes: Int.max)],
            at: now
        )
        #expect(snapshot.timeToEmptyMinutes == nil)

        let app = try repositoryFile("App/Sources/AppState.swift")
        let projection = try section(
            of: app,
            from: "private func projection(for cfg: CutoffConfig)",
            through: "return ArmProjection("
        )
        #expect(projection.contains("TimeInterval(minutes) * 60"))
        #expect(!projection.contains("minutes * 60"))
    }

    @Test func chargingWhileReportedOnBatteryIsContradictoryEvidence() {
        let contradictory = battery(
            percent: 50,
            state: .battery,
            charging: true
        )
        #expect(!contradictory.hasUsableSafetyEvidence)
        #expect(assess(
            config: floorEnabled,
            battery: contradictory
        ) == .refusedBatteryTelemetryUnavailable)
        #expect(CutoffEngine.evaluate(
            config: floorEnabled,
            armedAt: now,
            now: now.addingTimeInterval(60),
            battery: contradictory,
            thermal: nil,
            calendar: calendar
        ).fired == [.batteryTelemetryUnavailable])
    }

    @Test func telemetryCutoffKeepsItsPriorityAndCodableIdentity() throws {
        var config = floorEnabled
        config.thermalEnabled = true
        config.thermalStrikesRequired = 1
        config.durationEnabled = true
        config.durationSeconds = 30
        let evaluation = CutoffEngine.evaluate(
            config: config,
            armedAt: now,
            now: now.addingTimeInterval(60),
            battery: .unknown(at: now),
            thermal: ThermalReading(warningLevel: 1, sampledAt: now),
            thermalStrikes: 0,
            calendar: calendar
        )
        #expect(evaluation.fired == [
            .thermal(detail: "Thermal warning level 1"),
            .batteryTelemetryUnavailable,
            .durationElapsed,
        ])

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let encoded = try encoder.encode(CutoffReason.batteryTelemetryUnavailable)
        #expect(try decoder.decode(CutoffReason.self, from: encoded)
            == .batteryTelemetryUnavailable)
        let legacy = Data(#"{"offTime":{}}"#.utf8)
        #expect(try decoder.decode(CutoffReason.self, from: legacy) == .offTime)
        let nested = SessionEndReason.cutoff(.batteryTelemetryUnavailable)
        let nestedData = try encoder.encode(nested)
        #expect(try decoder.decode(SessionEndReason.self, from: nestedData)
            == nested)
    }

    @Test func refusalIsWiredThroughManualPresetAndScheduleSurfaces() throws {
        let app = try repositoryFile("App/Sources/AppState.swift")
        let panel = try repositoryFile(
            "App/Sources/UI/MenuBar/MenuPanelView.swift"
        )
        let confirmArm = try section(
            of: app,
            from: "func confirmArm() async",
            through: "func disarm() async"
        )
        let schedule = try section(
            of: app,
            from: "private func scheduleAutomationTick()",
            through: "private func maintainScheduledWake()"
        )

        #expect(confirmArm.contains("guard intent.assessment.allowsArm else"))
        #expect(confirmArm.contains("case .refusedBatteryTelemetryUnavailable"))
        let postArm = try section(
            of: String(confirmArm),
            from: "let postArmAssessment = CutoffEngine.assessArm(",
            through: "helperSessionProven = true"
        )
        #expect(postArm.contains("suppressCurrentScheduleOccurrence()"))
        #expect(!postArm.contains("if case .refusedBelowFloor"))
        #expect(schedule.contains("case .refusedBelowFloor:"))
        #expect(schedule.contains("case .refusedBatteryTelemetryUnavailable,"))
        #expect(schedule.contains(".refusedThermalTelemetryUnavailable,"))
        #expect(schedule.contains(".refusedThermalPressure:"))
        #expect(schedule.contains("Telemetry loss or thermal pressure is retryable"))
        #expect(panel.contains("!pending.assessment.allowsArm"))
        #expect(panel.contains("case .refusedBatteryTelemetryUnavailable"))
    }

    @Test func armCommitBoundaryRefreshesBatteryBeforeReassessment() throws {
        let app = try repositoryFile("App/Sources/AppState.swift")
        let confirmArm = try section(
            of: app,
            from: "func confirmArm() async",
            through: "func disarm() async"
        )
        let registryRefresh = try #require(confirmArm.range(
            of: "systemMonitor?.refresh()"
        ))
        let batteryRefresh = try #require(confirmArm.range(
            of: "batteryMonitor.refresh()",
            range: registryRefresh.upperBound..<confirmArm.endIndex
        ))
        let reassessment = try #require(confirmArm.range(
            of: "let freshAssessment = CutoffEngine.assessArm("
        ))

        #expect(registryRefresh.lowerBound < batteryRefresh.lowerBound)
        #expect(batteryRefresh.lowerBound < reassessment.lowerBound)
    }

    @Test func provenArmIsRecheckedAgainstFreshBatteryEvidence() throws {
        let app = try repositoryFile("App/Sources/AppState.swift")
        let confirmArm = try section(
            of: app,
            from: "func confirmArm() async",
            through: "func disarm() async"
        )
        let proof = try #require(confirmArm.range(
            of: "SleepOverrideSafety.isArmProven(reply)"
        ))
        let accepted = try #require(confirmArm.range(
            of: "helperSessionProven = true",
            range: proof.upperBound..<confirmArm.endIndex
        ))
        let postReplyRefresh = try #require(confirmArm.range(
            of: "batteryMonitor.refresh()",
            range: proof.upperBound..<accepted.lowerBound
        ))
        let postReplyAssessment = try #require(confirmArm.range(
            of: "let postArmAssessment = CutoffEngine.assessArm(",
            range: postReplyRefresh.upperBound..<accepted.lowerBound
        ))

        #expect(postReplyRefresh.lowerBound < postReplyAssessment.lowerBound)
    }

    @Test func monitorUsesExecutableFailClosedNormalization() throws {
        let monitor = try repositoryFile(
            "App/Sources/Monitors/BatteryMonitor.swift"
        )

        #expect(monitor.contains("BatteryPowerSourceReading.classify("))
        #expect(monitor.contains("BatterySnapshotNormalizer.normalize("))
        #expect(monitor.contains("guard let description"))
        #expect(monitor.contains("readings.append(.unavailable)"))
        #expect(monitor.contains("PowerRegistry.clamshellHardwareEvidence()"))
        #expect(monitor.contains("noInternalBatteryProven:"))
    }

    @Test func confirmationDistinguishesUnavailableAndNoBatteryStates() throws {
        let panel = try repositoryFile(
            "App/Sources/UI/MenuBar/MenuPanelView.swift"
        )

        #expect(panel.contains("state.battery.state == .noBattery"))
        #expect(panel.contains("No internal battery — configured floor is inactive"))
        #expect(panel.contains("showsBatteryFloor"))
        #expect(panel.contains("pending.assessment != .refusedBatteryTelemetryUnavailable"))
        #expect(panel.contains(".disabled(state.battery.state == .noBattery)"))
        #expect(panel.contains("state: state.battery.state"))
    }

    @Test func batteryOnlyPresetCannotArmWithoutAnInternalBattery() throws {
        let app = try repositoryFile("App/Sources/AppState.swift")
        let begin = try section(
            of: app,
            from: "func beginArmFlow(preset: ArmPreset? = nil)",
            through: "func cancelArmFlow()"
        )
        let confirm = try section(
            of: app,
            from: "func confirmArm() async",
            through: "func disarm() async"
        )

        #expect(begin.contains("batteryPresetIsAttainable(source)"))
        #expect(confirm.contains("batteryPresetIsAttainable(pending.source)"))
    }

    @Test func pendingBatteryPresetIsCancelledWhenTopologyProvesNoBattery() throws {
        let target = SessionSource.preset(.untilTwentyPercent)
        let validBattery = battery(percent: 50, state: .battery)
        let unknownBattery = BatterySnapshot.unknown(at: now)
        let noBattery = BatterySnapshot.noBattery(at: now)

        #expect(BatteryPresetAdmission.isAttainable(
            source: target,
            battery: validBattery
        ))
        #expect(BatteryPresetAdmission.isAttainable(
            source: target,
            battery: unknownBattery
        ))
        #expect(!BatteryPresetAdmission.isAttainable(
            source: target,
            battery: noBattery
        ))

        for preset in [ArmPreset.untilMorning, .nextFourHours] {
            #expect(BatteryPresetAdmission.isAttainable(
                source: .preset(preset),
                battery: noBattery
            ))
        }
        #expect(BatteryPresetAdmission.isAttainable(
            source: .manual,
            battery: noBattery
        ))
        #expect(BatteryPresetAdmission.isAttainable(
            source: .schedule(windowID: UUID()),
            battery: noBattery
        ))

        let app = try repositoryFile("App/Sources/AppState.swift")
        let refresh = try section(
            of: app,
            from: "func refreshPendingProjection()",
            through: "private func projection(for cfg: CutoffConfig)"
        )

        let admission = try #require(refresh.range(
            of: "guard batteryPresetIsAttainable(pending.source) else"
        ))
        let cancellation = try #require(refresh.range(
            of: "pendingArm = nil",
            range: admission.upperBound..<refresh.endIndex
        ))
        let rebuild = try #require(refresh.range(of: "pendingArm = PendingArm("))

        #expect(admission.lowerBound < cancellation.lowerBound)
        #expect(cancellation.lowerBound < rebuild.lowerBound)
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

    private func section(
        of source: String,
        from start: String,
        through end: String
    ) throws -> Substring {
        let startRange = try #require(source.range(of: start))
        let endRange = try #require(source.range(
            of: end,
            range: startRange.upperBound..<source.endIndex
        ))
        return source[startRange.lowerBound..<endRange.upperBound]
    }
}
