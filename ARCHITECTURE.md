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

**`Packages/LidlessCore`** — shared Swift over the Foundation, IOKit, and
Security system frameworks; it performs no system mutations. `CutoffEngine`
(arm assessment, planned cutoffs, per-tick
evaluation), `ScheduleEngine` (recurring windows, midnight wrap, DST-safe),
`DrainEstimator` (least-squares %/hr over the trailing discharge run),
`PMSetParser` (every piece of pmset text parsing in one tested module),
`BatterySnapshotNormalizer` (typed, fail-closed power-source evidence), the
`ThermalEvidenceSafety` validator and source-aware strike tracker, the XPC
payload types, battery/thermal admission and cutoff policy, and the sentinel
model. Deterministic tests keep the policies that decide when a configured
safety guard can be enforced out of UI code.

**The app** owns all policy *state*: the session lifecycle, thermal strike
counting, schedule automation, history recording, and every projection shown
in UI. Battery state arrives via `IOPSNotificationCreateRunLoopSource`
(events, not polling); thermals via a 90 s `pmset -g therm` poll fused with
`ProcessInfo.thermalState` change notifications; lid state and the *actual*
override value via IORegistry reads on a 15 s tick. The app never assumes an
operation worked — the menu bar indicator is driven by reading
`IOPMrootDomain.SleepDisabled` back, which is also what makes an override
left behind by *any other tool* visible (with a one-click repair).
When a battery floor is enabled, unreadable or malformed battery evidence
refuses a new arm and sends an established session into the same
verified-restoration coordinator. Completion remains pending until the helper
reply and an independent registry read both prove normal sleep. Enumeration
absence alone is not accepted as hardware-absence proof. Only a fully
classified enumeration plus a readable root-domain topology showing no
clamshell produces the explicit no-battery state. When thermal protection is
enabled, the same admission/restoration rule applies to a missing, structurally
invalid, future-dated, or more than 180-second-old `pmset` sample. Recognized
malformed or contradictory fields invalidate the whole parsed sample instead
of retaining a convenient nominal subset. A serious or critical `ProcessInfo`
state remains an independent pressure signal, but cannot replace the `pmset`
evidence needed to enforce the configured warning/speed thresholds.

**The helper** makes no decisions. It clamps its inputs (watchdog TTL is
15–120 s no matter what the app asks), verifies every mutation by reading the
registry back, and treats "restore normal sleep" as the terminal state it
always falls back to.

## The safety invariant

> The sleep override must never outlive supervision.

Mechanisms, layered so no single failure strands the override:

1. **Sentinel-first ordering.** Before decoding disk recovery state or arming,
   the helper proves both `/var/db` and `/var/db/lidless` are exact root:wheel
   0755 directories with no ACL. Creation and open of `lidless` are relative
   to the proven parent descriptor; creation/open of `override-active` is
   relative to the proven child descriptor, exclusive, and no-follow. The
   helper proves a single-link root:wheel 0600 regular file with no ACL, writes
   the complete record, requires successful `F_FULLFSYNC` requests for the
   file and its directory entry, and checks mutation-bearing closes *before*
   `disablesleep 1` runs. It re-applies child/parent namespace barriers even
   when the directory already exists, closing the interrupted-creation retry
   gap. After a Lidless mutation, removal requires verified restoration, a
   full directory barrier, and a checked close; an unused prepared marker may
   instead be removed after a proven pre-mutation rejection. Invalid metadata
   or a partial/corrupt direct write is never decoded as trusted optional
   state; proof failure selects version-0 normal-sleep recovery and keeps
   recovery pending. These host requests fail closed, but offline tests cannot
   prove a particular physical device honors cache-flush requests under OS
   crash or power loss. Sentinel schema v2
   records the LPM key
   (`lowpowermode`/`powermode` — differs across macOS releases) and numeric
   LPM/`tcpkeepalive` priors only for the exact Battery/AC/UPS scopes Lidless
   mutates, plus a legacy `disablesleep` field, so recovery needs no app state.
   A schema-v1 sentinel with optional state cannot claim those scoped
   semantics and remains pending for explicit recovery; v1 without optional
   state can still restore normal sleep. Protocol v5 and later
   refuse to arm over a measured external override and always restore ordinary
   sleep (`disablesleep 0`). The disk record is immutable while active;
   heartbeat deadlines live only in queue-owned memory because
   filesystem latency is not bounded.
2. **Connection supervision.** The helper tracks the fresh arming connection's
   identity. A second arm is rejected while that session is active, only the
   exact owner connection may renew the watchdog, and owner XPC invalidation
   (app quit or crash) restores immediately. Other authenticated connections
   retain de-risking restore and repair access but cannot prolong the override.
3. **Watchdog.** The app heartbeats every 10 s; the helper restores if no
   beat arrives within the TTL (45 s), with a 30 s grace period after system
   wake so a just-woken app isn't raced.
4. **launchd configured as the last supervisor.** `KeepAlive.PathState` on the
   sentinel requests keep/relaunch while the override may be active;
   `RunAtLoad` requests a boot recovery pass. Every actual helper launch begins
   with trusted sentinel inspection (restoring when present) or untrusted
   fail-safe recovery before serving. A corrupt sentinel forces
   `disablesleep 0`, but its optional priors are
   unprovable: the helper marks recovery pending and retains corrupt evidence
   rather than claiming a complete restore. Actual launchd/crash behavior is a
   live gate.
5. **Forced-sleep detection.** `disablesleep` makes ordinary sleep
   impossible, so a `kIOMessageSystemWillSleep` while armed means the user
   forced it — the helper releases the override on the way down so the Mac
   *stays* asleep.
6. **Restore failure never gives up.** Normal sleep is proved first. Every
   recorded optional value is then restored through grouped per-scope
   commands and must match a fresh `pmset -g custom` readback before the
   sentinel can leave. A command error, invalid snapshot, missing/mismatched
   readback, or sentinel-deletion error parks in `restorePending`; the tick
   retries every 30 s while the process remains. A trusted on-disk marker
   configures `KeepAlive.PathState` to request relaunch. If storage itself is
   missing or invalid, the version-0 pending fallback can be memory-only; a
   simultaneous restore failure followed by forced process loss has no proven
   disk restart trigger and remains an explicit live fault gate. Arming is
   refused while a restore is pending.
7. **SIGTERM/SIGINT fail closed.** A signal latches termination and restores on
   the serial state queue. It voluntarily exits only after no helper-owned
   recovery remains; an owned sentinel or pending restore clears only after
   exact normal-sleep proof and sentinel deletion. A no-record exit does not
   prove the external sleep state. Failures retry on the next supervision tick;
   new arm, repair, all wake work, and delayed force-sleep work are refused,
   while ordinary restore stays available. The OS can
   still force-kill the process, so launchd escalation and shutdown timing
   remain live validation gates rather than offline guarantees.
8. **Bounded state-queue work while armed.** Each `pmset` child gets 3 s,
   followed by at most 1 s to observe forced termination. The critical
   enable/rollback interval is at most two calls; post-proof optional work is
   grouped into at most three power-scope calls, strictly below the 15 s
   minimum TTL. Once a restore starts executing, its at-most-five child calls
   (sleep restore, three scopes, custom readback) have a 20 s child-process
   bound. Prior queue occupancy — including post-reply optional activation —
   plus filesystem, process-launch, and IOKit work can still outlive the app's
   25 s local deadline; that timeout is outcome-unknown, not cancellation or
   restore proof. Wake scheduling is deferred while armed or recovering.

The helper rechecks the registry after the potentially unbounded initial
sentinel write and immediately before installing in-memory ownership and
running `pmset`. macOS exposes no atomic check-and-set ownership primitive for
this global Boolean, so a final cross-process registry-read-to-mutation race
remains an explicit external validation/design gate rather than a closed
offline claim.

The app side mirrors this: quitting while armed asks ("Disarm & Quit"), the
session journal (`current-session.json`) folds crashed sessions into history
on next launch, and launch reconciliation disarms an orphaned helper session
if the app comes back before the watchdog fires. A helper interruption or any
heartbeat that cannot prove the live override is terminal for the current
session: the app restores normal sleep and requires a fresh user/schedule arm.
It never automatically re-enables an override after proof has been lost. A
never-established arm request may end without mutation if the exact current
helper proves it owns no session or pending recovery while the app independently
sees an outside override. Once a Lidless session was established, that evidence
is causally ambiguous; recovery stays visible until normal sleep is proven.
Repairing an outside override is also generation-bound: the app records the
repair transition before its first XPC call and keeps the repair operation
selected whenever an attempt returns without complete proof. Completion still
requires the helper and a fresh, independent registry read to prove normal
sleep. A repair generation cannot inherit session-finalization,
outside-ownership, or force-sleep semantics. The generation is app-local and
cannot cancel a remotely delivered mutation. Every app-side XPC continuation
has a 25 s local deadline: reply, transport failure, and timeout race through
one exactly-once completion gate. A timeout retires the exact captured
connection and invalidates current helper proof. This bounds the local await;
it neither cancels an already delivered mutation nor proves its remote outcome.

## XPC hardening

The helper accepts a connection only if the peer satisfies a code-signing
requirement applied with `NSXPCConnection.setCodeSigningRequirement`:
`anchor apple generic and identifier "com.lidless.app" and certificate
leaf[subject.OU] = "<team>"`, where `<team>` is read from the helper's *own*
signing info once at startup, but only after the running helper dynamically
validates its Apple-anchored `com.lidless.helper` identity. There is no hardcoded
runtime team anchor; missing or invalid helper identity rejects every peer.
Ad-hoc helpers fail closed because an identifier-only requirement is locally
spoofable. Payloads are Codable JSON over `Data` (one
encoding for XPC, sentinel, and logs); malformed input produces an error
reply, never a crash. Every reply carries a fresh `HelperStatus` including
the *read-back* override value. Readiness and every app-side arm, restore,
outside-ownership, enabled-registration removal, and scheduled-wake acceptance
boundary require both protocol v6 and the exact safety behavior revision 6.
A missing, older, or future revision is stale and cannot supply proof. The
revision is self-reported compatibility metadata, not executable attestation
or an installation receipt; safely replacing an already registered stale
helper remains a separate deployment gate.

Enabled-helper cleanup has the same compatibility boundary on entry, not only
on its reply. The client asks the responder to prepare cleanup, requires the
exact protocol and safety revision in that non-cleanup reply, and rechecks that
launchd still classifies the service as enabled. Preparation also returns a
random authorization bound to that helper process lifetime. The receiving
daemon validates it before advancing lifecycle state, restoring settings,
cancelling wakes, or removing data. A commit delivered to a restarted or
replacement process therefore rejects before cleanup mutation. The legacy
unbound cleanup selector is fail-closed. The token does not bind a lingering
responder to the SMAppService registration that will later be unregistered, so
registration/executable identity and enabled-to-enabled registration ABA remain
open gates. This handshake is self-reported compatibility evidence, not
attestation of installed bytes or a receipt for the registered executable;
signed replacement and live ServiceManagement/XPC behavior remain separate
runtime gates.

Uninstall-time scheduled-wake cleanup is also fail-closed. After `pmset`
accepts cancellation, the daemon must remove the exact persisted wake record
before clearing its in-memory intent or attempting broader helper-data removal.
Exact-target absence is accepted; any other ledger-removal error retains any
known in-memory intent and returns failure, so the current client does not
authorize deregistration. The external `pmset` mutation and filesystem unlink
are not atomic: process death in that interval, external wake changes, and real
cancellation/readback behavior remain live recovery gates rather than closed
offline claims.

## The arming flow (exact)

1. **Intent.** Power button in the menu panel (or a preset chip / schedule
   window / `lidless://` URL). If the helper isn't ready, the panel routes to
   Setup instead — arming is impossible until the one-time authorization is
   done. Each pending intent has an unforgeable process-local identity and an
   immutable snapshot of its effective cutoffs and helper options; a scheduled
   intent additionally snapshots the exact active window occurrence. Manual,
   preset, and scheduled confirmation tasks carry that exact identity, so a
   queued task from a cancelled intent cannot confirm a later replacement. A
   changed warning, risk-relevant setting, disabled automation, or edited or
   expired schedule occurrence revokes the authorization. Drift before
   mutation requires fresh confirmation, and drift after a proven mutation
   enters verified restoration instead of accepting the session. Disabling
   automation also terminates an already accepted scheduled session through
   the normal verified-restoration path.
2. **Assessment** (`CutoffEngine.assessArm`): enabled thermal protection first
   requires a fresh, structurally meaningful `pmset` sample, and an enabled
   floor requires usable battery/source evidence; unavailable, structurally
   invalid, stale, or future-dated required evidence is **refused**. A fresh
   `pmset` threshold violation or serious/critical `ProcessInfo` pressure is also
   **refused**, so Lidless never knowingly arms hot. On AC with a valid battery
   → ok (floor applies later if unplugged); discharging at ≤ floor + 2 % →
   **refused**, with the reason shown; discharging below 30 % → allowed with an
   explicit warning. Dual source/topology evidence proving there is no internal
   battery is not telemetry failure; its configured floor is shown as inactive,
   and the battery-only “To 20%” preset is unavailable.
3. **Confirmation card** (always for the master button; presets skip it only
   when there's nothing to warn about): projected runtime to empty at the
   current drain rate, an applicable floor with its projected wall-clock time,
   the first time-based cutoff, and the enforceable cutoff summary. The card
   does not promise a floor when telemetry is unavailable or the machine has
   no internal battery. Low-battery arms are visually orange; refusals disable
   the button and say why. If topology later proves there is no internal
   battery, a pending “To 20%” card is withdrawn before it can arm.
4. **Actuation.** After re-proving helper eligibility, the app polls thermal
   evidence, re-reads the override registry and battery evidence, and repeats
   the assessment with no suspension before dispatch. `arm(options)` → helper
   captures optional priors → proves
   the override inactive → writes the sentinel → proves it inactive again →
   installs the connection owner and monotonic watchdog → runs
   `disablesleep 1` → verifies via registry read-back (restoring on mismatch)
   → replies with proof → performs best-effort LPM/`tcpkeepalive`, grouped only
   across scopes with captured numeric priors. A partial optional application
   does not revoke the already-proven sleep arm, but the sentinel retains every
   possibly touched prior and later restoration is strict. Only after the
   proven reply, the app synchronously re-reads battery evidence and revalidates
   the thermal sample. Only an accepted result—an unchanged assessment with
   every source-specific endpoint still attainable for manual/preset flows, or
   any arm-allowed assessment for a schedule flow—lets it create the session
   record, start the 10 s heartbeat and 5-minute battery sampling, post the arm
   notification, and spring the UI into the armed state. A result outside those
   rules instead starts verified restoration. Any failure before proof lands
   back in `disarmed` with the error surfaced.
5. **While armed**, a 15 s tick evaluates the engine against live inputs.
   Thermal violations require two strikes by default. No source can advance
   that debounce more than once per 45 seconds: `pmset` also requires a distinct
   violating sample, while sustained serious/critical `ProcessInfo` pressure
   advances independently after the same gate. A distinct `pmset` sample that
   arrives inside the gate remains eligible when the interval elapses.
   Missing, structurally invalid, future-dated, or more than 180-second-old
   required `pmset` evidence bypasses that debounce and initiates verified
   restoration.
   Plugging in suspends the floor, but loss of evidence for an enabled floor
   also initiates verified restoration; either path keeps the session pending
   until proof, and config edits apply live. Pre-cutoff warnings post at T-5
   minutes and at floor + 3 %. Before helper mutation, a scheduled occurrence
   retries after transient telemetry loss while a real floor refusal suppresses
   that occurrence. After a proven helper mutation, any post-proof safety
   assessment that is not accepted suppresses the occurrence before verified
   restoration to prevent arm/restore flapping.
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
Packages/LidlessCore/    pure logic + tests (swift test)
App/Sources/             AppState, monitors, HelperClient, services, SwiftUI
Helper/                  daemon (PMSet, HelperDaemon, launchd plist)
Widget/                  WidgetKit mirror of the published snapshot
project.yml              xcodegen definition (xcodeproj is generated + committed)
Scripts/                 icon renderer, release pipeline
```
