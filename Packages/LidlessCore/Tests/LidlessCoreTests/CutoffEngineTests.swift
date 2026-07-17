import Foundation
import Testing
import LidlessCore

// Fixed instants in America/Los_Angeles (PDT, UTC-7 in July), externally verified:
//   1_784_120_400 = 2026-07-15 06:00:00 PT
//   1_784_124_000 = 2026-07-15 07:00:00 PT
//   1_784_181_600 = 2026-07-15 23:00:00 PT
//   1_784_210_400 = 2026-07-16 07:00:00 PT
private let t0600 = Date(timeIntervalSince1970: 1_784_120_400)
private let t0700 = Date(timeIntervalSince1970: 1_784_124_000)
private let t2300 = Date(timeIntervalSince1970: 1_784_181_600)
private let t0700NextDay = Date(timeIntervalSince1970: 1_784_210_400)

@Suite("CutoffEngine")
struct CutoffEngineTests {

    // MARK: - Fixtures

    private var la: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return cal
    }

    /// A config whose defaults mirror the shipping `CutoffConfig()` defaults,
    /// with every knob overridable per test.
    private func config(
        batteryFloorEnabled: Bool = true,
        batteryFloorPercent: Int = 10,
        thermalEnabled: Bool = true,
        thermalSpeedLimitFloor: Int = 60,
        thermalStrikesRequired: Int = 2,
        durationEnabled: Bool = false,
        durationSeconds: TimeInterval = 4 * 3600,
        offTimeEnabled: Bool = false,
        offTime: HMTime = HMTime(hour: 7, minute: 0)
    ) -> CutoffConfig {
        var c = CutoffConfig()
        c.batteryFloorEnabled = batteryFloorEnabled
        c.batteryFloorPercent = batteryFloorPercent
        c.thermalEnabled = thermalEnabled
        c.thermalSpeedLimitFloor = thermalSpeedLimitFloor
        c.thermalStrikesRequired = thermalStrikesRequired
        c.durationEnabled = durationEnabled
        c.durationSeconds = durationSeconds
        c.offTimeEnabled = offTimeEnabled
        c.offTime = offTime
        return c
    }

    private func battery(_ percent: Int?, state: PowerSourceState, charging: Bool = false) -> BatterySnapshot {
        BatterySnapshot(percent: percent, state: state, isCharging: charging, sampledAt: t0600)
    }

    private func discharging(_ percent: Int) -> BatterySnapshot { battery(percent, state: .battery) }
    private func onAC(_ percent: Int?) -> BatterySnapshot { battery(percent, state: .ac) }

    private func reading(warningLevel: Int? = nil, cpuSpeedLimit: Int? = nil) -> ThermalReading {
        ThermalReading(warningLevel: warningLevel, cpuSpeedLimit: cpuSpeedLimit, sampledAt: t0600)
    }

    private func evaluate(
        config: CutoffConfig,
        armedAt: Date = t0600,
        now: Date,
        battery: BatterySnapshot,
        thermal: ThermalReading? = nil,
        processThermal: ProcessThermalLevel = .nominal,
        thermalStrikes: Int = 0
    ) -> CutoffEvaluation {
        CutoffEngine.evaluate(
            config: config,
            armedAt: armedAt,
            now: now,
            battery: battery,
            thermal: thermal,
            processThermal: processThermal,
            thermalStrikes: thermalStrikes,
            calendar: la
        )
    }

    // MARK: - assessArm

    @Test func assessArm_onACAtThreePercent_ok() {
        // The floor only governs discharge; if unplugged later below the floor,
        // the cutoff fires then. Arming on AC is always allowed.
        #expect(CutoffEngine.assessArm(config: config(), battery: onAC(3)) == .ok)
        // Charging counts as "on AC" even if state reports .battery quirks aside;
        // an actively charging 3% machine is also allowed.
        #expect(CutoffEngine.assessArm(config: config(), battery: battery(3, state: .battery, charging: true)) == .ok)
    }

    @Test func assessArm_noBattery_ok() {
        // Desktop: battery cutoffs simply never fire, arming is always ok.
        #expect(CutoffEngine.assessArm(config: config(), battery: battery(nil, state: .ac)) == .ok)
        #expect(CutoffEngine.assessArm(config: config(), battery: battery(nil, state: .unknown)) == .ok)
        #expect(CutoffEngine.assessArm(config: config(), battery: battery(nil, state: .battery)) == .ok)
    }

    @Test func assessArm_dischargingAtFloor_refused() {
        #expect(CutoffEngine.assessArm(config: config(), battery: discharging(10))
                == .refusedBelowFloor(percent: 10, floor: 10))
    }

    @Test func assessArm_dischargingAtFloorPlusOne_refused() {
        #expect(CutoffEngine.assessArm(config: config(), battery: discharging(11))
                == .refusedBelowFloor(percent: 11, floor: 10))
    }

    @Test func assessArm_dischargingAtFloorPlusTwo_refused() {
        // Margin boundary: refusal is percent <= floor + armRefusalMargin (2).
        #expect(CutoffConfig.armRefusalMargin == 2)
        #expect(CutoffEngine.assessArm(config: config(), battery: discharging(12))
                == .refusedBelowFloor(percent: 12, floor: 10))
    }

    @Test func assessArm_dischargingAtFloorPlusThree_warnsInsteadOfRefusing() {
        // First percent above the refusal margin: arming allowed, but 13 < 30
        // so the low-battery warning applies.
        #expect(CutoffEngine.assessArm(config: config(), battery: discharging(13))
                == .lowBatteryWarning(percent: 13))
    }

    @Test func assessArm_dischargingAt29_lowBatteryWarning() {
        #expect(CutoffConfig.armLowBatteryWarning == 30)
        #expect(CutoffEngine.assessArm(config: config(), battery: discharging(29))
                == .lowBatteryWarning(percent: 29))
    }

    @Test func assessArm_dischargingAt30_ok() {
        // Warning is strictly below 30: exactly 30 arms silently.
        #expect(CutoffEngine.assessArm(config: config(), battery: discharging(30)) == .ok)
    }

    @Test func assessArm_floorDisabled_noRefusalButWarningStillApplies() {
        let c = config(batteryFloorEnabled: false)
        // At and below what would have been the refusal band: warned, not refused.
        #expect(CutoffEngine.assessArm(config: c, battery: discharging(10)) == .lowBatteryWarning(percent: 10))
        #expect(CutoffEngine.assessArm(config: c, battery: discharging(3)) == .lowBatteryWarning(percent: 3))
        // Healthy battery with floor disabled: plain ok.
        #expect(CutoffEngine.assessArm(config: c, battery: discharging(30)) == .ok)
        #expect(CutoffEngine.assessArm(config: c, battery: discharging(80)) == .ok)
    }

    @Test func assessArm_chargingAt25_ok() {
        // Charging suppresses both refusal and warning: not discharging.
        #expect(CutoffEngine.assessArm(config: config(), battery: battery(25, state: .battery, charging: true)) == .ok)
    }

    @Test func assessArm_unknownPowerState_notDischarging_ok() {
        // .unknown power state is not "discharging", so even 5% arms without
        // refusal — the floor cutoff arms live and fires once discharge is known.
        #expect(CutoffEngine.assessArm(config: config(), battery: battery(5, state: .unknown)) == .ok)
    }

    // MARK: - plannedCutoffs

    @Test func planned_durationOnly() {
        let c = config(durationEnabled: true, durationSeconds: 7200)
        let planned = CutoffEngine.plannedCutoffs(config: c, armedAt: t0600, calendar: la)
        #expect(planned == [PlannedCutoff(kind: .duration, date: t0600.addingTimeInterval(7200))])
    }

    @Test func planned_offTimeOnly_armedLateEvening_firesNextMorning() {
        // Arm 23:00 with a 07:00 off-time -> fires 07:00 tomorrow.
        let c = config(offTimeEnabled: true)
        let planned = CutoffEngine.plannedCutoffs(config: c, armedAt: t2300, calendar: la)
        #expect(planned == [PlannedCutoff(kind: .offTime, date: t0700NextDay)])
    }

    @Test func planned_offTimeOnly_armedEarlyMorning_firesSameDay() {
        // Arm 06:00 with a 07:00 off-time -> fires 07:00 the same day.
        let c = config(offTimeEnabled: true)
        let planned = CutoffEngine.plannedCutoffs(config: c, armedAt: t0600, calendar: la)
        #expect(planned == [PlannedCutoff(kind: .offTime, date: t0700)])
    }

    @Test func planned_offTimeOnly_armedExactlyAtOffTime_firesTomorrow() {
        // "Strictly after": arming at exactly 07:00:00 schedules tomorrow's 07:00,
        // never an immediate same-instant cutoff.
        let c = config(offTimeEnabled: true)
        let planned = CutoffEngine.plannedCutoffs(config: c, armedAt: t0700, calendar: la)
        #expect(planned == [PlannedCutoff(kind: .offTime, date: t0700NextDay)])
    }

    @Test func planned_bothEnabled_sortedAscendingByDate() {
        // Duration (06:30) before off-time (07:00): natural insertion order.
        let short = config(durationEnabled: true, durationSeconds: 1800, offTimeEnabled: true)
        #expect(CutoffEngine.plannedCutoffs(config: short, armedAt: t0600, calendar: la) == [
            PlannedCutoff(kind: .duration, date: t0600.addingTimeInterval(1800)),
            PlannedCutoff(kind: .offTime, date: t0700),
        ])
        // Off-time (07:00) before duration (10:00): the sort must reorder,
        // because duration is appended first internally.
        let long = config(durationEnabled: true, durationSeconds: 4 * 3600, offTimeEnabled: true)
        #expect(CutoffEngine.plannedCutoffs(config: long, armedAt: t0600, calendar: la) == [
            PlannedCutoff(kind: .offTime, date: t0700),
            PlannedCutoff(kind: .duration, date: t0600.addingTimeInterval(4 * 3600)),
        ])
    }

    @Test func planned_zeroOrNegativeDuration_omitsDurationCutoff() {
        let zero = config(durationEnabled: true, durationSeconds: 0)
        #expect(CutoffEngine.plannedCutoffs(config: zero, armedAt: t0600, calendar: la).isEmpty)

        let negative = config(durationEnabled: true, durationSeconds: -3600)
        #expect(CutoffEngine.plannedCutoffs(config: negative, armedAt: t0600, calendar: la).isEmpty)

        // A degenerate duration must not suppress an enabled off-time.
        let zeroWithOffTime = config(durationEnabled: true, durationSeconds: 0, offTimeEnabled: true)
        #expect(CutoffEngine.plannedCutoffs(config: zeroWithOffTime, armedAt: t0600, calendar: la)
                == [PlannedCutoff(kind: .offTime, date: t0700)])
    }

    @Test func planned_disabledFlags_empty() {
        // Both time cutoffs disabled (despite a positive durationSeconds): nothing planned.
        let c = config(durationEnabled: false, durationSeconds: 7200, offTimeEnabled: false)
        #expect(CutoffEngine.plannedCutoffs(config: c, armedAt: t0600, calendar: la).isEmpty)
    }

    // MARK: - isThermalViolation

    @Test func thermalViolation_warningLevelOne_true() {
        #expect(CutoffEngine.isThermalViolation(config: config(), thermal: reading(warningLevel: 1), processThermal: .nominal))
    }

    @Test func thermalViolation_warningLevelZero_false() {
        #expect(!CutoffEngine.isThermalViolation(config: config(), thermal: reading(warningLevel: 0), processThermal: .nominal))
    }

    @Test func thermalViolation_nilReadingNominalProcess_false() {
        #expect(!CutoffEngine.isThermalViolation(config: config(), thermal: nil, processThermal: .nominal))
    }

    @Test func thermalViolation_cpuSpeedLimitFloorBoundary() {
        // Floor 60: 59 violates, exactly 60 does not.
        #expect(CutoffEngine.isThermalViolation(config: config(), thermal: reading(cpuSpeedLimit: 59), processThermal: .nominal))
        #expect(!CutoffEngine.isThermalViolation(config: config(), thermal: reading(cpuSpeedLimit: 60), processThermal: .nominal))
        // A nominal warning level (0) must not mask a speed-limit violation.
        #expect(CutoffEngine.isThermalViolation(config: config(), thermal: reading(warningLevel: 0, cpuSpeedLimit: 59), processThermal: .nominal))
    }

    @Test func thermalViolation_processThermalLevels() {
        #expect(CutoffEngine.isThermalViolation(config: config(), thermal: nil, processThermal: .serious))
        #expect(CutoffEngine.isThermalViolation(config: config(), thermal: nil, processThermal: .critical))
        #expect(!CutoffEngine.isThermalViolation(config: config(), thermal: nil, processThermal: .fair))
        #expect(!CutoffEngine.isThermalViolation(config: config(), thermal: nil, processThermal: .nominal))
    }

    @Test func thermalViolation_disabled_alwaysFalse() {
        // With thermal protection off, even the worst possible picture is not a violation.
        let c = config(thermalEnabled: false)
        #expect(!CutoffEngine.isThermalViolation(config: c, thermal: reading(warningLevel: 3, cpuSpeedLimit: 10), processThermal: .critical))
    }

    // MARK: - evaluate: battery floor

    @Test func evaluateBattery_atFloorWhileDischarging_fires() {
        let r = evaluate(config: config(), now: t0600.addingTimeInterval(600), battery: discharging(10))
        #expect(r.fired == [.batteryFloor(percent: 10, floor: 10)])
        #expect(!r.thermalViolation)
        #expect(r.nextTimeCutoff == nil)
    }

    @Test func evaluateBattery_oneAboveFloor_doesNotFire() {
        let r = evaluate(config: config(), now: t0600.addingTimeInterval(600), battery: discharging(11))
        #expect(r.fired.isEmpty)
    }

    @Test func evaluateBattery_belowFloor_fires() {
        // Deep below the floor (missed polls) must still fire, not just exact equality.
        let r = evaluate(config: config(), now: t0600.addingTimeInterval(600), battery: discharging(4))
        #expect(r.fired == [.batteryFloor(percent: 4, floor: 10)])
    }

    @Test func evaluateBattery_chargingAtFivePercent_doesNotFire() {
        // Plugging in suspends the floor: charging at 5% is not a cutoff.
        let charging = battery(5, state: .battery, charging: true)
        #expect(evaluate(config: config(), now: t0600.addingTimeInterval(600), battery: charging).fired.isEmpty)
        // Same on AC.
        #expect(evaluate(config: config(), now: t0600.addingTimeInterval(600), battery: onAC(5)).fired.isEmpty)
    }

    @Test func evaluateBattery_floorDisabledOrNoBattery_doesNotFire() {
        let disabled = config(batteryFloorEnabled: false)
        #expect(evaluate(config: disabled, now: t0600.addingTimeInterval(600), battery: discharging(1)).fired.isEmpty)
        // No battery hardware: nil percent never fires even in .battery state.
        #expect(evaluate(config: config(), now: t0600.addingTimeInterval(600), battery: battery(nil, state: .battery)).fired.isEmpty)
    }

    // MARK: - evaluate: thermal strikes

    @Test func evaluateThermal_firstStrikeOfTwo_reportsViolationWithoutFiring() {
        // strikesRequired 2, zero prior strikes: 0 + 1 < 2 -> no cutoff yet,
        // but the violation must be surfaced so the caller can count it.
        let r = evaluate(config: config(thermalStrikesRequired: 2),
                         now: t0600.addingTimeInterval(60),
                         battery: onAC(80),
                         thermal: reading(warningLevel: 1),
                         thermalStrikes: 0)
        #expect(r.fired.isEmpty)
        #expect(r.thermalViolation)
    }

    @Test func evaluateThermal_secondStrikeOfTwo_fires() {
        // One prior strike: 1 + 1 >= 2 -> fire.
        let r = evaluate(config: config(thermalStrikesRequired: 2),
                         now: t0600.addingTimeInterval(60),
                         battery: onAC(80),
                         thermal: reading(warningLevel: 1),
                         thermalStrikes: 1)
        #expect(r.fired == [.thermal(detail: "Thermal warning level 1")])
        #expect(r.thermalViolation)
    }

    @Test func evaluateThermal_strikesRequiredZero_clampsToOne_firesOnFirstViolation() {
        // max(1, 0) == 1: a misconfigured 0 can never mean "never fire".
        let r = evaluate(config: config(thermalStrikesRequired: 0),
                         now: t0600.addingTimeInterval(60),
                         battery: onAC(80),
                         thermal: reading(warningLevel: 1),
                         thermalStrikes: 0)
        #expect(r.fired == [.thermal(detail: "Thermal warning level 1")])
    }

    @Test func evaluateThermal_strikesRequiredOne_firesOnFirstViolation() {
        let r = evaluate(config: config(thermalStrikesRequired: 1),
                         now: t0600.addingTimeInterval(60),
                         battery: onAC(80),
                         thermal: reading(cpuSpeedLimit: 59),
                         thermalStrikes: 0)
        #expect(r.fired == [.thermal(detail: "CPU limited to 59%")])
        #expect(r.thermalViolation)
    }

    @Test func evaluateThermal_noViolation_priorStrikesIrrelevant() {
        // A healthy reading never fires, no matter how many strikes accumulated.
        let r = evaluate(config: config(thermalStrikesRequired: 2),
                         now: t0600.addingTimeInterval(60),
                         battery: onAC(80),
                         thermal: reading(warningLevel: 0, cpuSpeedLimit: 100),
                         thermalStrikes: 99)
        #expect(r.fired.isEmpty)
        #expect(!r.thermalViolation)
    }

    @Test func evaluateThermal_disabled_neverFires() {
        let r = evaluate(config: config(thermalEnabled: false),
                         now: t0600.addingTimeInterval(60),
                         battery: onAC(80),
                         thermal: reading(warningLevel: 3, cpuSpeedLimit: 10),
                         processThermal: .critical,
                         thermalStrikes: 99)
        #expect(r.fired.isEmpty)
        #expect(!r.thermalViolation)
    }

    // MARK: - evaluate: time cutoffs

    @Test func evaluateDuration_firesExactlyAtPlannedDate() {
        let c = config(durationEnabled: true, durationSeconds: 3600)
        // One second before the boundary: nothing fires, countdown still shows it.
        let before = evaluate(config: c, now: Date(timeIntervalSince1970: 1_784_123_999), battery: onAC(80))
        #expect(before.fired.isEmpty)
        #expect(before.nextTimeCutoff == PlannedCutoff(kind: .duration, date: t0700))
        // now == fire date: fires (>=, not >).
        let at = evaluate(config: c, now: t0700, battery: onAC(80))
        #expect(at.fired == [.durationElapsed])
        #expect(at.nextTimeCutoff == nil)
    }

    @Test func evaluateOffTime_firesExactlyAtPlannedDate() {
        let c = config(offTimeEnabled: true)
        // Armed 23:00; planned fire is 07:00 next day.
        let before = evaluate(config: c, armedAt: t2300, now: Date(timeIntervalSince1970: 1_784_210_399), battery: onAC(80))
        #expect(before.fired.isEmpty)
        #expect(before.nextTimeCutoff == PlannedCutoff(kind: .offTime, date: t0700NextDay))
        let at = evaluate(config: c, armedAt: t2300, now: t0700NextDay, battery: onAC(80))
        #expect(at.fired == [.offTime])
        #expect(at.nextTimeCutoff == nil)
    }

    @Test func evaluate_multipleSimultaneousReasons_sortedByPriority() {
        // Duration fires at 06:30, off-time at 07:00; at 08:00 both have passed,
        // battery is at 8% discharging, and this is the second thermal strike.
        // Priority order must be thermal < batteryFloor < offTime < durationElapsed,
        // even though duration's *date* precedes the off-time's.
        let c = config(thermalStrikesRequired: 2, durationEnabled: true, durationSeconds: 1800, offTimeEnabled: true)
        let r = evaluate(config: c,
                         now: t0600.addingTimeInterval(7200),
                         battery: discharging(8),
                         thermal: reading(warningLevel: 1),
                         thermalStrikes: 1)
        #expect(r.fired == [
            .thermal(detail: "Thermal warning level 1"),
            .batteryFloor(percent: 8, floor: 10),
            .offTime,
            .durationElapsed,
        ])
        #expect(r.thermalViolation)
        #expect(r.nextTimeCutoff == nil)
    }

    @Test func evaluate_timeReasonsAlone_priorityOrderNotDateOrder() {
        // Duration (06:30) elapsed before off-time (07:00), but .offTime (priority 2)
        // must precede .durationElapsed (priority 3) in `fired`.
        let c = config(durationEnabled: true, durationSeconds: 1800, offTimeEnabled: true)
        let r = evaluate(config: c, now: t0600.addingTimeInterval(7200), battery: onAC(80))
        #expect(r.fired == [.offTime, .durationElapsed])
        #expect(r.nextTimeCutoff == nil) // all planned cutoffs have passed
    }

    @Test func evaluate_nextTimeCutoff_isEarliestUpcoming() {
        let c = config(durationEnabled: true, durationSeconds: 1800, offTimeEnabled: true)
        // 06:10: nothing fired; next is the earlier of the two (duration @ 06:30).
        let r = evaluate(config: c, now: t0600.addingTimeInterval(600), battery: onAC(80))
        #expect(r.fired.isEmpty)
        #expect(r.nextTimeCutoff == PlannedCutoff(kind: .duration, date: t0600.addingTimeInterval(1800)))
    }

    @Test func evaluate_nextTimeCutoff_strictlyAfterNow() {
        // Exactly at the duration boundary: it fires and is NOT "next";
        // next is the off-time still ahead.
        let c = config(durationEnabled: true, durationSeconds: 1800, offTimeEnabled: true)
        let r = evaluate(config: c, now: t0600.addingTimeInterval(1800), battery: onAC(80))
        #expect(r.fired == [.durationElapsed])
        #expect(r.nextTimeCutoff == PlannedCutoff(kind: .offTime, date: t0700))
    }

    @Test func evaluate_nextTimeCutoff_nilWhenNoneConfigured() {
        let r = evaluate(config: config(), now: t0600.addingTimeInterval(600), battery: onAC(80))
        #expect(r.fired.isEmpty)
        #expect(!r.thermalViolation)
        #expect(r.nextTimeCutoff == nil)
    }

    // MARK: - thermalDetail

    @Test func thermalDetail_branchMessages() {
        let c = config()
        #expect(CutoffEngine.thermalDetail(config: c, thermal: reading(warningLevel: 2), processThermal: .nominal)
                == "Thermal warning level 2")
        #expect(CutoffEngine.thermalDetail(config: c, thermal: reading(cpuSpeedLimit: 59), processThermal: .nominal)
                == "CPU limited to 59%")
        #expect(CutoffEngine.thermalDetail(config: c, thermal: nil, processThermal: .critical)
                == "System thermal state critical")
        #expect(CutoffEngine.thermalDetail(config: c, thermal: nil, processThermal: .serious)
                == "System thermal state serious")
        #expect(CutoffEngine.thermalDetail(config: c, thermal: nil, processThermal: .nominal)
                == "Thermal pressure")
        #expect(CutoffEngine.thermalDetail(config: c, thermal: nil, processThermal: .fair)
                == "Thermal pressure")
    }

    @Test func thermalDetail_attributesTriggerToActualViolator() {
        // An 80% speed limit is NOT a violation with floor 60; the cutoff
        // fires because processThermal is .serious, and the detail string
        // must blame that, not the CPU speed.
        let c = config(thermalStrikesRequired: 1)
        let r = evaluate(config: c,
                         now: t0600.addingTimeInterval(60),
                         battery: onAC(80),
                         thermal: reading(cpuSpeedLimit: 80),
                         processThermal: .serious)
        #expect(r.thermalViolation)
        #expect(r.fired == [.thermal(detail: "System thermal state serious")])
    }

    // MARK: - CutoffConfig.applying(overrides)

    @Test func applying_nilOverrides_unchanged() {
        let base = config(batteryFloorPercent: 15,
                          durationEnabled: true,
                          durationSeconds: 1234,
                          offTimeEnabled: true,
                          offTime: HMTime(hour: 22, minute: 30))
        #expect(base.applying(nil) == base)
    }

    @Test func applying_allNilFieldsOverrides_unchanged() {
        let base = config()
        #expect(base.applying(SessionOverrides.none) == base)
        #expect(base.applying(SessionOverrides()) == base)
    }

    @Test func applying_partialOverrides_touchOnlyGivenFields() {
        let base = config()
        let out = base.applying(SessionOverrides(batteryFloorPercent: 15, offTime: HMTime(hour: 22, minute: 30)))
        #expect(out.batteryFloorPercent == 15)
        #expect(out.offTime == HMTime(hour: 22, minute: 30))
        // Everything else inherits from the base.
        #expect(out.batteryFloorEnabled == base.batteryFloorEnabled)
        #expect(out.thermalEnabled == base.thermalEnabled)
        #expect(out.thermalSpeedLimitFloor == base.thermalSpeedLimitFloor)
        #expect(out.thermalStrikesRequired == base.thermalStrikesRequired)
        #expect(out.durationEnabled == base.durationEnabled)
        #expect(out.durationSeconds == base.durationSeconds)
        #expect(out.offTimeEnabled == base.offTimeEnabled)
    }

    @Test func preset_untilTwentyPercent_raisesFloorAndDisablesTimeCutoffs() {
        // Even from a base where the floor was disabled and both time cutoffs on.
        let base = config(batteryFloorEnabled: false,
                          batteryFloorPercent: 10,
                          durationEnabled: true,
                          durationSeconds: 7200,
                          offTimeEnabled: true,
                          offTime: HMTime(hour: 23, minute: 45))
        let out = base.applying(ArmPreset.untilTwentyPercent.overrides())
        #expect(out.batteryFloorEnabled)
        #expect(out.batteryFloorPercent == 20)
        #expect(!out.durationEnabled)
        #expect(!out.offTimeEnabled)
        // Untouched knobs inherit; thermal safety net is never weakened.
        #expect(out.durationSeconds == 7200)
        #expect(out.offTime == HMTime(hour: 23, minute: 45))
        #expect(out.thermalEnabled == base.thermalEnabled)
        #expect(out.thermalSpeedLimitFloor == base.thermalSpeedLimitFloor)
    }

    @Test func preset_untilMorning_sevenAMOffTimeEnabled_durationDisabled() {
        let base = config(durationEnabled: true,
                          durationSeconds: 7200,
                          offTimeEnabled: false,
                          offTime: HMTime(hour: 22, minute: 30))
        let out = base.applying(ArmPreset.untilMorning.overrides())
        #expect(!out.durationEnabled)
        #expect(out.offTimeEnabled)
        #expect(out.offTime == HMTime(hour: 7, minute: 0))
        // Only the flag flips; the stored duration length is untouched.
        #expect(out.durationSeconds == 7200)
        // Battery/thermal safety nets remain in force.
        #expect(out.batteryFloorEnabled == base.batteryFloorEnabled)
        #expect(out.batteryFloorPercent == base.batteryFloorPercent)
        #expect(out.thermalEnabled == base.thermalEnabled)
    }

    @Test func preset_nextFourHours_fourHourDurationEnabled_offTimeDisabled() {
        let base = config(durationEnabled: false,
                          durationSeconds: 60,
                          offTimeEnabled: true,
                          offTime: HMTime(hour: 22, minute: 30))
        let out = base.applying(ArmPreset.nextFourHours.overrides())
        #expect(out.durationEnabled)
        #expect(out.durationSeconds == 4 * 3600)
        #expect(!out.offTimeEnabled)
        // The stored off-time value itself is untouched, only disabled.
        #expect(out.offTime == HMTime(hour: 22, minute: 30))
        #expect(out.batteryFloorEnabled == base.batteryFloorEnabled)
        #expect(out.batteryFloorPercent == base.batteryFloorPercent)
    }

    // MARK: - CutoffReason priority

    @Test func cutoffReason_priorityOrdering_safetyOutranksConvenience() {
        let ordered: [CutoffReason] = [
            .thermal(detail: "x"),
            .batteryFloor(percent: 1, floor: 10),
            .offTime,
            .durationElapsed,
            .scheduleEnded,
        ]
        #expect(ordered.map(\.priority) == [0, 1, 2, 3, 4])
    }
}
