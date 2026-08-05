# Lidless Safety Repair Status — 2026-08-05

State: IN_PROGRESS
Branch: codex/lidless-safety-repair-2026-08-04
Starting HEAD: 7f17aaca11bc6228bed48b9265d63b9e576cdea7

This ledger covers only the isolated linked worktree at
`/Users/junaid/Xcode-Projects/Lidless-worktrees/codex-safety-repair-2026-08-04`.
It does not authorize installation, launch, live helper actions, sleep-setting
changes, signed-runtime claims, network publication, or changes to the main
checkout.

## Resolved restart-inventory clarification

The resumed worker conservatively stopped before package review because this
required ledger was not present in the supplied pre-ledger manifest. The
coordinator has resolved that self-referential bookkeeping mismatch without
waiving any preserved-package check:

- Expected dirty inventory: 22 modified tracked files and 5 untracked files.
- Observed dirty inventory before this invocation's first edit: 22 modified
  tracked files and 6 untracked files.
- Additional bookkeeping path: `?? Docs/orchestration/LIDLESS-SAFETY-REPAIR-STATUS-2026-08-05.md`.
- The extra file was not present in the manifest. Before this update it had mode
  `0644`, 5,903 bytes, and raw SHA-256
  `3b9a0bdf16c547649c4bbcf77d4c70d78cbede2dd4be676ad4f3f4aea8eae43a`.
- All 27 paths that are present in the manifest independently matched their
  expected status, mode, byte count, and raw SHA-256. The tracked binary diff
  SHA-256 also remained the expected
  `585692490de6c54d8a5c37e969ede7f2b185fa198ca0a3b7843695caaec462b0`.

This ledger was created only after the original recovery audit passed, as
recorded by E-001 through E-003. It is therefore excluded from the immutable
27-file package-manifest comparison on restart. All 27 supplied entries and the
tracked binary diff must still match exactly, and any other extra, missing, or
changed path remains a hard stop. Work may resume from `State: IN_PROGRESS`.

## Recovery audit

| Check | Expected | Independently observed | Verdict |
|---|---|---|---|
| Canonical handoff SHA-256 | `95bdacdde663c642c2f97d532c1ec2b931e94a7dfcda47b8031e011ab3944831` | Exact match | PASS |
| State manifest SHA-256 | `d84065171a261e24ae574b98164132472ff1e8bb635647403d814b9fcf58c36a` | Exact match | PASS |
| Worktree path | Exact isolated path above | Exact match from `pwd -P` and `git rev-parse --show-toplevel` | PASS |
| Linked-worktree registration | Registered under the Lidless common Git directory | Main checkout plus this linked worktree; no lock/prunable marker | PASS |
| Branch | `codex/lidless-safety-repair-2026-08-04` | Exact match | PASS |
| HEAD | `7f17aaca11bc6228bed48b9265d63b9e576cdea7` | Exact match | PASS |
| Git directory | Linked-worktree admin directory | `/Users/junaid/Xcode-Projects/Lidless/.git/worktrees/codex-safety-repair-2026-08-04` | PASS |
| Git common directory | Main repository Git directory | `/Users/junaid/Xcode-Projects/Lidless/.git` | PASS |
| Modified tracked files | 22 | 22 | PASS |
| Untracked files | 5 | 5 | PASS |
| Manifest file records | All status/mode/size/hash values exact | 27 of 27 exact; zero extra or missing dirty paths | PASS |
| Tracked binary diff SHA-256 | `585692490de6c54d8a5c37e969ede7f2b185fa198ca0a3b7843695caaec462b0` | Exact match from `git diff --binary HEAD` | PASS |
| Main checkout baseline | Untouched | `main` at starting HEAD; no tracked diff; only three pre-existing untracked `.playwright-mcp/` files | PASS |

### Main-checkout preservation baseline

- Branch/HEAD: `main` / `7f17aaca11bc6228bed48b9265d63b9e576cdea7`
- Tracked binary diff SHA-256: `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`
- Untracked path-list SHA-256: `1ddc7b8fe0b0232cf68c470366a1eb1eeac1e5fd8e764e0f814eecf61e9e290a`
- `.playwright-mcp/console-2026-07-18T10-52-11-213Z.log`: mode `0644`, 340 bytes, SHA-256 `2d980ec1d2140e73f18450a9ad648d243f323a2c6d31d6454a6b63958951d369`
- `.playwright-mcp/page-2026-07-18T21-23-11-623Z.png`: mode `0644`, 6,051 bytes, SHA-256 `3be867fea8dfcbe878ac947a9ad09210b25f44db5ad0936dea75b458394261df`
- `.playwright-mcp/page-2026-07-18T21-24-01-631Z.png`: mode `0644`, 252,160 bytes, SHA-256 `5601fb55bae5ae4218a8c6da6ef732609e11b530ed2c288a911c438f35d71fb7`

## Finding and verification matrix

| ID | Safety claim or surface | Code trace | Regression evidence | Build/static/artifact evidence | Status |
|---|---|---|---|---|---|
| S-01 | Fresh arm requires readable proof of normal sleep before mutation | `HelperDaemon.handleArm` checks the registry, then can block in `readCustom` before mutation; the check and mutation are not atomic | Tri-state policy tests pass, but no integration regression closes the time-of-check/time-of-use window | Manual helper compilation only | PARTIAL — REPAIR REQUIRED |
| S-02 | Arm and restore require exact readback; unknown never succeeds | Exact checks exist in `SleepOverrideSafety`, arm readback, restore readback, and app completion gates | Focused policy tests pass | Manual helper compilation only; no live registry proof | PARTIAL — LIVE/FAULT GATES OPEN |
| S-03 | Sentinel/recovery state survives and retries unverified restoration | Fresh-arm sentinel precedes mutation, but blocking optional mutations delay in-memory watchdog/connection supervision; re-arm and heartbeat suppress sentinel-write errors | No daemon fault-injection regression | Manual helper compilation only | CONFIRMED DEFECT |
| S-04 | App terminal actions wait for proven restoration | `beginRestore` and its monitor retain pending state until v5 proof | Core proof-policy tests pass | Stale-helper path remains contradictory | PARTIAL — STALE PATH DEFECT |
| S-05 | Manual disarm, cutoff, quit, restart, wake, and orphan recovery share pending-restore semantics | Several paths use `beginRestore`; wake/orphan polling suppresses status errors and does not establish a terminal result | No complete transition-table regression | Not runtime tested | CONFIRMED DEFECT |
| S-06 | Heartbeats require a proven armed status | Successful replies use `isArmProven`, but transport errors are ignored indefinitely in the loop | Policy proof test only; no repeated-error regression | Not runtime tested | CONFIRMED DEFECT |
| S-07 | Stale helper versions cannot arm but remain usable for recovery | Client labels every version `>= 5` ready; v4 lacks proof fields required by restore completion and can carry legacy `priorSleepDisabled = true` | v5 missing-field fail-closed tests pass, exposing rather than solving v4 recovery | No compatible v4 recovery artifact | CONFIRMED DEFECT |
| S-08 | Unknown registry state stays unknown in app and widget | IPC/widget types carry verification state, but app presentation and some uninstall/wake branches do not preserve unknown uniformly | Core encoding/proof tests pass | UI/runtime not exercised | CONFIRMED DEFECT |
| S-09 | XPC peer trust fails closed without signed same-team identity | Startup provider validates Apple anchor + helper identifier before reading signing info, validates again with the candidate team, caches the peer requirement, and rejects all peers on failure | RED: missing ordered seam failed compilation; GREEN: 8 XPC tests prove check → extract → candidate-bound check plus failure ordering | Debug/Release helper compile with Swift 6 strict concurrency and warnings-as-errors; signed runtime remains prohibited/unverified | CHECKPOINT VERIFIED OFFLINE |
| S-10 | Protocol/build/signing/release configuration reflects v5 and does not present ad-hoc trust as proof | Source/project identifiers align, but release verification accepts ad-hoc nested code and does not assert same-team identities/entitlements; documentation overclaims remain | No release-policy regression | Plists/pbxproj lint; full graph could not resolve under nested sandbox | CONFIRMED DEFECT |
| V-01 | Complete core suite | N/A | Full dirty source tree: 169 tests in 7 suites passed; isolated staged checkpoint: 159 tests in 6 suites passed | Complete outputs preserved | PASS |
| V-02 | Unsigned Debug and Release full-graph builds | N/A | N/A | Both Xcode configurations were attempted with signing disabled but package resolution is blocked by the managed outer sandbox; isolated staged Debug/Release core and helper compilation passed separately | PARTIAL — ENVIRONMENT BLOCKED |
| V-03 | Static analysis without live activation | N/A | N/A | Swift 6 strict-concurrency helper compilation with warnings-as-errors passed; Xcode analysis is blocked before graph resolution | PARTIAL |
| V-04 | Built bundle, plist, configuration, and entitlement claims | N/A | N/A | All source plist/entitlement files and `project.pbxproj` lint; no complete built bundle exists to inspect | PARTIAL — BUILD BLOCKED |
| V-05 | Main checkout remains unchanged | Baseline recorded above | N/A | Post-checkpoint branch/HEAD, empty tracked diff, NUL path-list hash, and all three artifact hashes exactly match the baseline | PASS |

## Confirmed findings and first-checkpoint ruling

- **F-001 — Critical trust-anchor provenance defect, repaired in the first
  checkpoint.** The preserved helper read `kSecCodeInfoTeamIdentifier` from
  `SecCodeCopySigningInformation` without first calling
  `SecCodeCheckValidity`. The local Security SDK says corrupt signing data can
  return partial information and requires a successful validity check first.
  This was not by itself an unconditional XPC bypass: abuse would additionally
  require influence over the helper's signing source and a usable signing
  identity. The focused repair checks the dynamic helper against its Apple
  anchor and identifier before extraction, rechecks it against the extracted
  candidate team, and exposes no public raw-team provider.
- **F-002 — High helper supervision timing defect, open.** A fresh arm can
  spend up to 20 seconds reading custom settings before mutation and up to two
  further 20-second optional mutations after `disablesleep 1`; the in-memory
  watchdog and connection owner are installed only afterward. This can exceed
  the 15-second minimum TTL while the serial supervision queue is blocked. The
  preflight/mutation interval also admits a time-of-check/time-of-use race.
- **F-003 — High stale-v4 recovery defect, open.** Missing v5 proof fields are
  correctly rejected as proof, but that makes the advertised v4 recovery path
  unable to complete. A legacy sentinel can also encode
  `priorSleepDisabled = true`; the v4 helper can restore that value and remove
  its sentinel while the override remains active.
- **F-004 — High heartbeat/reconciliation defect, open.** Repeated heartbeat
  transport errors are ignored on the assumption that an interruption callback
  will arrive. Wake and orphan reconciliation similarly suppress some status
  errors, leaving no bounded escalation path when callbacks or reads fail.
- **F-005 — High release-verification gap, open.** `codesign --verify` alone
  does not prove the helper/app/widget share the intended non-ad-hoc team. The
  release script does not assert helper identifier, nested TeamIdentifier
  equality, hardened-runtime flags, or the expected app/widget entitlements.
- **F-006 — Medium configuration/documentation contradictions, open.** The
  committed project uses automatic signing with a fixed team while the README
  describes an account-free local flow; release/notarization language and test
  counts outside the corrected architecture section remain overstated or stale.

The preserved 27-file package is therefore not coherent enough to accept as a
single commit. Per the first-invocation contract, only F-001 is eligible for the
first coherent checkpoint. Every other preserved change remains unstaged for a
later root-cause checkpoint, and the ledger remains `State: IN_PROGRESS`.

## Remaining non-offline gates

The following cannot be proven by this package and remain explicitly unverified:
real signed app-to-helper trust, SMAppService registration/approval, real
arm/restore, sleep/wake, crash recovery, helper restart, uninstall recovery,
closed-lid hardware behavior, notarization, and release readiness.

## Append-only evidence log

- E-001 — 2026-08-05T11:40:53+0200 — Read all required handoff and repository documents in full. Their supplied hashes matched. Recursive repository scan found no `AGENTS.md`, `CLAUDE.md`, or equivalent agent instruction file.
- E-002 — 2026-08-05T11:40:53+0200 — Recovery gate passed before the first edit: topology/branch/HEAD/common-dir matched; all 27 manifest entries matched status, mode, byte count, and SHA-256; inventory was exactly 22 modified tracked plus 5 untracked; tracked binary diff SHA-256 matched; there were no extra or missing dirty paths.
- E-003 — 2026-08-05T11:40:53+0200 — Recorded the main-checkout preservation baseline without editing it. Main had no tracked diff and only its three pre-existing untracked `.playwright-mcp/` artifacts listed above.
- E-004 — 2026-08-05T11:49:59+0200 — A resumed, read-only recovery audit observed 22 modified tracked files and 6 untracked files, not the required 22 and 5. The sole extra dirty path was this ledger itself, absent from the supplied manifest; its pre-update mode, byte count, and raw SHA-256 are recorded in the blocking section above.
- E-005 — 2026-08-05T11:49:59+0200 — Independently rechecked every supplied manifest entry: 27 of 27 matched status, mode, byte count, and raw SHA-256. Worktree path, linked registration, branch, HEAD, common Git directory, tracked-file count, and tracked binary diff hash also matched. This does not override the extra-path mismatch.
- E-006 — 2026-08-05T11:49:59+0200 — One attempted read-only manifest loop was invalid because a zsh special variable shadowed the command path; it changed no files and its output was discarded. The corrected independent loop produced E-005. Per the recovery gate, state was set to `BLOCKED` and no package/test/build/commit work continued.
- E-007 — 2026-08-05T11:50:48+0200 — Final read-only preservation check: the main checkout remained on `main` at `7f17aaca11bc6228bed48b9265d63b9e576cdea7`, its tracked diff remained empty, and its same three untracked `.playwright-mcp/` files independently matched the previously recorded modes, byte counts, and raw SHA-256 values. The main checkout was not edited.
- E-008 — 2026-08-05T11:53:00+0200 — Coordinator resolved the restart-only inventory ambiguity: this required ledger is post-gate bookkeeping created after E-002 and is the sole permitted path excluded from the original 27-file manifest comparison. State returned to IN_PROGRESS. No preserved package byte, Lidless product source, main-checkout file, runtime, helper, or system setting was changed by this ruling.
- E-009 — 2026-08-05T11:56:00+0200 — Fresh restart audit read the canonical handoff, manifest, progress log, decision log, architecture, design-reset brief, and CONTRIBUTING guidance in full. The two supplied artifact SHA-256 values matched exactly; no `AGENTS.md`, `CLAUDE.md`, or equivalent agent-specific instruction file exists in the repository.
- E-010 — 2026-08-05T11:56:00+0200 — Fresh restart recovery gate passed under the explicit ledger exception: worktree path, linked registration, branch, starting HEAD, Git directory, and common directory matched; all 27 manifest entries independently matched status, mode, byte count, and raw SHA-256; the preserved package remained exactly 22 modified tracked plus 5 manifest-untracked paths after excluding only this ledger; the tracked binary diff SHA-256 was exactly `585692490de6c54d8a5c37e969ede7f2b185fa198ca0a3b7843695caaec462b0`.
- E-011 — 2026-08-05T11:56:00+0200 — One preliminary read-only verifier loop shadowed zsh's special `path` parameter after its first entry, so its apparent mismatch output was invalid and discarded; it changed no files. A corrected loop using a non-special variable then produced the exact 27-of-27 result recorded in E-010. The main checkout remained on `main` at the starting HEAD with no tracked changes and only its pre-existing `.playwright-mcp/` directory untracked.
- E-012 — 2026-08-05T12:05:00+0200 — Reviewed the complete preserved diff against starting HEAD and traced the claimed safety surfaces through helper, app, shared policy, tests, build configuration, release script, and documentation. Independent adversarial reviews agreed the package is not coherent wholesale; F-002 through F-006 remain open and only the XPC trust-anchor provenance repair is scoped to the first checkpoint.
- E-013 — 2026-08-05T12:06:00+0200 — Reproduced the pre-checkpoint core baseline: the complete suite passed 164 tests in 7 suites. Focused pre-repair safety runs also passed, showing that the preserved tests did not detect the XPC signing-information validity flaw. Complete output is archived under the ignored `build/verification-2026-08-05/` directory.
- E-014 — 2026-08-05T12:08:00+0200 — Confirmed F-001 against the installed macOS SDK header. `SecCode.h` lines 217–238 describe dynamic validity and filesystem-source protection; lines 332–353 warn that signing information may be invalid/partial and require successful validity checking first. The exact excerpt is preserved in `security-seccode-validity-contract.log`.
- E-015 — 2026-08-05T12:15:00+0200 — Added the adversarial ordered-pipeline regression first. One initial RED invocation stopped at a sandboxed module-cache path and supplied no code verdict; it changed no product source. The corrected RED run, with caches redirected inside this worktree and SwiftPM's nested sandbox disabled, failed compilation exactly because `XPCPeerPolicy.validatedRequirement` did not exist. Output is preserved in `swift-test-xpc-pipeline-red-compile.log`.
- E-016 — 2026-08-05T12:16:00+0200 — Implemented the minimal internal ordering seam and production Security closures. Focused GREEN passed 8 tests in the XPC suite, including base-check failure preventing extraction, candidate-bound failure rejection, missing/invalid team rejection, and successful base-check → extraction → bound-check ordering. The public provider fails closed for this unsigned test process.
- E-017 — 2026-08-05T12:17:00+0200 — Final source-tree core verification passed 169 tests in 7 suites. A Release `LidlessCore` build also passed. Complete outputs are preserved in `swift-test-full-checkpoint-final.log` and `swift-build-core-release-checkpoint-final.log`.
- E-018 — 2026-08-05T12:18:00+0200 — Manually compiled the complete helper source in Debug and Release against the corresponding final core products using Swift 6 complete strict concurrency and warnings-as-errors; both passed with no diagnostic. These are compile-only unsigned artifacts and do not prove signed XPC trust or live helper behavior.
- E-019 — 2026-08-05T12:18:00+0200 — Full unsigned Xcode Debug and Release builds were attempted with `CODE_SIGNING_ALLOWED=NO`. Initial attempts could not write user caches; redirected attempts reached SwiftPM's nested `sandbox-exec`, which the managed outer sandbox rejects with `sandbox_apply: Operation not permitted`. A Debug bypass attempt omitted package resolution, failed with missing `LidlessCore`, and Xcode automatically invoked LaunchServices registration for its temporary unsigned app before failing. Neither app nor helper was launched, and no helper install/activation/registration or system-setting mutation was performed. No further Xcode retry is justified in this environment.
- E-020 — 2026-08-05T12:18:00+0200 — `plutil -lint` passed for all source app/widget plist and entitlement files, the helper launchd plist, export options, and `project.pbxproj`. Static identifier inspection aligns `com.lidless.app`, `com.lidless.helper`, the Mach service, associated app identifier, and configured team; there is no complete built bundle to elevate those source/configuration observations into runtime proof.
- E-021 — 2026-08-05T12:18:00+0200 — Moved the exact two-file top-level `.build` directory created by an earlier build probe into ignored `build/verification-2026-08-05/root-dot-build-side-effect`. The preserved package inventory is again free of tool-created untracked paths; the two artifacts remain recoverable in the verification archive.
- E-022 — 2026-08-05T12:21:00+0200 — Independent review of the XPC-only checkpoint found no security blocker and confirmed candidate-bound, fail-closed ordering, internal raw builders, startup caching, and reject-all behavior on provider failure. It caught that 169 tests described the full dirty package, while the isolated checkpoint has 159; `ARCHITECTURE.md` was corrected to the scoped count. The reviewer also confirmed that positive signed Security-framework behavior is simulated and must remain a live external gate.
- E-023 — 2026-08-05T12:23:43+0200 — Reviewed and partially staged only F-001: the new XPC policy and 8 tests, helper import/startup/listener/old-provider hunks, the scoped architecture correction, and this ledger. `git diff --cached --check` passed. A fresh temporary `HEAD + staged binary diff` snapshot passed all 159 tests in 6 suites, a Release core build, and standalone Debug and optimized Release helper compiles with Swift 6 complete strict concurrency and warnings-as-errors. Every other preserved package change remains unstaged. No app/helper was launched and no live or signed-runtime claim is made.
- E-024 — 2026-08-05T12:25:00+0200 — Post-checkpoint preservation comparison passed: the main checkout remained on `main` at starting HEAD, its tracked binary diff remained empty, its NUL-delimited untracked path-list hash remained `1ddc7b8fe0b0232cf68c470366a1eb1eeac1e5fd8e764e0f814eecf61e9e290a`, and the modes, sizes, and hashes of all three pre-existing `.playwright-mcp/` artifacts exactly matched the baseline. The isolated feature worktree index was clean; its remaining 21 tracked modifications and 3 untracked paths are the intentionally unstaged remainder of the preserved package.
