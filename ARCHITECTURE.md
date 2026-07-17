# Lidless Architecture

The problem shapes the design: keeping a closed MacBook awake requires the
root-only, system-wide `pmset disablesleep 1`, and the unforgivable failure
mode is *leaving it set*. So Lidless is built as a small trusted actuator
wrapped in redundant supervision, driven by a completely unprivileged brain.

```
┌───────────────────────────────────────────────┐
│ Lidless.app (menu bar, no privileges)         │
│  Monitors: IOKit battery events · pmset therm │
│  polls · ProcessInfo thermal · lid & override │
│  readback (IORegistry) · NSWorkspace wake     │
│  Brain:    AppState (state machine)           │
│            LidlessCore (pure decisions)       │
│  UI:       MenuBarExtra panel · main window · │
│            widget (app-group mirror)          │
└──────────────┬────────────────────────────────┘
               │ XPC (mach service, peer code-sign requirement)
               │ arm / heartbeat(10s) / disarm / repair / wake / uninstall
┌──────────────▼────────────────────────────────┐
│ LidlessHelper (root launchd daemon, ~700 LOC) │
│  pmset disablesleep|sleepnow|lpm|tcpkeepalive │
│  + IORegistry readback verification           │
│  Safety: sentinel file · watchdog(45s) ·      │
│  connection supervision · boot/crash recovery │
└───────────────────────────────────────────────┘
```

## Layering

**`Packages/LidlessCore`** — pure Swift, Foundation+IOKit only, no side
effects. `CutoffEngine` (arm assessment, planned cutoffs, per-tick
evaluation), `ScheduleEngine` (recurring windows, midnight wrap, DST-safe),
`DrainEstimator` (least-squares %/hr over the trailing discharge run),
`PMSetParser` (every piece of pmset text parsing in one tested module), the
XPC payload types, and the sentinel model. 151 deterministic tests; the
policies that decide when your battery stops draining are never buried in UI
code.

**The app** owns all policy *state*: the session lifecycle, thermal strike
counting, schedule automation, history recording, and every projection shown
in UI. Battery state arrives via `IOPSNotificationCreateRunLoopSource`
(events, not polling); thermals via a 90 s `pmset -g therm` poll fused with
`ProcessInfo.thermalState` change notifications; lid state and the *actual*
override value via IORegistry reads on a 15 s tick. The app never assumes an
operation worked — the menu bar indicator is driven by reading
`IOPMrootDomain.SleepDisabled` back, which is also what makes an override
left behind by *any other tool* visible (with a one-click repair).

**The helper** makes no decisions. It clamps its inputs (watchdog TTL is
15–120 s no matter what the app asks), verifies every mutation by reading the
registry back, and treats "restore normal sleep" as the terminal state it
always falls back to.

## The safety invariant

> The sleep override must never outlive supervision.

Mechanisms, layered so no single failure strands the override:

1. **Sentinel-first ordering.** `/var/db/lidless/override-active` is written
   (0600, root) *before* `disablesleep 1` runs and removed only *after* a
   verified restore. It records the prior values of `disablesleep`, the
   LPM key (`lowpowermode`/`powermode` — differs across macOS releases), and
   `tcpkeepalive`, so restore is non-destructive and needs no other state.
2. **Connection supervision.** The helper tracks the arming connection's
   identity; XPC invalidation (app quit or crash) restores immediately.
3. **Watchdog.** The app heartbeats every 10 s; the helper restores if no
   beat arrives within the TTL (45 s), with a 30 s grace period after system
   wake so a just-woken app isn't raced.
4. **launchd as the last supervisor.** `KeepAlive.PathState` on the sentinel
   relaunches a crashed helper *while the override is active*; `RunAtLoad`
   runs a restore pass at boot. Every helper launch begins: "sentinel exists
   → restore, then serve." A corrupt sentinel restores to safe defaults
   (`disablesleep 0`).
5. **Forced-sleep detection.** `disablesleep` makes ordinary sleep
   impossible, so a `kIOMessageSystemWillSleep` while armed means the user
   forced it — the helper releases the override on the way down so the Mac
   *stays* asleep.
6. **Restore failure never gives up.** If `pmset` errors, the sentinel stays,
   the state machine parks in `restorePending`, and the tick retries every
   30 s (launchd keeps the process alive because the sentinel exists).
   Arming is refused while a restore is pending.
7. **SIGTERM** (system shutdown, unregistration) restores before exit.

The app side mirrors this: quitting while armed asks ("Disarm & Quit"), the
session journal (`current-session.json`) folds crashed sessions into history
on next launch, and launch reconciliation disarms an orphaned helper session
if the app comes back before the watchdog fires. If the helper restarts
mid-session, the app's interruption handler re-arms within seconds and the
blip is logged on both sides; if re-arm fails, the session ends loudly.

## XPC hardening

The helper accepts a connection only if the peer satisfies a code-signing
requirement applied with `NSXPCConnection.setCodeSigningRequirement`:
`anchor apple generic and identifier "com.lidless.app" and certificate
leaf[subject.OU] = "<team>"`, where `<team>` is read from the helper's *own*
signing info at runtime — no hardcoded team, and app & helper are always
signed together. Ad-hoc dev builds (no team) fall back to an identifier-only
requirement and log that loudly. Payloads are Codable JSON over `Data` (one
encoding for XPC, sentinel, and logs); malformed input produces an error
reply, never a crash. Every reply carries a fresh `HelperStatus` including
the *read-back* override value.

## The arming flow (exact)

1. **Intent.** Power button in the menu panel (or a preset chip / schedule
   window / `lidless://` URL). If the helper isn't ready, the panel routes to
   Setup instead — arming is impossible until the one-time authorization is
   done.
2. **Assessment** (`CutoffEngine.assessArm`): on AC → ok (floor applies later
   if unplugged); discharging at ≤ floor + 2 % → **refused**, with the reason
   shown; discharging below 30 % → allowed with an explicit warning.
3. **Confirmation card** (always for the master button; presets skip it only
   when there's nothing to warn about): projected runtime to empty at the
   current drain rate, the floor with its projected wall-clock time, the
   first time-based cutoff, and the full cutoff summary. Low-battery arms
   are visually orange; refusals disable the button and say why.
4. **Actuation.** `arm(options)` → helper captures priors → writes sentinel →
   `disablesleep 1` → verifies via registry read-back (reverting on
   mismatch) → best-effort LPM/tcpkeepalive. Only then does the app create
   the session record, start the 10 s heartbeat and 5-minute battery
   sampling, post the arm notification, and spring the UI into the armed
   state. Any failure lands back in `disarmed` with the error surfaced.
5. **While armed**, a 15 s tick evaluates the engine against live inputs.
   Thermal violations debounce (2 consecutive readings, ≥ 30 s apart);
   plugging in suspends the floor; config edits apply live. Pre-cutoff
   warnings post at T-5 minutes and at floor + 3 %.
6. **Cutoff:** restore normal sleep → notification + chime → `pmset sleepnow`
   after a 3 s grace, *only if the lid is closed*. The session is finalized
   with its reason and battery curve; the next panel open shows the recap.

## Dry-run mode

`--simulate` swaps the three integration points (battery monitor, thermal
monitor, helper) for simulated implementations behind the same protocols —
everything else, from the arming card to notifications to session history,
is the production code path. The Simulator pane drives charge level, drain
rate, AC/charging, thermal signals, and lid state; a time-scale slider runs
overnight scenarios in seconds. README screenshots are rendered from this
mode (`--render-screenshots`), so the docs can never drift from the real UI.

## Project layout

```
Packages/LidlessCore/    pure logic + 151 tests (swift test)
App/Sources/             AppState, monitors, HelperClient, services, SwiftUI
Helper/                  daemon (PMSet, HelperDaemon, launchd plist)
Widget/                  WidgetKit mirror of the published snapshot
project.yml              xcodegen definition (xcodeproj is generated + committed)
Scripts/                 icon renderer, release pipeline
```
