# Lidless Recovery and Live Validation Procedure

## Status and authority

This is a **review plan**, not authorization to mutate a Mac. The 2026-08-07
completion lane did not install a helper, invoke live `pmset`, change a system
setting, sign, notarize, or release anything. Follow the privileged sections
only after the founder gives a fresh, exact instruction for the named machine,
build identity, and test window.

## Truth hierarchy during recovery

Use these sources in order; do not promote a weaker signal into proof:

1. A fresh independent `IOPMrootDomain.SleepDisabled` registry observation.
2. A structurally complete current-helper status and exact readback.
3. Durable sentinel, mutation-marker, and wake-ledger obligations.
4. App presentation and logs as explanations, never as independent proof.

“The command returned,” “the helper disappeared,” “the app says normal,” and
“no schedule was parsed” are not proof by themselves.

## Operator-safe recovery boundary

If Lidless cannot verify normal sleep:

1. Stop new keep-awake requests and leave the helper registered so launchd
   supervision remains available.
2. Keep Lidless open and use its visible restore/recheck path when the current
   helper is reachable.
3. Independently read the sleep-disabled registry value using the command shown
   in Setup & Help. Normal sleep is proven only when the result explicitly says
   `SleepDisabled = No`.
4. If the app cannot restore and a privileged operator has fresh authorization,
   request ordinary sleep with `sudo pmset -a disablesleep 0`.
5. Repeat the independent registry read. Treat missing, malformed, or
   contradictory output as unresolved.
6. Do not delete helper files, markers, ledgers, launchd registration, optional
   setting priors, or scheduled-wake evidence as part of this fallback.

The manual command restores only the main sleep override. It does not prove
that helper-owned scheduled wakes were cancelled, optional Low Power Mode or
`tcpkeepalive` values were restored, durable evidence was reconciled, or the
helper is safe to remove.

## Signed-runtime validation prerequisites

Before any live mutation:

- use a dedicated test Mac with a known recovery route and adequate power;
- record the exact commit or immutable source snapshot and signed bundle hashes;
- use one Apple team and the expected app, widget, helper, and app-group IDs;
- confirm the helper binary and launchd property list came from that bundle;
- record baseline registry, `pmset`, scheduled-event, battery, thermal, login
  item, and helper-registration state;
- define abort criteria and a second operator or remote recovery path for
  closed-lid testing;
- protect unrelated scheduled wake events and optional power settings;
- capture timestamps, command exits, independent readbacks, helper status,
  durable record state, and process/launchd state for every transition.

## Live matrix

### Signed identity and admission

- Current same-team app can connect and obtain a structurally complete status.
- Ad-hoc, wrong-team, wrong-bundle, stale-revision, and wrong-wire clients are
  rejected according to the risk-increasing versus recovery-only boundary.
- Interrupted and invalidated connections trigger one owner-terminal path.
- A local timeout never becomes proof that the remote command did not run.

### Arm and restore

- Normal arm: sentinel durable before mutation, registry ON after the command,
  exact ownership/status proof before armed UI.
- Explicit disarm: registry OFF and managed-setting restoration before the
  sentinel clears.
- App crash, helper crash, SIGTERM, SIGINT, watchdog expiry, and XPC loss:
  launchd supervision persists until normal sleep is independently proven.
- Command timeout and forced reap: no late child outcome can escape the durable
  mutation marker.
- Outside override: app does not claim ownership; repair can request ordinary
  sleep but does not fabricate a Lidless session.

### Boot and sleep boundaries

- Relaunch with same-boot mutation uncertainty remains fail-closed.
- Reboot changes boot identity, prevents old child completion, and still
  requires fresh readback before clearing recovery.
- RunAtLoad and each `KeepAlive.PathState` witness relaunch the helper as
  expected.
- Sleep/wake callbacks, post-wake grace, closed-lid cutoff, and optional
  `sleepnow` occur only after their generation-bound proof.
- Forced power loss retains enough durable evidence to select recovery.

### Scheduled wakes

- Schedule an exact Lidless event; confirm exact readback before commit.
- Replace it and prove the old event becomes a cancellation obligation.
- Inject duplicate exact observations; prove all extras are cancelled.
- Crash before command, during command, after command/before readback, and after
  readback/before ledger commit; prove each restart converges without promoting
  uncertain intent.
- Preserve unrelated valid system wake events.
- Treat malformed or changed `pmset -g sched` output as parser failure, not
  authoritative absence.

### Hardware and product behavior

- Battery floor at, below, and just above threshold; charging transition;
  topology-proven no-battery machine; telemetry loss and recovery.
- Thermal warning, CPU throttling, critical ProcessInfo pressure, stale/future
  sample, malformed recognized fields, clock rollback, and cool-down recovery.
- Minimum/default/wide window, menu error/refusal states, onboarding failure,
  widget fresh/stale/empty states, and icon at native sizes.
- VoiceOver labels and announcements, keyboard-only operation, default/cancel
  actions, focus order, Reduce Motion, increased contrast, long copy, and text
  scaling.

## Removal remains a separate review

Do not infer a removal procedure from recovery. A future removal design must be
revision-specific and prove, before deregistration, that normal sleep is
independently verified, no helper-owned restore or wake obligation remains,
no privileged child can complete late, managed settings are reconciled, and
the signed client/helper identities match the reviewed procedure. It must then
survive crash-boundary and downgrade testing. Until that exists, cleanup APIs
correctly refuse and the helper stays registered.

## Completion evidence

A live gate is complete only when the captured record includes the signed
bundle identities, starting state, exact action, command/process outcome,
independent system readback, durable-obligation state, observed UI state, and
successful recovery from each deliberately injected failure. A green unit test
or a helper reply alone is insufficient.
