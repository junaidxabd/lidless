# Helper and Recovery Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every locally testable Lidless safety boundary fail closed under stale clients, uncertain child termination, corrupt configuration, scheduled-wake faults, and unverified cleanup.

**Architecture:** New pure policies in `LidlessCore` define compatibility, normalization, termination certainty, thermal urgency, and scheduled-wake transactions. App and helper code remain narrow I/O adapters, and current automatic helper removal is disabled until a durable cross-process epoch can be live-validated.

**Tech Stack:** Swift 6, Foundation, Swift Testing, macOS 15, ServiceManagement/XPC adapters, `pmset` adapter code (never invoked by tests).

## Global Constraints

- Never invoke live `pmset`, install/remove a helper, alter ServiceManagement, or change system power settings.
- Preserve ordinary restore/disarm/repair availability when risk-increasing work is refused.
- Swift 6.0 compatibility and complete strict concurrency are required.
- No new external dependencies.
- Every production behavior change starts with a failing executable test.
- Source-string tests may prove adapter wiring only; behavioral policy belongs in executable pure tests.
- Automatic helper cleanup, replacement, and uninstall remain disabled in this local candidate.
- Signed runtime, launchd, reboot, sleep/wake, notarization, and hardware checks remain external release gates.

---

### Task 1: Normalize all cutoff inputs and make critical thermal pressure immediate

**Files:**
- Modify: `Packages/LidlessCore/Sources/LidlessCore/Config.swift`
- Modify: `Packages/LidlessCore/Sources/LidlessCore/Models.swift`
- Modify: `Packages/LidlessCore/Sources/LidlessCore/CutoffEngine.swift`
- Modify: `Packages/LidlessCore/Sources/LidlessCore/ThermalEvidenceSafety.swift`
- Modify: `App/Sources/Services/ConfigStore.swift`
- Modify: `App/Sources/AppState.swift`
- Test: `Packages/LidlessCore/Tests/LidlessCoreTests/ConfigNormalizationTests.swift`
- Test: `Packages/LidlessCore/Tests/LidlessCoreTests/CutoffEngineTests.swift`
- Test: `Packages/LidlessCore/Tests/LidlessCoreTests/ThermalTelemetrySafetyTests.swift`

**Interfaces:**
- Produces: `CutoffConfig.normalized() -> CutoffConfig`
- Produces: `HMTime.normalized() -> HMTime`
- Consumes: normalized values in decode, overrides, assessment, planning, and evaluation.

- [ ] **Step 1: Write failing normalization property tests**

```swift
@Test func extremeConfigurationAlwaysNormalizesToSafeFiniteBounds() {
    var config = CutoffConfig()
    config.batteryFloorPercent = .max
    config.thermalSpeedLimitFloor = .min
    config.thermalStrikesRequired = .max
    config.durationSeconds = .infinity
    config.offTime = HMTime(hour: .max, minute: .min)

    let value = config.normalized()
    #expect((5...50).contains(value.batteryFloorPercent))
    #expect((20...90).contains(value.thermalSpeedLimitFloor))
    #expect((1...5).contains(value.thermalStrikesRequired))
    #expect(value.durationSeconds == 24 * 3600)
    #expect(value.offTime == HMTime(hour: 23, minute: 0))
}
```

- [ ] **Step 2: Run the focused tests and verify RED**

Run the `ConfigNormalizationTests` filter with the repository-local SwiftPM cache command. Expected: compile failure because `normalized()` does not exist.

- [ ] **Step 3: Implement exact normalization**

```swift
public func normalized() -> CutoffConfig {
    var value = self
    value.batteryFloorPercent = min(max(value.batteryFloorPercent, 5), 50)
    value.thermalSpeedLimitFloor = min(max(value.thermalSpeedLimitFloor, 20), 90)
    value.thermalStrikesRequired = min(max(value.thermalStrikesRequired, 1), 5)
    value.durationSeconds = value.durationSeconds.isFinite
        ? min(max(value.durationSeconds, 30 * 60), 24 * 3600)
        : 24 * 3600
    value.offTime = value.offTime.normalized()
    return value
}
```

Normalize loaded config, `effectiveConfig`, and every `CutoffEngine` entry point before arithmetic.

- [ ] **Step 4: Write the failing critical-thermal test**

```swift
@Test func criticalProcessPressureFiresWithoutDebounce() {
    let result = CutoffEngine.evaluate(
        config: CutoffConfig(), armedAt: now, now: now,
        battery: usableBattery, thermal: usableNominalThermal,
        processThermal: .critical, thermalStrikes: 0, calendar: calendar
    )
    #expect(result.fired.contains { if case .thermal = $0 { true } else { false } })
}
```

- [ ] **Step 5: Verify RED, implement immediate critical policy, and verify GREEN**

`CutoffEngine.evaluate` fires `.thermal` immediately for `.critical`; serious and `pmset` violations retain debounce. Run normalization, cutoff, and thermal suites, then the full core suite.

### Task 2: Require exact client identity for risk-increasing helper requests

**Files:**
- Modify: `Packages/LidlessCore/Sources/LidlessCore/LidlessIDs.swift`
- Modify: `Packages/LidlessCore/Sources/LidlessCore/HelperIPC.swift`
- Create: `Packages/LidlessCore/Sources/LidlessCore/HelperClientAdmissionSafety.swift`
- Test: `Packages/LidlessCore/Tests/LidlessCoreTests/HelperClientAdmissionSafetyTests.swift`
- Modify: `Packages/LidlessCore/Tests/LidlessCoreTests/HelperSafetyRevisionTests.swift`

**Interfaces:**
- Produces: `HelperClientIdentity.current`
- Produces: `HelperClientAdmissionSafety.allows(_:identity:)`
- Produces: `HelperScheduleWakeRequest(identity:desiredDate:)`
- `HelperArmOptions` and `HelperDisarmOptions` gain optional `clientIdentity` with current defaults.

- [ ] **Step 1: Write failing exact-admission tests**

```swift
@Test(arguments: [nil, .init(protocolVersion: 5, safetyRevision: 8), .init(protocolVersion: 6, safetyRevision: 7), .init(protocolVersion: 6, safetyRevision: 9)])
func staleOrMissingIdentityCannotIncreaseRisk(_ identity: HelperClientIdentity?) {
    #expect(!HelperClientAdmissionSafety.allows(.arm, identity: identity))
    #expect(!HelperClientAdmissionSafety.allows(.scheduleWake, identity: identity))
    #expect(!HelperClientAdmissionSafety.allows(.forceSleep, identity: identity))
    #expect(HelperClientAdmissionSafety.allows(.restoreNormalSleep, identity: identity))
}
```

- [ ] **Step 2: Verify RED**

Expected: missing admission types.

- [ ] **Step 3: Implement policy and backward-decodable payloads**

```swift
public struct HelperClientIdentity: Codable, Sendable, Equatable {
    public var protocolVersion: Int
    public var safetyRevision: Int
    public static let current = HelperClientIdentity(
        protocolVersion: LidlessIDs.helperVersion,
        safetyRevision: LidlessIDs.helperSafetyRevision
    )
}
```

Advance `helperSafetyRevision` to 8 and pin revision 7 as the reviewed predecessor for classification only; automatic cleanup remains disabled.

- [ ] **Step 4: Verify wire round trips and legacy missing-field decoding**

Legacy arm/disarm JSON must decode with `clientIdentity == nil` so the helper can return a structured refusal or de-risking reply.

- [ ] **Step 5: Run admission and revision suites, then full core suite**

### Task 3: Wire current-client admission through app and helper

**Files:**
- Modify: `App/Sources/Helper/HelperClient.swift`
- Modify: `App/Sources/Simulation/Simulation.swift`
- Modify: `Helper/HelperDaemon.swift`
- Test: `Packages/LidlessCore/Tests/LidlessCoreTests/HelperClientAdmissionSafetyTests.swift`
- Modify: `Packages/LidlessCore/Tests/LidlessCoreTests/HelperDaemonSourceSafetyTests.swift`
- Modify: `Packages/LidlessCore/Tests/LidlessCoreTests/ScheduledWakeReconciliationTests.swift`

**Interfaces:**
- App calls new `scheduleWakeRequest(_:reply:)` and `prepareUninstallRequest(_:reply:)` selectors.
- Legacy scalar schedule and preparation selectors reply with refusal and perform no mutation.
- Helper gates arm, schedule, force-sleep, and cleanup preparation before lifecycle advance or mutation.

- [ ] **Step 1: Add failing adapter-wiring tests**

Tests assert that identity validation precedes `advanceLifecycle`, `PMSet.scheduleWake`, force-sleep dispatch, and cleanup authorization creation; legacy handlers contain no mutation call.

- [ ] **Step 2: Verify RED**

Expected: missing new selectors and admission guards.

- [ ] **Step 3: Update protocol bridges and current client calls**

Encode `HelperClientIdentity.current` at each current app call. Keep ping, heartbeat, ordinary disarm, and repair semantics intact.

- [ ] **Step 4: Gate helper mutation paths**

Arm and schedule reject invalid identity. Disarm always attempts restoration but strips/refuses `forceSleep` without exact identity. Cleanup preparation always refuses in the current candidate per Task 7.

- [ ] **Step 5: Run focused source-wiring tests and the full core suite**

### Task 4: Model and retain unproven child termination

**Files:**
- Create: `Packages/LidlessCore/Sources/LidlessCore/CommandTerminationSafety.swift`
- Test: `Packages/LidlessCore/Tests/LidlessCoreTests/CommandTerminationSafetyTests.swift`
- Modify: `Helper/PMSet.swift`
- Modify: `Helper/HelperDaemon.swift`
- Modify: `Packages/LidlessCore/Tests/LidlessCoreTests/HelperDaemonSourceSafetyTests.swift`
- Modify: `Packages/LidlessCore/Tests/LidlessCoreTests/HelperTerminationSafetyTests.swift`

**Interfaces:**
- Produces: `CommandTerminationSafety.classify(killAccepted:exitObserved:)`
- Produces: `PMSet.TerminationWitness` with `isResolved`.
- `PMSet.CommandError` exposes `terminationCertainty` and optional witness.
- Daemon retains unresolved mutation witnesses and blocks sentinel deletion/new risky work until resolved.

- [ ] **Step 1: Write the failing truth-table test**

```swift
@Test(arguments: [
    (true, true, CommandTerminationSafety.Result.killedAndReaped),
    (false, true, .exited),
    (true, false, .unproven),
    (false, false, .unproven),
])
func timeoutClassification(_ accepted: Bool, _ observed: Bool, _ expected: CommandTerminationSafety.Result) {
    #expect(CommandTerminationSafety.classify(killAccepted: accepted, exitObserved: observed) == expected)
}
```

- [ ] **Step 2: Verify RED and implement the pure policy**

- [ ] **Step 3: Refactor `PMSet.run` to attach a retained witness**

The witness retains the `Process`; `isResolved` becomes true only when Foundation observes termination. A timed-out, unobserved child never collapses into an ordinary command error.

- [ ] **Step 4: Write the failing daemon wiring regression**

The source path for an unproven `disablesleep 1` error must register the witness and park recovery before any readback-based sentinel removal. Every restore attempt must call the unresolved-witness gate first.

- [ ] **Step 5: Implement the daemon gate and verify**

Prune resolved witnesses; while any remain, keep `restorePending`, schedule retry, refuse arm/wake/cleanup, and never delete the sentinel or voluntarily exit. Run command, daemon-source, termination, and full suites.

### Task 5: Verify optional managed settings before arm success

**Files:**
- Modify: `Packages/LidlessCore/Sources/LidlessCore/ManagedSettingRestorationSafety.swift`
- Modify: `Packages/LidlessCore/Sources/LidlessCore/HelperIPC.swift`
- Modify: `Packages/LidlessCore/Sources/LidlessCore/HelperSupervisionTiming.swift`
- Modify: `Helper/HelperDaemon.swift`
- Test: `Packages/LidlessCore/Tests/LidlessCoreTests/ManagedSettingRestorationSafetyTests.swift`
- Test: `Packages/LidlessCore/Tests/LidlessCoreTests/HelperSupervisionTimingTests.swift`
- Modify: `Packages/LidlessCore/Tests/LidlessCoreTests/HelperDaemonSourceSafetyTests.swift`

**Interfaces:**
- Produces: `ManagedSettingRestorationSafety.isProven(for:target:fromCustom:)`.
- Minimum watchdog TTL becomes 45 seconds.
- Arm success follows exact activation readback.

- [ ] **Step 1: Add failing activation-proof tests**

Use an activation plan with battery/AC values and assert missing, malformed, partial, mismatched, and exact readbacks.

- [ ] **Step 2: Verify RED and generalize the proof function**

Retain `isRestorationProven` as a compatibility wrapper over the generic proof.

- [ ] **Step 3: Add failing ordering/timing tests**

Assert `apply(managedActivationPlan)` and `readCustom()` occur before the success reply, and the worst-case command count is strictly below the 45-second minimum TTL.

- [ ] **Step 4: Move activation before success and fail into recovery**

If apply or readback fails, call the sentinel-backed abort/restore path and do not report arm success. Register any unproven mutation witness from Task 4.

- [ ] **Step 5: Run managed-setting, timing, daemon-source, and full suites**

### Task 6: Implement the durable scheduled-wake ledger kernel

**Files:**
- Create: `Packages/LidlessCore/Sources/LidlessCore/ScheduledWakeLedger.swift`
- Create: `Packages/LidlessCore/Sources/LidlessCore/ScheduledWakeOutputParser.swift`
- Test: `Packages/LidlessCore/Tests/LidlessCoreTests/ScheduledWakeLedgerTests.swift`
- Test: `Packages/LidlessCore/Tests/LidlessCoreTests/ScheduledWakeOutputParserTests.swift`

**Interfaces:**
- Produces: `ScheduledWakeLedger(version:events:)`
- Produces: `ScheduledWakeLedger.Event(rendered:date:phase:)`
- Produces deterministic `nextAction(observedEvents:)` and transition methods.
- Parser returns exact rendered wake strings owned by a `pmset` schedule line.

- [ ] **Step 1: Write failing transaction/crash tests**

Cover new schedule, replacement, cancellation, pending-schedule restart, pending-cancel restart, duplicate desired wake, corrupt phase, and exact success postconditions.

- [ ] **Step 2: Verify RED**

Expected: missing ledger types.

- [ ] **Step 3: Implement the smallest deterministic ledger**

```swift
public struct ScheduledWakeLedger: Codable, Sendable, Equatable {
    public enum Phase: String, Codable, Sendable { case pendingSchedule, scheduled, pendingCancel }
    public struct Event: Codable, Sendable, Equatable, Identifiable {
        public var id: UUID
        public var date: Date
        public var rendered: String
        public var phase: Phase
    }
    public var version = 1
    public var events: [Event]
}
```

Sort actions deterministically; never drop an event without observed proof.

- [ ] **Step 4: Write parser fixtures and implement exact matching**

Fixtures include unrelated system events, multiple wake types, malformed lines, timezone text, exact manual `pmset` wakes, and duplicate dates. No test reads host schedules.

- [ ] **Step 5: Run ledger/parser and full core suites**

### Task 7: Wire scheduled-wake transactions and disable automatic cleanup

**Files:**
- Modify: `Helper/PMSet.swift`
- Modify: `Helper/HelperDaemon.swift`
- Modify: `App/Sources/Helper/HelperClient.swift`
- Modify: `App/Sources/AppState.swift`
- Modify: `App/Sources/UI/Main/SetupPane.swift`
- Modify: `App/Sources/UI/Onboarding/OnboardingView.swift`
- Delete: `Casks/lidless.rb`
- Modify: `README.md`
- Modify: `ARCHITECTURE.md`
- Modify: `Packages/LidlessCore/Tests/LidlessCoreTests/ScheduledWakeReconciliationTests.swift`
- Modify: `Packages/LidlessCore/Tests/LidlessCoreTests/HelperRemovalAppSafetyTests.swift`
- Modify: `Packages/LidlessCore/Tests/LidlessCoreTests/HelperRemovalDaemonFenceTests.swift`

**Interfaces:**
- `PMSet.readScheduledWakes()` supplies read-only output to the parser.
- Ledger persistence throws and never uses `try?`.
- Current cleanup preparation returns a reviewed-removal-required refusal.

- [ ] **Step 1: Add failing adapter tests for each transaction boundary**

Assert persist-before-mutate, observe-before-transition, old-event retention
until absence proof, and no success reply before final committed persistence.

- [ ] **Step 2: Verify RED**

- [ ] **Step 3: Replace `StoredWake` best-effort persistence with the ledger**

On every failure, retain the last durable ledger, return failure, and reconcile
on the next safe tick/start. Register unproven command witnesses.

- [ ] **Step 4: Disable cleanup and remove unsafe distribution surface**

`prepareUninstallRequest` and all legacy cleanup entry points perform no mutation
and return a precise reviewed-removal-required message. UI removes the active
uninstall button. Delete the incomplete cask and document that public packaging
waits for a live-validated durable removal protocol.

- [ ] **Step 5: Run scheduled-wake, removal, release-policy, and full suites**

### Task 8: Surface persistence failures and preserve unresolved session truth

**Files:**
- Modify: `App/Sources/Services/ConfigStore.swift`
- Modify: `App/Sources/Services/SessionStore.swift`
- Modify: `App/Sources/AppState.swift`
- Modify: `App/Sources/UI/MenuBar/MenuPanelView.swift`
- Modify: `App/Sources/UI/Main/SetupPane.swift`
- Test: `Packages/LidlessCore/Tests/LidlessCoreTests/ReleasePolicySourceTests.swift`
- Create: `Packages/LidlessCore/Tests/LidlessCoreTests/PersistenceTruthSourceTests.swift`

**Interfaces:**
- Stores expose `lastPersistenceError: String?`.
- Orphan journal remains available as unresolved evidence until reconciliation chooses an end reason.

- [ ] **Step 1: Add failing persistence-truth wiring tests**

Forbid `try?` on config/session writes and immediate orphan `.appQuit` deletion; require an observable error and unresolved-journal path.

- [ ] **Step 2: Verify RED**

- [ ] **Step 3: Implement visible persistence results**

Catch exact write/read/delete errors, retain data in memory, and expose concise recovery copy. Simulation remains ephemeral and silent.

- [ ] **Step 4: Reconcile orphan journals after helper status**

Do not invent watchdog/helper-restored detail; use an explicit unresolved end reason until evidence selects a truthful reason.

- [ ] **Step 5: Run persistence source tests and full core suite**

### Task 9: Correct unsupported-helper and cutoff claims

**Files:**
- Modify: `App/Sources/LidlessApp.swift`
- Modify: `App/Sources/AppState.swift`
- Modify: `App/Sources/UI/Onboarding/OnboardingView.swift`
- Modify: `README.md`
- Test: `Packages/LidlessCore/Tests/LidlessCoreTests/ArmLossRecoveryTests.swift`
- Test: `Packages/LidlessCore/Tests/LidlessCoreTests/DelayedSleepSafetyTests.swift`

**Interfaces:**
- Copy never guarantees behavior by an incompatible helper.
- Pre-cutoff notifications distinguish end-of-keep-awake from verified force-sleep dispatch.

- [ ] **Step 1: Write failing negative-copy tests**

Forbid “cannot make the sleep setting worse” and any promise that incompatible-helper connection loss restores normal sleep. Forbid “Sleeping soon” before force-sleep authorization.

- [ ] **Step 2: Verify RED**

- [ ] **Step 3: Replace copy with evidence-bounded language**

Force quit ends app-side verification; the user must restore and independently verify normal sleep first. Cutoff warning says the keep-awake session is ending unless the later exact force-sleep path is proven.

- [ ] **Step 4: Run focused and full suites**

### Task 10: Strengthen local build and release policy

**Files:**
- Modify: `.github/workflows/ci.yml`
- Modify: `Scripts/verify_release_bundle.sh`
- Modify: `Packages/LidlessCore/Tests/LidlessCoreTests/ReleasePolicySourceTests.swift`
- Modify: `Makefile`
- Modify: `CONTRIBUTING.md`

**Interfaces:**
- CI has core, project-drift, Debug, Release, analyze, and shell-syntax steps.
- Distribution verifier requires `arm64` and `x86_64`.
- `make test-local` uses repository-local caches without weakening normal CI sandboxing.

- [ ] **Step 1: Add failing release-policy tests**

Assert CI includes Release and analyze, verifier checks both architectures, and no release-ready cask contains placeholder hash/removal claims.

- [ ] **Step 2: Verify RED**

- [ ] **Step 3: Update workflow, verifier, and local developer targets**

Keep `make test` unchanged for normal environments; add a documented local-cache target for this restricted workspace.

- [ ] **Step 4: Run shell syntax, release-policy tests, XcodeGen drift, and full suite**

Run `bash -n` on both scripts, `xcodegen generate` followed by project diff, and the complete core suite. Xcode compilation is verified separately in the verification plan.
