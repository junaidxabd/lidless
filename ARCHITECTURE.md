# Lidless Architecture

Lidless is a native macOS utility that can request the root-only,
system-wide `pmset disablesleep` override needed to keep a closed MacBook
awake. The unacceptable failure mode is leaving that override enabled without
supervision. The architecture therefore treats every mutation as unproven
until it is read back, keeps recovery obligations durable, and prefers a
visible refusal over inferred success.

This document describes the verified local release-candidate design. It does
not claim that unsigned builds prove signed XPC trust, launchd behavior, real
`pmset` mutations, reboot persistence, or hardware thermal and battery
behavior. Those remain explicit live gates.

```
┌────────────────────────────────────────────────────────────┐
│ Lidless.app — unprivileged                                 │
│                                                            │
│  AppState          session/recovery state machine          │
│  Monitors          battery · thermal · lid · registry      │
│  SwiftUI           menu panel · window · onboarding        │
│  Persistence       config · session journal · history      │
└──────────────────────┬─────────────────────────────────────┘
                       │ NSXPC, signed peer requirement
                       │ status / arm / heartbeat / restore /
                       │ repair / wake scheduling
┌──────────────────────▼─────────────────────────────────────┐
│ LidlessHelper — root launchd daemon                        │
│                                                            │
│  Narrow actuator    pmset + IORegistry verification        │
│  Supervision        ownership · watchdog · sleep observer  │
│  Durable recovery   sentinel · mutation marker · wake log  │
└────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────┐
│ LidlessCore — shared deterministic policy, no mutations    │
│ Widget — read-only app-group projection, no authority      │
└────────────────────────────────────────────────────────────┘
```

## Boundaries and responsibilities

`Packages/LidlessCore` holds deterministic policy: configuration
normalization, arm admission, cutoff ordering, thermal-evidence validation,
schedule calculation, battery normalization, helper admission, managed-setting
restoration policy, XPC payloads, command timing, and the scheduled-wake
ledger. It does not run privileged commands.

The app owns user intent and product state. It monitors battery power-source
events, polls `pmset -g therm`, listens to `ProcessInfo.thermalState`, reads lid
and `IOPMrootDomain.SleepDisabled` evidence, reconciles sessions, and publishes
a read-only widget snapshot. The dark-only interface is a native safety
instrument: semantic color, native type, quiet hierarchy, one primary action,
and distinct normal, armed, restoring, outside-override, stale, and unknown
states. A screenshot is presentation evidence, never system-state proof.

The helper owns the smallest practical privileged surface. It does not decide
whether a cutoff should fire. It validates the requesting client, performs a
bounded mutation, reads the result back, and retains any unresolved recovery
obligation. The helper's current wire protocol is v6 and its safety behavior
revision is 8.

The widget cannot arm, restore, or classify the helper. It renders a timestamped
projection written by the app and exposes deep links back to the app. Real
WidgetKit hosting and app-group delivery require signed runtime validation.

## Evidence model

Lidless distinguishes four ideas that must not collapse into one another:

1. **Intent** — what the user or schedule requested.
2. **Reply** — what a helper process reported.
3. **Independent observation** — what a fresh registry or `pmset` read showed.
4. **Durable obligation** — what might still need reconciliation after a crash.

Risk-increasing work requires exact-current helper admission and operation-
specific proof. Normal-sleep recovery can accept a narrower exact-wire,
two-source proof: a structurally complete helper reply plus an independent
registry-OFF observation. A malformed, negative, timed-out, stale-wire, or
contradictory result never becomes success.

Every app-side XPC request has a 25-second local deadline and an exactly-once
completion gate. A timeout retires the captured connection and means the remote
outcome is unknown; it neither cancels a delivered request nor proves the
system state. For scheduled wakes, a reply this app refused after delivery is an indeterminate remote outcome, because the remote command may already have
been applied.

## Configuration and cutoff policy

All externally writable cutoff values are normalized before arithmetic or date
interpretation:

- battery floor: 5–50 percent;
- thermal CPU-speed floor: 20–90 percent;
- thermal strikes: 1–5;
- duration: 30 minutes–24 hours, with non-finite values mapped to 24 hours;
- wall-clock hour/minute: valid 24-hour components.

An enabled battery floor requires usable power-source evidence. Enumeration
absence alone is not proof that a machine has no battery; Lidless requires
independent topology evidence before showing the explicit no-battery state.
Loss of required evidence during an established session starts verified
restoration.

An enabled thermal guard requires a structurally valid `pmset` sample that is
not future-dated and is no more than 180 seconds old. Recognized malformed or
contradictory fields invalidate the sample. Serious `ProcessInfo` pressure is
debounced; critical pressure cuts off immediately. A clock rollback saturates
the strike requirement instead of extending a hot session.

Safety cutoff reasons outrank convenience cutoffs: thermal, missing thermal
evidence, missing battery evidence, battery floor, wall-clock time, duration,
then schedule end. Restoration must be proven before an optional `sleepnow`
follow-up is authorized.

## Arming transaction

1. The app creates an immutable, process-local pending intent. It snapshots the
   effective normalized configuration and, for an automated arm, the exact
   schedule occurrence.
2. The app refreshes helper admission, thermal evidence, battery evidence, and
   the actual override registry value. Any relevant drift revokes confirmation.
3. The helper validates the exact live connection and captures the current
   optional-setting priors.
4. The helper securely creates and fully synchronizes the override sentinel
   before it can enable `disablesleep`.
5. It re-proves the override is inactive, installs connection ownership and a
   monotonic watchdog deadline, runs the bounded command, and reads the registry
   back.
6. Optional Low Power Mode and `tcpkeepalive` changes are applied only with
   captured per-scope priors; restoration of touched state is strict.
7. Only an exact-current successful reply plus the app's post-reply safety
   checks may create a session. The active-session journal must then be written
   successfully before the heartbeat starts or the UI claims armed. A journal
   failure immediately enters verified restoration with a truthful terminal
   reason; any other post-mutation failure does the same.

The helper clamps watchdog TTL to 45–120 seconds. The app heartbeats every 10
seconds. Each `pmset` child gets 3 seconds, then at most 1 second for forced
termination and reap. The maximum arm/fail-safe path is eleven child waits, or
44 seconds, strictly below the 45-second minimum watchdog. A timeout whose
child exit is not observed remains a durable mutation uncertainty.

## Override recovery

The main invariant is:

> A Lidless-owned sleep override must never outlive supervision or be reported
> as restored without proof.

The helper layers these mechanisms:

### Secure sentinel

`/var/db/lidless/override-active` is a root-owned, mode-0600 regular file in a
validated root-owned directory. Descriptor-relative, no-follow operations,
link-count and ACL checks, checked closes, and full synchronization defend its
namespace and durability. The sentinel is written before `disablesleep 1` and
removed only after exact normal-sleep and managed-setting restoration proof. A
corrupt or legacy record selects recovery; it is not treated as absent.

### Connection ownership

Each accepted XPC connection receives a process-local identity. Only the exact
owner of the active session may heartbeat. Interruption and invalidation pass
through one terminal gate; other authenticated clients may request de-risking
restore but cannot prolong the override.

### Watchdog and launchd

An expired heartbeat restores normal sleep. A 30-second post-wake grace avoids
racing a just-resumed app. `RunAtLoad` requests a boot recovery pass, and
`KeepAlive.PathState` watches all three durable recovery witnesses:

- `/var/db/lidless/override-active`;
- `/var/db/lidless/mutation-in-flight.json`;
- `/var/db/lidless/scheduled-wake-recovery-required.json`.

Actual callback timing, process relaunch, boot execution, and forced-kill
escalation remain live gates.

### Durable mutation marker

Before a privileged child command can create an uncertain late outcome, the
helper persists and synchronizes a root-owned marker. Marker v2 records the
boot-session UUID. A child from the same boot may have survived and been
reparented, so process restart alone cannot clear the obligation. A changed
boot session proves the old child cannot still complete, after which fresh
readback can reconcile it. Missing boot identity and legacy v1 evidence fail
closed for new mutation authority.

### Termination

SIGTERM and SIGINT latch termination on the serial state queue. Risk-increasing
work is refused, restoration remains available, and the helper voluntarily
exits only when no helper-owned recovery remains. A no-record exit does not
prove the external sleep state. The OS may still force-kill a blocked process;
that is why durable markers and launchd are independent layers.

## App-side recovery coordination

The app never automatically re-arms after proof is lost. Established sessions,
failed arms with ambiguous outcomes, outside overrides, cutoffs, quit, launch
reconciliation, and sleep transitions each retain an explicit generation or
pending restore until fresh proof resolves them.

The restore monitor checks its generation before and after every suspension
and remote call. The absence of a monitor task is not a fence: an explicit
manual-recovery latch prevents a later retry from redispatching against an
incompatible wire. The sleep-transition fence has no restore generation, so it
is keyed on the sleep generation instead; every new transition advances that
generation. Force-sleep follow-ups are separately gated and cannot borrow the
main restoration proof.

Every status ingress demotes stale authority before it can be consumed,
including a refresh the client classifies itself. Cached wake confirmation is
invalidated when the helper ceases to be exact-current. The helper's initial
not-yet-classified state is distinct from that verdict: `.checking` means a
refresh has not completed, while `.unknown` is a concluded fail-closed result.
Only explicit `.notRegistered` may be shown as safely uninstalled after a
registration attempt; `.notFound` and other ambiguous classifications remain
unknown.

## Scheduled-wake transaction

RTC wake programming has two durable records with separate jobs:

- `scheduled-wake-recovery-required.json` is synchronized before the first
  pending ledger write and tells launchd that reconciliation is required;
- `scheduled-wake.json` records each exact rendered event and its phase:
  pending schedule, scheduled, or pending cancellation.

The helper's parser accepts only a recognized `pmset -g sched` structure and
throws on malformed or ambiguous candidate lines. It preserves duplicate exact
events. Parser silence is therefore never manufactured absence.

Before scheduling, the ledger persists intent. Success is committed only after
exact readback; that single ledger transition also turns every prior committed
event into a cancellation obligation. A cancellation obligation is removed
only after exact absence proof. A pending schedule observed after a crash is
cancelled, not promoted. Duplicate committed observations also become
cancellation work. Launch and each periodic tick perform at most one recovery
action, while a client transaction is bounded to 64 actions. Any ambiguous
ledger write invalidates in-memory truth and requires a trusted reload.

## Helper admission and stale revisions

The helper validates its own signed identity and applies a same-team,
Apple-anchored code-signing requirement to peers. Ad-hoc or identifier-only
trust fails closed. Payloads are Codable JSON over `Data`; malformed input
returns an error rather than crashing the daemon.

Protocol v6 plus exact safety revision 8 is required for risk-increasing work,
one-source status proof, ownership, and scheduled-wake authority. Revision
metadata is a compatibility claim, not cryptographic attestation of installed
bytes. A v6 responder with a different revision may participate only in the
narrow two-source normal-sleep recovery boundary. A different wire version
cannot.

All stale revisions are terminal in the UI. Automatic replacement and helper
cleanup are disabled. The public app and client cleanup entry points are
immediate, side-effect-free refusals, and compatibility XPC cleanup selectors
return `ok: false` without mutation. The helper must stay registered so its
launchd recovery supervision is not removed from an unresolved machine. The
manual command `sudo pmset -a disablesleep 0` is emergency normal-sleep
recovery only; it does not cancel wakes, restore optional settings, delete
helper data, or deregister the service. Removal requires a separately reviewed,
signed-runtime procedure.

## Persistence truth

Configuration and session stores return explicit load/save results; failures
are surfaced rather than silently replaced with apparent success. Session load
and save outcomes remain independent, so a later successful write cannot hide
an unresolved load failure or its active admission fence. An active session
journal is written before the UI claims an established session. The
in-memory witness mirrors that journal, and manual, preset, and scheduled arm
admission stays fenced while a prior journal, launch reconciliation, or store
failure remains unresolved. On launch, an orphan journal is retained while
helper reconciliation decides the truthful end reason. History is written
before that journal is deleted; a failed archival retains the selected reason
and retries idempotently before schedule automation. Widget snapshots are
timestamped and stale-aware.

Simulation uses the production decision and presentation paths with simulated
monitors and helper behavior. Its stores are ephemeral and it never performs a
privileged mutation. A checked-in repository-local harness compiles the final
app sources with the shipping entry point excluded, selects screenshot
simulation, and renders explicit unknown, error, refusal, recovery, size, pane,
and onboarding scenarios. Separate checked-in widget and icon renderers finish
the matrix before contact sheets are generated. The complete artifact set is
hash-stable across repeated runs without treating simulation as runtime proof.

## Build and release boundary

`project.yml` is the XcodeGen authority; the generated project is committed.
The Core package is deterministic and locally testable without signing.
Release automation builds both Debug and Release unsigned, runs static
analysis, verifies XcodeGen drift, checks least-privilege CI settings, and
requires both arm64 and x86_64 slices for each release executable before code
identity validation.

An unsigned build is compile evidence only. A distributable candidate still
requires one real Apple team across app, widget, helper, and app group, then
signed XPC validation, helper approval, real launchd/`pmset`/sleep/reboot tests,
WidgetKit and deep-link checks, accessibility input testing, notarization,
stapling, and the credentialed release gate. None of those externally mutating
steps are implied by this local release candidate.

## Project map

```
Packages/LidlessCore/   policy, models, parsers, source contracts, tests
App/Sources/            app state, monitors, persistence, SwiftUI
Helper/                 root daemon, bounded pmset adapter, launchd plist
Widget/                 read-only WidgetKit projection
Scripts/                icon, screenshots, release verification
Docs/                   rendered evidence, decisions, plans, handoff
project.yml             generated-project authority
```
