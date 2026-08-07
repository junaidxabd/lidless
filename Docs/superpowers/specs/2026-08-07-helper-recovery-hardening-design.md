# Lidless Helper and Recovery Hardening Design

Date: 2026-08-07

Status: approved for autonomous implementation by the founder's completion-lane instruction.

## Objective

Close the locally verifiable safety gaps found after the revision-7 repair
without weakening the invariant:

> The sleep override must never outlive proven supervision.

The local candidate must fail closed when client compatibility, child-process
termination, persisted configuration, scheduled-wake bookkeeping, helper
removal, or state evidence is uncertain. Signed runtime, launchd, reboot,
notarization, and real-hardware behavior remain explicit external release gates.

## Threat and failure model

Protect against:

- an older genuine same-team Lidless app speaking to the current helper;
- a mutating `pmset` child surviving its timeout and completing late;
- a crash or filesystem fault at any scheduled-wake replacement boundary;
- malformed or extreme persisted cutoff values;
- critical thermal pressure hidden behind ordinary debounce;
- helper restart or a second genuine app during automatic removal;
- misleading recovery, optional-setting, quit, or persistence claims.

Root compromise is outside the boundary because root can invoke `pmset`
directly.

## Approaches considered

### 1. Patch each call site

Add guards and propagate current errors in place. This is the smallest diff,
but preserves source-string testing and makes cross-boundary crash states hard
to reason about.

### 2. Pure safety kernels plus narrow adapters — selected

Put compatibility, normalization, termination certainty, thermal urgency, and
scheduled-wake transaction decisions in small `LidlessCore` types with
executable deterministic tests. The app/helper remain I/O adapters. Source
tests assert only wiring that cannot yet run without signed ServiceManagement.

This closes the known local gaps while keeping privileged code reviewable and
avoiding a risky whole-daemon rewrite.

### 3. Full helper runtime inversion

Move the entire daemon behind injected filesystem, process, clock, registry,
XPC, and registration protocols with a new executable test target. This is the
right longer-term architecture for exhaustive crash exploration, but is too
broad to combine safely with the product rewrite in one release-candidate
branch. The selected approach creates seams that make this follow-up possible.

## 1. Current-client admission at the helper

Code-signing identity proves publisher and bundle identity, not behavioral
freshness. Every risk-increasing request must also carry exact current client
compatibility metadata.

Add `HelperClientIdentity` with `protocolVersion` and `safetyRevision`, plus an
exact `authorizesRiskIncreasingWork` policy. The current helper safety revision
advances. The wire protocol can remain compatible because new selectors and
optional JSON fields preserve structured responses to old clients.

- `HelperArmOptions` carries optional identity for decoding legacy requests;
  the helper rejects missing/mismatched identity before arm side effects.
- `HelperDisarmOptions` carries identity. Ordinary restoration remains allowed
  from compatible signed clients, but `forceSleep` requires exact current
  identity and the existing ownership/generation proof.
- A new structured scheduled-wake selector carries identity and desired date.
  The legacy scalar selector returns a structured refusal without mutation.
- A new cleanup-preparation selector carries identity. Legacy preparation and
  legacy uninstall return structured refusals without cleanup mutation.
- `ping`, heartbeat for an already exact-admitted owner, ordinary disarm, and
  override repair remain available for de-risking and observation.

Tests prove that missing, older, future, malformed, and exact identities have
the intended permissions; helper source wiring is checked at each mutation
boundary.

## 2. Unproven child termination

`PMSet.run` must distinguish:

- exited (including a nonzero exit);
- killed and exit observed;
- termination unproven.

An unproven mutating child yields a retained termination witness. The helper
records the witness, retains the sentinel, refuses new risk-increasing work,
and does not issue an ordering-dependent success or delete recovery evidence.
Restore retries wait until every witness proves the child is no longer running,
then perform and verify a fresh normal-sleep mutation. Voluntary helper exit and
cleanup remain blocked while a mutation witness is unresolved.

Pure policy tests cover every kill/reap combination. Adapter tests or source
wiring prove enable, restore, managed-setting, wake, and sleep mutations register
unproven witnesses. The critical regression is: enable times out, kill/reap is
unproven, an OFF read appears, the original child completes late—the sentinel
must still exist and a later verified restore must run.

## 3. Scheduled-wake transaction

Replace the single best-effort `StoredWake` with a versioned ledger containing
all known events and one of three phases:

- `pendingSchedule`
- `scheduled`
- `pendingCancel`

The ledger is persisted before every mutation. A success reply is allowed only
after the corresponding postcondition and final ledger state are both proven.

Replacement sequence:

1. Persist the new event as `pendingSchedule` beside the old committed event.
2. Program the new event.
3. Read scheduled events and prove the exact rendered event exists.
4. Persist the new event as `scheduled`.
5. Persist the old event as `pendingCancel`.
6. Cancel the old event.
7. Read scheduled events and prove the old event is absent.
8. Remove the old event from the ledger and persist the committed result.

On startup, pending schedule is conservatively cancelled, pending cancellation
is completed, and committed state is reconciled against read-only scheduled
event output. Corrupt or unreadable ledger state disables further wake mutation
and blocks cleanup success; it is never decoded as “no wake.”

All transition decisions and parser behavior live in `LidlessCore` with fault
tests for every write, mutation, verification, and crash boundary. No test
invokes real `pmset`.

## 4. Automatic helper removal

The current process-local removal fence cannot prove safety across helper
restart and deregistration awaits. Until a durable cross-process epoch can be
bound to ServiceManagement registration, the local candidate disables automatic
helper cleanup, replacement, and uninstall.

The helper refuses both legacy and current cleanup preparation without mutation.
The app presents a truthful reviewed-removal-required state, keeps the helper
registered, and provides only emergency normal-sleep recovery plus independent
verification. The Homebrew cask is removed from release-ready artifacts rather
than bypassing this boundary with `launchctl`.

This is a deliberate fail-closed product decision, not a claim that removal is
solved. A future lane may implement and live-validate a durable removal epoch.

## 5. Configuration normalization

`CutoffConfig.normalized()` clamps every persisted or overridden value:

- battery floor: 5...50 percent;
- thermal speed floor: 20...90 percent;
- thermal strikes: 1...5;
- duration: 30 minutes...24 hours;
- wall-clock hour: 0...23;
- wall-clock minute: 0...59.

Normalization occurs after decode, after session overrides, and inside the
pure cutoff engine before arithmetic or actuation decisions. Invalid JSON or a
failed read uses safe defaults and records a visible persistence warning.
Property tests cover integer and floating-point extremes, non-finite duration,
invalid time fields, and overflow-sensitive margins.

## 6. Critical thermal urgency

`ProcessThermalLevel.critical` fires an immediate thermal cutoff on the next
tick, independent of the ordinary strike count. Serious pressure and `pmset`
threshold violations retain the source-aware debounce. Admission still refuses
an already serious or critical arm.

Tests cover nominal→serious, repeated serious, nominal→critical, and critical
with missing/stale `pmset` evidence. Missing configured `pmset` evidence remains
a telemetry cutoff and never becomes nominal.

## 7. Optional managed settings

Requested Low Power Mode and network keep-alive are part of the arm contract,
not best-effort history decoration.

The helper applies and reads back the complete activation plan before returning
arm success. Any failure enters sentinel-backed restoration and the app does
not record a session. The minimum watchdog TTL is raised so the complete bounded
enable/apply/readback/restore path remains below the deadline. History can then
truthfully record the settings as verified applied.

## 8. Truthful persistence and recovery copy

- Config, session history, and crash-journal writes record visible errors
  instead of silently disappearing.
- An orphan session journal remains unresolved until helper reconciliation;
  it is not immediately labeled app quit and deleted.
- Unsupported-helper quit copy makes no promise about helper behavior after
  force quit.
- A post-cleanup registration change cannot be labeled “cleanup did not start.”
  With automatic cleanup disabled, this legacy branch remains only as preserved
  compatibility history and cannot be reached by the current app.
- Notifications say “keep-awake ends” unless an exact sleep request is both
  authorized and dispatched; they do not promise “sleeping soon” from a cutoff
  alone.

## 9. Build and release policy

- CI runs the core suite, Debug and Release unsigned compilation, static
  analysis, shell syntax, XcodeGen drift, and release-policy tests.
- The distribution verifier requires both `arm64` and `x86_64` for a universal
  distribution artifact.
- Placeholder hashes and unsafe cask uninstall claims cannot enter a release
  artifact.
- Local verification never invokes live `pmset`, helper installation,
  ServiceManagement removal, signing, notarization, or system-setting changes.

## External release gates

The following remain mandatory on a disposable VM or dedicated Mac with a real
signing team before public release:

- signed peer admission and exact-current client refusal matrix;
- helper activation and approval;
- arm/disarm, app kill, helper kill, hung child, SIGTERM, sleep/wake, reboot;
- scheduled wake creation/replacement/cancellation across crash points;
- widget app-group freshness;
- any future durable removal protocol;
- archive, Developer ID export, notarization, stapling, Gatekeeper, and hardware
  thermal/battery behavior.

Local completion must name these gates; it must not convert them into claims.
