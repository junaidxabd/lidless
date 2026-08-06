# Lidless Safety Repair Status — 2026-08-05

State: IN_PROGRESS
Branch: codex/lidless-safety-repair-2026-08-04
Starting HEAD: 7f17aaca11bc6228bed48b9265d63b9e576cdea7

This ledger covers only the isolated linked worktree at
`/Users/junaid/Xcode-Projects/Lidless-worktrees/codex-safety-repair-2026-08-04`.
It does not authorize installation, launch, live helper actions, sleep-setting
changes, signed-runtime claims, network publication, or changes to the main
checkout.

## Recovery gate mismatch — 2026-08-05T12:28:24+0200

This invocation stopped before package review, tests, builds, staging, or any
product-source edit because the required restart state no longer matches the
supplied manifest. The only edit made after detecting the mismatch is this
required `BLOCKED` ledger update.

| Check | Required | Observed | Verdict |
|---|---|---|---|
| Worktree path | `/Users/junaid/Xcode-Projects/Lidless-worktrees/codex-safety-repair-2026-08-04` | Exact match from `pwd -P` and `git rev-parse --show-toplevel` | PASS |
| Linked-worktree/common directory | Registered linked worktree under `/Users/junaid/Xcode-Projects/Lidless/.git` | Exact match; admin directory is `/Users/junaid/Xcode-Projects/Lidless/.git/worktrees/codex-safety-repair-2026-08-04` | PASS |
| Branch | `codex/lidless-safety-repair-2026-08-04` | Exact match | PASS |
| HEAD | `7f17aaca11bc6228bed48b9265d63b9e576cdea7` | `22ed6189f444a7f96719153ca1abd146d9713510` | **FAIL** |
| Dirty package inventory | 22 modified tracked + 5 untracked manifest paths, excluding only an additional untracked ledger | 21 modified tracked + 3 untracked; the ledger is tracked in the current HEAD rather than present as the permitted `??` bookkeeping path | **FAIL** |
| Tracked binary diff SHA-256 | `585692490de6c54d8a5c37e969ede7f2b185fa198ca0a3b7843695caaec462b0` | `eddd2acc77f548d076981c2a1e5ed68ada2bb0097125153cdea9994c0d4deaa0` from `git diff --binary HEAD` | **FAIL** |
| Manifest records | All 27 exact | 23 exact; four paths differ as detailed below | **FAIL** |
| Main checkout | Recorded preservation baseline | Branch/HEAD, empty tracked diff, untracked path-list hash, and all three artifact modes/sizes/hashes match exactly | PASS |

The unexpected HEAD is a direct child of the required starting HEAD. Its commit
metadata is:

- commit: `22ed6189f444a7f96719153ca1abd146d9713510`
- parent: `7f17aaca11bc6228bed48b9265d63b9e576cdea7`
- subject: `security: validate helper identity before XPC trust`
- committed paths: `ARCHITECTURE.md`, this ledger,
  `Helper/HelperDaemon.swift`,
  `Packages/LidlessCore/Sources/LidlessCore/XPCPeerPolicy.swift`, and
  `Packages/LidlessCore/Tests/LidlessCoreTests/XPCPeerPolicyTests.swift`

All 27 manifest paths exist and retain their expected mode. The four entries
with non-matching status and/or bytes are:

| Path | Manifest evidence | Observed evidence |
|---|---|---|
| `ARCHITECTURE.md` | status ` M`; 8,971 bytes; SHA-256 `a790d7bbf4b026c0941716dc55722c50f7b371bdae1e67f9fdcb92888a42c76a` | clean/tracked; 9,150 bytes; SHA-256 `24c65826d981f93515fe84e0cf9bcd65c8f38e0ddff62008ceae4ff9ccd26749` |
| `Helper/HelperDaemon.swift` | status ` M`; 31,774 bytes; SHA-256 `14e2bc6c50163561022c22a04444f1e5643b02fd4b1aba71c4a5a386a4faf9e0` | status ` M`; 31,474 bytes; SHA-256 `e4bbdca622b1605321dbfa704a0ae9d61894c7fba2ddc240b452dc7e32987477` |
| `Packages/LidlessCore/Sources/LidlessCore/XPCPeerPolicy.swift` | status `??`; 1,108 bytes; SHA-256 `9699b15dce28a3806cb90fbc5f3aeae9a4b9724dc3925dcd697a05c7249f96b5` | clean/tracked; 4,890 bytes; SHA-256 `f4348deb79a18f5efdeba633203f2aacb8873658ccc85e8fffa244dadc6e260a` |
| `Packages/LidlessCore/Tests/LidlessCoreTests/XPCPeerPolicyTests.swift` | status `??`; 1,081 bytes; SHA-256 `5c30eaf3374bcd0ecdda2d7ded63f422c86043dfaf4f23b11fa47e4a465c729e` | clean/tracked; 4,569 bytes; SHA-256 `9478bc7cd57510f2f045352f6dd2e74b479daf58908e5a718f092cf40e054f4d` |

For diagnosis only, the complete tracked diff against the required starting
HEAD hashes to
`07376b7e219534f44f4a2d826352020b41b92e9614921c43178653bfd8e2c031`,
which also does not match the manifest's tracked binary diff hash. No attempt
was made to reset, normalize, amend, or otherwise overwrite this state.

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
| S-01 | Fresh arm requires readable proof of normal sleep before mutation | Optional snapshots precede the first preflight; a second preflight follows the unbounded sentinel write and immediately precedes in-memory ownership plus enable. macOS still provides no atomic registry-read/`pmset` ownership transaction | Tri-state policy tests plus a production-source ordering regression pass | Debug/Release helper compile only; the final cross-process race and live registry behavior remain unproved | PARTIAL — OWNERSHIP/LIVE GATES OPEN |
| S-02 | Arm and restore require exact readback; unknown never succeeds | Exact checks exist in `SleepOverrideSafety`, arm readback, restore readback, and app completion gates | Focused policy tests pass | Manual helper compilation only; no live registry proof | PARTIAL — LIVE/FAULT GATES OPEN |
| S-03 | Sentinel/recovery state survives and retries unverified restoration | The sentinel, connection owner, and monotonic watchdog precede enable; active-session sentinel rewrites are eliminated; exact restore proof gates deletion; deletion/readback failure retains retry state; wake scheduling is deferred while supervising | RED source-contract regression failed on all three active sentinel rewrites; GREEN passes immutability, ordering, timeout wiring, and wake-deferral checks | Debug/Release helper compile with strict concurrency and warnings-as-errors; no daemon fault injection or live recovery | CHECKPOINT VERIFIED OFFLINE — LIVE/FAULT GATES OPEN |
| S-04 | App terminal actions wait for proven restoration | The forced-sleep terminal worker requires strict helper restore proof plus a fresh registry-OFF read; non-sleep disarm/cutoff/quit/orphan paths do not yet apply that rule uniformly | Forced-sleep ordering/source regressions pass; no complete non-sleep transition table | Strict App compilation passes; live restoration remains prohibited | PARTIAL — NON-SLEEP RESTORE DEFECT |
| S-05 | Manual disarm, cutoff, quit, restart, wake, and orphan recovery share pending-restore semantics | Forced sleep is terminally fenced, but the other restore paths remain split and some suppress status/transport errors | No complete transition-table regression | Not runtime tested | CONFIRMED DEFECT |
| S-06 | Heartbeats require a proven armed status | Successful replies require current-version `isArmProven`; registry/helper contradictions invalidate proof, but transport errors still lack bounded escalation | Arm-proof and source-ordering tests pass; no repeated-error regression | Strict App compilation only | PARTIAL — TRANSPORT ESCALATION OPEN |
| S-07 | Stale helper versions cannot arm but remain usable for recovery | Client labels every version `>= 5` ready; v4 lacks proof fields required by restore completion and can carry legacy `priorSleepDisabled = true` | v5 missing-field fail-closed tests pass, exposing rather than solving v4 recovery | No compatible v4 recovery artifact | CONFIRMED DEFECT |
| S-08 | Unknown registry state stays unknown in app and widget | Optional registry evidence feeds one shared reducer; current helper-session proof is required for AWAKE; widget v2 rejects missing, stale, future-dated, or contradictory proof; actions and labels use the canonical state | Presentation truth table, widget schema/freshness, publication, and source-contract regressions pass | Exact App and widget compile; plist/config inspection passes; UI was not launched or rendered | CHECKPOINT VERIFIED OFFLINE — LIVE/VISUAL GATES OPEN |
| S-09 | XPC peer trust fails closed without signed same-team identity | Startup provider validates Apple anchor + helper identifier before reading signing info, validates again with the candidate team, caches the peer requirement, and rejects all peers on failure | RED: missing ordered seam failed compilation; GREEN: 8 XPC tests prove check → extract → candidate-bound check plus failure ordering | Debug/Release helper compile with Swift 6 strict concurrency and warnings-as-errors; signed runtime remains prohibited/unverified | CHECKPOINT VERIFIED OFFLINE |
| S-10 | Protocol/build/signing/release configuration reflects v5 and does not present ad-hoc trust as proof | The offline verifier derives one configured team from `project.yml`; pins the app/helper/widget identifier, team, Developer ID chain, secure timestamp, executable Mach-O type, hardened runtime, leaf certificate, and entitlements in every architecture; requires exact architecture-set parity; rejects extra code, links, unsafe modes, non-owner-executable required binaries, and unexpected executable payloads; requires system-validated macOS distribution profiles that authorize the actual leaf and restricted entitlements; and checks source versions plus the launchd contract. Prepare emits no final hash and adds `syspolicy_check notary-submission`; finalize requires stapler, execution-policy, repository, and distribution checks before zipping and hashing | RED history includes the original absent-verifier/checksum failures, seven reviewer-regression issues for architecture/error/mode branches, and a two-issue owner-execute failure. Final focused GREEN passes all 13 release-policy tests, including eight real-verifier negative fixtures | Bash/ShellCheck/YAML/plist checks pass; Xcodegen reproduces the committed project byte-for-byte. No signed export exists for the positive verifier/profile path | CHECKPOINT VERIFIED OFFLINE — SIGNED/NOTARY GATES OPEN |
| S-11 | A sleep transition cannot resurrect an armed or queued intent | `sleepGeneration` fences every initial/re-arm reply; queued pending intent and its schedule occurrence are synchronously cleared; any active or in-flight arm moves to terminal restoring; wake never renews proof; repeated compensating disarm completes only after all arm calls settle, strict helper restore proof, and fresh registry OFF | Focused RED exposed missing generation/terminal/wake fences; later RED exposed the commit-point and in-flight restore races; final 7-test presentation GREEN plus three independent exact-byte reviews pass | Swift 6 strict App compilation and Debug/Release direct links pass; no real XPC, sleep/wake, or hardware proof | CHECKPOINT VERIFIED OFFLINE — LIVE/HARDWARE GATES OPEN |
| V-01 | Complete core suite | N/A | Exact checkpoint tree passed 195 tests in 11 suites; complete dirty remainder tree passed 197 tests in 11 suites | Complete outputs are preserved in `swift-test-full-exact-presentation-stable-final5.log` and `swift-test-full-dirty-presentation-stable-final5.log` | PASS |
| V-02 | Unsigned Debug and Release full-graph builds | N/A | N/A | Stable Swift Debug/Release core builds pass. All exact app/helper/widget source sets compiled and linked as identity-free arm64 Mach-O executables in Debug and optimized Release; the current App outputs are `exact-presentation-products-final4-*`, while unchanged helper/widget outputs are `exact-presentation-products-final2-*`. Xcode's graph was not retried because its nested sandbox and automatic LaunchServices side effect were already established | PARTIAL — XCODE GRAPH ENVIRONMENT BLOCKED |
| V-03 | Static analysis without live activation | N/A | N/A | Current exact and dirty App sources pass Swift 6 complete strict-concurrency typechecking with warnings-as-errors; unchanged exact helper/widget strict checks and core builds also pass. Xcode `analyze` remains blocked with the project graph | PARTIAL — XCODE ANALYZE BLOCKED |
| V-04 | Built bundle, plist, configuration, and entitlement claims | N/A | Presentation/release regressions pass | Exact source app/widget Info plists and entitlements plus helper launchd plist pass `plutil -lint` and were decoded; `project.yml` identifiers, deployment target, plist, and entitlement bindings were inspected. Direct executables are unbundled linker-ad-hoc outputs with no TeamIdentifier, bound Info.plist, sealed resources, or entitlements—not signed runtime proof | PARTIAL — SIGNED ARTIFACT GATE OPEN |
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
- E-025 — 2026-08-05T12:28:24+0200 — Read the canonical handoff, supplied manifest, progress log, decision log, architecture, and design-reset brief in full. The handoff SHA-256 was exactly `95bdacdde663c642c2f97d532c1ec2b931e94a7dfcda47b8031e011ab3944831`; the manifest SHA-256 was exactly `d84065171a261e24ae574b98164132472ff1e8bb635647403d814b9fcf58c36a`. A repository-wide hidden-file scan found no `AGENTS.md`, `CLAUDE.md`, or equivalent agent instruction file.
- E-026 — 2026-08-05T12:28:24+0200 — The restart recovery gate failed before any edit. The isolated path, linked-worktree registration, common directory, and branch matched, but HEAD was `22ed6189f444a7f96719153ca1abd146d9713510` instead of the required `7f17aaca11bc6228bed48b9265d63b9e576cdea7`; dirty inventory was 21 modified tracked plus 3 untracked rather than 22 plus 5; and the required ledger was already tracked in the unexpected commit rather than appearing as the sole permitted additional untracked path.
- E-027 — 2026-08-05T12:28:24+0200 — Independently checked existence, status, mode, byte count, and raw SHA-256 for all 27 manifest entries. Twenty-three entries matched every field. The four exact path-level mismatches are recorded in the blocking section above. `git diff --binary HEAD` hashed to `eddd2acc77f548d076981c2a1e5ed68ada2bb0097125153cdea9994c0d4deaa0`, not the required `585692490de6c54d8a5c37e969ede7f2b185fa198ca0a3b7843695caaec462b0`.
- E-028 — 2026-08-05T12:28:24+0200 — Reverified the main checkout without editing it: `main` remained at `7f17aaca11bc6228bed48b9265d63b9e576cdea7`; its tracked binary diff hash remained the empty hash; its NUL-delimited untracked path-list hash remained `1ddc7b8fe0b0232cf68c470366a1eb1eeac1e5fd8e764e0f814eecf61e9e290a`; and the recorded modes, sizes, and SHA-256 values of all three `.playwright-mcp/` artifacts matched exactly. Per the hard-stop contract, no tests, builds, static analysis, staging, commit, product-source edit, app/helper launch, or live action followed; only this required `BLOCKED` ledger update was made.
- E-029 — 2026-08-05T13:25:55+0200 — Read the canonical handoff, immutable state manifest, rolling remainder manifest and sidecar, progress log, decision log, architecture, and design-reset brief in full. The supplied canonical and immutable-manifest hashes matched exactly. The sidecar's recorded rolling-manifest SHA-256 `76f07d267dd2e314f7ad349ab956405085bc5f42796c440b8e783a0ac7359e1d` matched the manifest bytes. A repository-wide instruction-file scan again found no `AGENTS.md`, `CLAUDE.md`, or equivalent agent instruction file.
- E-030 — 2026-08-05T13:25:55+0200 — Applied the checkpoint-aware rolling manifest as the sole recovery authority. The feature worktree canonical path, linked topology, branch, HEAD `22ed6189f444a7f96719153ca1abd146d9713510`, Git admin/common directories, clean index, 25-path dirty inventory, every path's status/type/mode/size/raw SHA-256, NUL-status digest `7d7e30f1a7c3b8eea307581d2d411e5f9e69d8f2376d0d8a7f40af4018b5e015`, and tracked binary-diff digest `75a0237740b72d9249529d4d9fa4884db0a3593484453451b21b28ea546afe8e` matched exactly.
- E-031 — 2026-08-05T13:25:55+0200 — Independently reverified the rolling manifest's main-checkout record without editing it: canonical path, linked topology, `main` at `7f17aaca11bc6228bed48b9265d63b9e576cdea7`, clean index, all three `.playwright-mcp` records, NUL-status digest `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`, and empty tracked binary-diff digest matched exactly.
- E-032 — 2026-08-05T13:25:55+0200 — Corrected the top-level state from `BLOCKED` to `IN_PROGRESS` under the explicit rolling-manifest recovery rule. The earlier false-stop evidence remains intact; no historical evidence was removed or rewritten, and no product source was changed during recovery.

## Rolling-manifest recovery correction — 2026-08-05T13:25:55+0200

The `BLOCKED` entry at 12:28:24 applied the historical starting-state manifest
after the legitimate first checkpoint. The authenticated rolling manifest is
the required post-checkpoint authority and reproduces exactly. The false stop
is therefore corrected to `State: IN_PROGRESS`; its evidence remains above.

## Second-checkpoint ruling — helper supervision queue

The coherent scope for this invocation is the helper's synchronous
supervision/restore group, planned as `security: bound helper supervision
work`. It repairs the avoidable queue-starvation portion of F-002 and the v5
helper's sentinel/readback retry behavior without accepting the unreviewed app,
widget, release, configuration, or design remainder.

The helper now snapshots optional settings before its final preparation,
limits each `pmset` wait to 3 seconds plus a 1-second forced-termination
observation window, installs the sentinel/connection owner/monotonic watchdog
before enable, proves the registry result, replies before at most two optional
mutations, and defers wake scheduling while armed or recovering. The disk
sentinel is immutable during an active session: re-arm, proven-arm completion,
and heartbeat refresh queue-owned memory only. Restoration always targets
ordinary sleep, requires exact readback before deletion, and retains retry
state when readback or sentinel deletion is not proven complete.

This checkpoint deliberately does **not** close or claim:

- the final cross-process registry-read-to-`pmset` race, because macOS exposes
  no atomic ownership primitive for the global Boolean;
- a formal real-time bound for `Process.run`, filesystem calls, IOKit, or every
  OS operation; 3+1 seconds bounds only the child wait/reap observation;
- stale-v4 app/helper reconciliation (F-003), including a running v4 helper
  restoring its legacy `priorSleepDisabled = true` value;
- heartbeat transport escalation, wake/orphan app reconciliation, unknown UI
  presentation, signed runtime behavior, or any hardware recovery path.

The prepared-sentinel interval also remains conservative: a crash after the
sentinel exists but before Lidless enables the override can cause recovery to
prefer normal sleep over a concurrent external owner. That tradeoff and the
remaining ownership race require separate live/design review.

- E-033 — 2026-08-05T13:48:32+0200 — Reviewed the complete 25-path rolling remainder against checkpoint HEAD and traced helper, app reconciliation, release/configuration, test, and documentation claims. Independent read-only reviews confirmed that app stale-v4/heartbeat/unknown-state defects and release-policy defects remain separate root-cause groups; only the helper supervision queue is eligible for this invocation's checkpoint.
- E-034 — 2026-08-05T13:48:32+0200 — Reproduced the dirty-package baseline at 169 tests in 7 suites. Added the timing policy regression first: the corrected RED run failed compilation because `HelperSupervisionTiming` did not exist; after adding the 3-second timeout, 1-second reap observation, and minimum-TTL arithmetic, focused GREEN passed 3 tests. A first GREEN command used a non-matching filter and ran no tests; it is preserved and not counted.
- E-035 — 2026-08-05T13:48:32+0200 — Fresh adversarial review rejected the first repair because synchronous sentinel rewrites in re-arm, proven-arm completion, and heartbeat could still block the supervision queue and then erase an expired deadline. Added a production-source contract regression before the correction; expanded RED failed with six issues covering all three rewrites, missing post-write preflight ordering, and unchecked kill/reap wiring. After the focused correction, GREEN passed all 4 source-safety tests.
- E-036 — 2026-08-05T13:48:32+0200 — Removed every active-session sentinel rewrite, added the second inactive-state preflight after the only unbounded preparation write, made sentinel deletion failure durable, required exact arm/restore proof, rejected wake scheduling while supervising, and made timeout diagnostics distinguish failed SIGKILL acceptance and unobserved child exit. The remaining registry-read-to-mutation race is explicitly not claimed closed.
- E-037 — 2026-08-05T13:48:32+0200 — Full dirty-tree `swift test` passed 177 tests in 9 suites. Dedicated Debug and Release `LidlessCore` builds passed. Standalone Debug and optimized Release helper compiles passed with Swift 6 complete strict concurrency and warnings-as-errors. Initial helper compile invocations failed only because Clang attempted the sandbox-blocked user module cache; corrected invocations redirected the cache into this worktree and passed. All outputs are under ignored `build/verification-2026-08-05/`; no binary was launched.
- E-038 — 2026-08-05T13:48:32+0200 — Current full-graph Debug, Release, and Debug-analysis Xcode attempts used `CODE_SIGNING_ALLOWED=NO` and did not launch Lidless or its helper. All failed because the local `LidlessCore` package product was unresolved; the parallel Debug build/analyze attempts also contended on one DerivedData database. Release and analysis nevertheless reached normal Xcode postprocessing and invoked `RegisterWithLaunchServices` for incomplete unsigned app output before reporting failure. This was not helper installation/registration or app execution, but it is an automatic side effect and no further Xcode attempt is made. These failures are not build or runtime proof.
- E-039 — 2026-08-05T13:48:32+0200 — Corrected static artifact inspection passed `plutil -lint` for app/widget Info plists and entitlements, helper launchd plist, export options, and `project.pbxproj`. The helper plist exactly reports label/Mach service `com.lidless.helper`, `RunAtLoad = true`, sentinel `KeepAlive.PathState = true`, and associated app `com.lidless.app`; both incomplete Xcode output trees copied that plist byte-for-byte. One preliminary lint used the wrong export-options path and an invalid dotted `plutil` key path; its output is preserved but not counted.
- E-040 — 2026-08-05T13:48:32+0200 — Independent fresh review found no remaining blocker for this narrowly named helper timing/queue-starvation checkpoint. It confirmed active sentinel immutability, second-preflight ordering, timeout diagnostics, reply-before-optionals, wake deferral, and deletion retry, while requiring the ownership race, prepared-sentinel tradeoff, non-real-time OS calls, and stale-v4 reconciliation to remain explicit gates.
- E-041 — 2026-08-05T13:51:00+0200 — Partially staged exactly eleven files for the helper checkpoint, excluding the modified `SmokeTests.swift` and every app/widget/release/configuration/design remainder. `git diff --cached --check` passed. A fresh `/private/tmp` export of the exact Git index passed all 175 tests in 9 suites, dedicated Debug and Release core builds, and standalone Debug and optimized Release helper compiles with Swift 6 complete strict concurrency and warnings-as-errors. The snapshot products are compile-only, were not launched, and do not establish signed XPC, live `pmset`, sleep/wake, crash, or hardware behavior.
- E-042 — 2026-08-05T13:55:13+0200 — Read the canonical handoff, immutable starting-state manifest, rolling remainder manifest and adjacent sidecar, progress log, decision log, architecture, and design-reset brief in full. The canonical handoff and immutable manifest matched their supplied SHA-256 values. The rolling sidecar recorded SHA-256 `2681e2374a5528af1ec14ab6030247c97d1ac69a0c3a093ef536f33bd27f55e1`, which exactly matched the rolling manifest bytes. A repository scan found no `AGENTS.md`, `CLAUDE.md`, `CODEX.md`, `INSTRUCTIONS.md`, `.cursorrules`, or `*.instructions.md` file.
- E-043 — 2026-08-05T13:55:13+0200 — Applied only the authenticated rolling manifest for recovery. The feature worktree canonical path, linked-worktree registration, branch, HEAD `19873dce9c2cd07035eda20969ca61e327ae535c`, Git admin/common directories, clean index, 19-path dirty inventory, every path's status/type/mode/size/raw SHA-256, NUL-status digest `1ca042c48a7c67433bc151a1a799445c38baebbbcde18b931e58d7d74af5d21c`, and tracked binary-diff digest `d1ee896b25c14d4e32721f69b2cd9ba0c3e2e10b304aed4d9cbdbeb8a366395a` matched exactly. The starting HEAD remains an ancestor through the two named checkpoint commits. A preliminary newline-delimited status hash differed by encoding and was not used; the required NUL-delimited reproduction matched exactly and changed no files.
- E-044 — 2026-08-05T13:55:13+0200 — Independently reverified the rolling manifest's main-checkout record without editing it: canonical path and topology, `main` at `7f17aaca11bc6228bed48b9265d63b9e576cdea7`, clean index, all three `.playwright-mcp` records, NUL-status digest `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`, and empty tracked binary-diff digest matched exactly. Recovery passed before this ledger append and `State: IN_PROGRESS` remains correct.

## Third-checkpoint ruling — release trust and configuration

The coherent scope for this invocation is F-005 plus the release-signing and
documentation portion of F-006, planned as `security: enforce release artifact
trust policy`. It retains the preserved automatic-signing configuration,
enables the reviewed app-group entitlements, makes account-free CI explicitly
compile-only, adds a fail-closed offline verifier for exported artifacts, and
separates notarization submission from final stapled-artifact hashing.

The verifier requires exact app/helper/widget identifiers; the configured
repository team; Developer ID Application certificate policy; secure
timestamps, executable Mach-O type, hardened runtime, entitlements, and one
common leaf in every architecture; exact nested-code inventory and a
fail-closed file-mode policy; exact
app/widget application, team, app-group, sandbox, and debug entitlements; no
helper entitlement; system-validated macOS distribution profiles that authorize
the actual leaf; matching source/built versions; and a byte-identical,
field-checked launchd plist. Prepare adds the system notarization-submission
policy check. Finalization requires stapler, execution-policy, repository, and
system distribution checks before producing the final zip and checksum.

This checkpoint deliberately does **not** close or claim:

- a positive verifier result, because no signed Developer ID export was
  available or authorized in this offline worker;
- notarization acceptance, stapling, Gatekeeper behavior on another machine,
  signed XPC trust, SMAppService behavior, or release readiness;
- Xcode full-project build/analyze success in this managed environment, where
  SwiftPM's nested manifest sandbox is rejected by the outer sandbox;
- stale-v4 recovery, heartbeat transport escalation, wake/orphan
  reconciliation, unknown-state UI treatment, or any other app/widget source
  remainder. Those paths remain unstaged for later checkpoints.

- E-045 — 2026-08-05T14:24:17+0200 — Reviewed every remaining diff against checkpoint HEAD and traced the app-recovery, unknown-state, release/configuration, CI, test, and documentation claims. Independent read-only reviews confirmed that stale-v4 recovery, ignored heartbeat/status transport errors, duplicate delayed force-sleep, unsafe uninstall nil handling, and unknown-state presentation are not coherent. The release/configuration group is separable and is the only group selected for this invocation.
- E-046 — 2026-08-05T14:24:17+0200 — Added the focused release-policy regression before implementation. The RED run executed 4 tests and reported 3 issues: two required-verifier assertions failed because `Scripts/verify_release_bundle.sh` did not exist, and the checksum-order assertion proved the release hash preceded stapler validation. The existing source/generated signing-alignment assertion passed. Complete output is preserved in `swift-test-release-policy-red.log`.
- E-047 — 2026-08-05T14:24:17+0200 — Implemented the focused root-cause repair: the offline verifier pins every nested identity/team/requirement/runtime flag, app/widget signed entitlements and unexpired profiles, absence of helper entitlements, versions, layout, and launchd contract. `release.sh prepare` now stops at a verified notarization-submission zip without a final hash; `finalize` requires a stapled ticket, execution-policy acceptance, repeat verification, final zipping, and then SHA-256. No credential, notarization, stapling, signing, publication, or live action was executed.
- E-048 — 2026-08-05T14:24:17+0200 — Final focused GREEN passed 5 tests in the release-policy suite. Bash syntax, ShellCheck at warning threshold, YAML parsing, plist/project lint, `git diff --check`, executable modes, and compilation of the pinned `csreq` requirement all passed. A temporary mirror regeneration with Xcodegen 2.45.4 reproduced `project.pbxproj` byte-for-byte at SHA-256 `e25e98206197323e9c102058aee0e81e4d46fe8e0d75572cc5b56f6a32a6298e`.
- E-049 — 2026-08-05T14:24:17+0200 — The final complete dirty-tree `swift test --package-path Packages/LidlessCore` run, using stable Xcode 26.5's Swift toolchain with all writable caches inside the worktree and SwiftPM's nested sandbox disabled, passed 182 tests in 10 suites. Complete output is preserved in `swift-test-full-release-checkpoint-final.log`.
- E-050 — 2026-08-05T14:24:17+0200 — Stable Swift Debug and Release `LidlessCore` builds passed. Against those exact products, all 25 app files, all 4 helper files, and the widget compiled in both Debug and optimized Release with Swift 6 complete strict concurrency and warnings-as-errors. The outputs are unsigned compile-only Mach-O artifacts under the ignored verification directory and were not launched.
- E-051 — 2026-08-05T14:24:17+0200 — Stable and beta Xcode project-resolution retries kept DerivedData, package caches, module caches, and fallback user state inside the worktree and did not pass any signing or provisioning-update option. Both stopped before compilation because Xcode invokes a nested `sandbox-exec` for the local package manifest and the managed outer sandbox rejects it with `sandbox_apply: Operation not permitted`. A hidden manifest-sandbox preference was inspected but not applied to the real user domain. No app bundle was produced or registered, and neither Lidless nor its helper ran. The new verifier was exercised only as a negative fail-closed probe against incomplete unsigned output; no signed artifact existed for its positive path.
- E-052 — 2026-08-05T14:24:17+0200 — Pre-commit preservation recheck passed without editing the main checkout: it remains on `main` at `7f17aaca11bc6228bed48b9265d63b9e576cdea7`, its index is clean, its tracked binary diff is empty, its NUL-status digest remains `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`, and all three `.playwright-mcp` modes, sizes, and SHA-256 values match E-044 exactly.
- E-053 — 2026-08-05T14:55:48+0200 — Two fresh read-only reviews rejected the initial nine-file staged release snapshot. They found an artifact-selected team, native-slice-only entitlement/timestamp checks, incomplete profile authenticity/distribution/certificate authorization, masked traversal failure, permissive executable inventory, source-derived final filenames, string-only tests, dirty-tree rather than exact-index evidence, and README claims that contradicted the still-open app findings. The rejected staged snapshot was not committed; its findings and prior evidence remain preserved.
- E-054 — 2026-08-05T14:55:48+0200 — Corrected every confirmed review defect. The verifier now binds to the sole configured team, inspects Mach-O type, identifier, team, Developer ID authority, timestamp, hardened runtime, leaf certificate, and entitlements per architecture, requires common leaf/entitlements across slices, materializes checked `find` output, rejects links/extra code/special or unexpected executable modes, and validates the widget executable. It runs `profiles validate` before CMS decoding, requires Developer ID/macOS distribution shape, binds the actual leaf to `DeveloperCertificates`, checks optional keychain authorization, and binds built versions to source. Release preparation/finalization add documented `syspolicy_check` gates and derive the final filename from the verified app. README and CONTRIBUTING now distinguish intended mechanisms from offline proof and retain every open live/app/hardware gate.
- E-055 — 2026-08-05T14:55:48+0200 — Expanded focused GREEN passed 8 release-policy tests, including executable negative fixtures that run the real verifier against an unsigned exact-layout bundle, an unexpected Mach-O, and a symbolic link without signing or launching code. The final complete dirty-tree suite passed 185 tests in 10 suites. Outputs are `swift-test-release-policy-final.log` and `swift-test-full-release-checkpoint-final-dirty.log`.
- E-056 — 2026-08-05T14:55:48+0200 — Corrected static verification passed Bash syntax, ShellCheck at warning threshold, plist/project lint, YAML parsing, executable modes, `git diff --cached --check`, and compilation of the exact pinned code requirement from standard input. A preliminary aggregator incorrectly passed the requirement text as a pathname and lacked errexit, so it printed an error followed by a false `PASS`; `release-checkpoint-static-final.log` is preserved but explicitly discarded. The corrected `release-checkpoint-static-final-corrected.log` uses `set -euo pipefail` and passed. Xcodegen 2.45.4 again reproduced `project.pbxproj` byte-for-byte at SHA-256 `e25e98206197323e9c102058aee0e81e4d46fe8e0d75572cc5b56f6a32a6298e`.
- E-057 — 2026-08-05T14:55:48+0200 — A preliminary exact-index export at tree `7ba7e6bdd462cdacf4300fae7631db4a56e4f9a5` passed 183 tests in 10 suites and dedicated Debug/Release core builds. All 25 app, 4 helper, and 1 widget source files from that index then compiled into unsigned Debug and optimized Release Mach-O executables with Swift 6 complete strict concurrency and warnings-as-errors. The first direct app invocation omitted the managed environment's required compiler `-disable-sandbox`; the next widget invocation omitted `-parse-as-library`; both failures are preserved and not counted. Corrected invocations passed, and no product was launched. Later verifier/docs hardening requires one final exact-index reproduction before commit.
- E-058 — 2026-08-05T14:55:48+0200 — Independent final review of pre-ledger code/docs tree `31397048b5ff540c9c922cf7951389c814179125` and verifier blob `ffca199ec5f247352afeeb8d5ba635a4c91f687d` found no remaining code or documentation blocker. It confirmed fail-closed configured-team, per-architecture, layout/mode, profile/leaf, version, release-ordering, and evidence-boundary behavior. It retains as explicit external gates a positive Developer ID export and real profile-shape compatibility, notarization/stapling, source-to-binary provenance, concurrent artifact mutation, signed XPC, `SMAppService`, widget sharing, Gatekeeper on another host, and all live/hardware behavior.
- E-059 — 2026-08-05T15:06:14+0200 — A second independent review overturned E-058 for its reviewed bytes. It found that nested architecture sets were not compared to the app, `file` inspection was not demonstrably fail-closed, and mode/error branches lacked behavioral fixtures. The later exact-index run at tree `037c84016714ce3f08ba8304719e0e3c6b57775a` and its 183-test/static/build evidence are therefore superseded and are not commit authority.
- E-060 — 2026-08-05T15:06:14+0200 — Added four behavioral regressions before the correction. The 12-test RED run recorded seven issues: missing architecture/file policy tokens, a thinned helper reaching app identity inspection, an unreadable resource failing for the wrong reason, and a sticky-mode executable reaching identity inspection. Complete output is preserved in `swift-test-release-policy-reviewer-red.log`.
- E-061 — 2026-08-05T15:06:14+0200 — Corrected architecture discovery to validate executable Mach-O type before identity and require exact sorted helper/widget parity with the app; made bundle-file inspection reject unreadability and `file` errors; parsed full raw modes and rejected the special-bit class; and added executable non-Mach-O coverage. After correcting two test/environment assumptions, focused GREEN passed 12 of 12. The complete accepted output is `swift-test-release-policy-reviewer-green-final.log`; the earlier GREEN-named attempt is preserved but not counted.
- E-062 — 2026-08-05T15:06:14+0200 — The complete dirty-tree suite after those corrections passed 189 tests in 10 suites. A subsequent raw-mode re-review found one remaining blocker in that tree: the expected app/helper/widget accepted group- or other-only execute permission because the shared predicate tested any of `0111`.
- E-063 — 2026-08-05T15:06:14+0200 — Added the owner-execute behavioral regression before changing production. Against the old predicate, mode `0401` passed the initial mode gate and reached identity inspection; the one-test RED recorded the two expected issues in `swift-test-release-policy-owner-mode-red.log`. Production now requires owner execute `0100` for the three expected binaries while retaining any-execute `0111` solely to reject unexpected executable non-Mach-O payloads. The regression exercises both readable `0401` and `0410` files; focused GREEN passed all 13 tests and the final complete dirty-tree suite passed 190 tests in 10 suites. Accepted outputs are `swift-test-release-policy-13-green.log` and `swift-test-full-release-checkpoint-reviewer-mode-final-dirty.log`.
- E-064 — 2026-08-05T15:11:26+0200 — Both independent re-reviews found no blocker in staged code/docs tree `ea4c12da9a0c2e86b05b7dfdccca71ceb4556812`, verifier blob `8cc9adf6a192cfa76a8404763495fe0a94cb53b3`, and test blob `cbc3489b23e8c408b60451798a69013ae188ada8`. They independently confirmed full `%p` parsing, `07000` rejection, the expected-binary `0100` versus unexpected-payload `0111` split, both mode fixtures, Bash 3.2 syntax, ShellCheck, and the focused 13-test result.
- E-065 — 2026-08-05T15:11:26+0200 — Exported exact Git index tree `718818bb8521181fbaa2fe407b52c3cf726816f5` with staged binary-diff SHA-256 `ad0e6141f46bc8a000b35e3dad4d8b32696373104c2f42103831f3a610f19f7c`. Its complete core suite passed 188 tests in 10 suites. Exact-index static verification passed Bash syntax, ShellCheck at warning threshold, YAML/plist/project lint, script modes, staged diff checking, pinned-requirement compilation, and Xcodegen 2.45.4 byte-for-byte reproduction of `project.pbxproj` at SHA-256 `e25e98206197323e9c102058aee0e81e4d46fe8e0d75572cc5b56f6a32a6298e`.
- E-066 — 2026-08-05T15:11:26+0200 — Exact-index Debug and Release core builds passed. All 25 app, 4 helper, and 1 widget sources then compiled in Debug and optimized Release with Swift 6 complete strict concurrency and warnings-as-errors into unsigned arm64 Mach-O executables; none was launched. The first final direct Debug command incorrectly selected deployment target 14.0 against the package's configured 15.0 minimum and was rejected before product emission; it is preserved and not counted. The corrected 15.0 Debug and Release commands passed. Source signing configuration, app/widget entitlements, Developer ID export method, versions, and the helper launchd fields were inspected from the exact index; no built signed bundle exists.
- E-067 — 2026-08-05T15:11:26+0200 — Final main-checkout preservation passed exactly: canonical path, linked topology baseline, `main` at `7f17aaca11bc6228bed48b9265d63b9e576cdea7`, clean index, empty tracked diff, all three `.playwright-mcp` modes/sizes/hashes, and required all-untracked NUL-status digest `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18` match the rolling-manifest baseline. A preliminary status hash omitted `--untracked-files=all`, collapsed the directory to one status record, and was discarded; it changed no file.

## Fourth recovery audit — app reconciliation remainder

- E-068 — 2026-08-05T15:16:06+0200 — Read the canonical handoff, immutable starting-state manifest, rolling remainder manifest and adjacent sidecar, progress log, decision log, architecture, design-reset brief, and this ledger in full. The canonical handoff and immutable manifest matched their supplied SHA-256 values. The sidecar-recorded rolling-manifest SHA-256 `c26340a1a72dc4dbb6d2f63433e0da48c5e54019ea49c96b88bd89b974934c7e` matched the manifest bytes. A repository-wide scan found no `AGENTS.md`, `CLAUDE.md`, `CODEX.md`, `.github/copilot-instructions.md`, or matching instruction file.
- E-069 — 2026-08-05T15:16:06+0200 — Applied only the authenticated rolling manifest for recovery. The feature worktree canonical path, linked-worktree registration, branch, HEAD `91186e79758337894ef58fa098fa75b7b03fe7be`, Git admin/common directories, clean index, complete 13-path dirty inventory, every recorded status/type/mode/size/raw SHA-256, NUL-status digest `537e3a1fab3fe7c7c8962d71ac0361292c58e457112f7b20fabab9b35e4b0887`, and tracked binary-diff digest `33b437ff5d175ab85dfe0163a461165d86da1cf7aed47fa62525c21c3423df63` matched exactly. The starting HEAD remains an ancestor through the three named checkpoint commits. Recovery passed before this append and `State: IN_PROGRESS` remains correct.
- E-070 — 2026-08-05T15:16:06+0200 — Independently reverified the rolling manifest's main-checkout record without editing it: canonical path and linked topology, `main` at `7f17aaca11bc6228bed48b9265d63b9e576cdea7`, clean index, complete three-path `.playwright-mcp` inventory, every recorded status/type/mode/size/raw SHA-256, NUL-status digest `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`, and empty tracked binary-diff digest matched exactly.

## Fourth-checkpoint ruling — fail-closed sleep presentation

The coherent scope for this invocation is the app/widget presentation and
forced-sleep intent group, planned as `safety: fail closed on unknown sleep
state`. The exact checkpoint replaces intent-derived OFF/AWAKE labels with one
shared evidence reducer, requires a current eligible helper proof plus readable
registry ON for AWAKE, expires widget claims, persists conservative transitions
before arm/re-arm mutation, and terminally fences every queued or in-flight arm
across sleep/wake.

A sleep signal now synchronously clears pending intent, suppresses the active
schedule occurrence, advances the proof generation, and moves any active or
in-flight arm to restoring. Wake cannot renew armed proof. A single idempotent
worker starts compensating restore immediately, repeats while an arm can still
settle late, and cannot return to disarmed until all tracked arm calls have
settled, the helper strictly proves restoration, and a separately refreshed
registry read proves the override OFF. This is an offline control-flow and
compile/test result only; no app/helper was launched and no sleep or power
setting was changed.

This checkpoint deliberately does **not** close or claim:

- uniform strict completion for non-sleep manual disarm, cutoff, quit, repair,
  ambiguous arm failure, or orphan reconciliation;
- stale-helper recovery, bounded XPC transport timeouts, repeated heartbeat
  transport escalation, or every pending-restore identity/cancellation race;
- uninstall behavior for every future/unknown `SMAppService` state, duplicate
  forced-sleep suppression, or the remaining broader recovery diff;
- visual approval of the touched SwiftUI states. The design doctrine was
  applied to semantic hierarchy, affordance, accessibility, and restrained
  motion, but rendering would require the prohibited app launch;
- signed bundle identity, XPC trust, `SMAppService`, live arm/restore,
  sleep/wake, crash recovery, closed-lid hardware, notarization, release, or
  production readiness.

- E-071 — 2026-08-05T16:53:16+0200 — Reviewed the complete 13-path rolling remainder and the complete diff against checkpoint HEAD before accepting any preserved claim. The dirty baseline passed 190 tests in 10 suites, but review rejected the remainder as one package: strict non-sleep recovery, stale-helper/uninstall, timeout/heartbeat, and design work remain separate groups. Only fail-closed presentation plus forced-sleep intent fencing is selected here.
- E-072 — 2026-08-05T16:53:16+0200 — Added presentation regressions before implementation. The initial RED failed because the shared reducer/schema did not exist. Subsequent RED evidence separately captured a missing post-suspension helper/proof boundary, a helper-proof lifetime failure, and the missing synchronous arm commit point. Corrected focused GREEN runs passed after current-version helper proof, fresh eligibility/registry/intent checks, widget-transition persistence, and synchronous removal of the confirmation card before helper dispatch. Logs include `swift-test-sleep-presentation-red.log`, `swift-test-presentation-boundaries-red.log`, `swift-test-presentation-lifetime-red.log`, and `swift-test-presentation-commit-red.log`; corresponding accepted GREEN outputs remain beside them. Setup-only failures from an invalid relative module-cache path and non-matching filter are preserved and not counted.
- E-073 — 2026-08-05T16:53:16+0200 — Implemented the shared six-state presentation policy, optional registry evidence with per-read revision, current eligible helper-session proof, widget v2 proof/freshness/contradiction checks, legacy snapshot removal, and persistence-aware arm/re-arm transitions. App and widget action/label/accessibility state now derive from the canonical presentation. A stale helper remains reachable for later recovery but is no longer usable to arm.
- E-074 — 2026-08-05T16:53:16+0200 — Independent review found that Cancel remained actionable while `helper.arm` was suspended. The focused RED failed on the absent commit point. The fix clears `pendingArm` synchronously after final intent/battery/preflight checks and before XPC dispatch; `swift-test-presentation-commit-green.log` then passed all 6 presentation tests.
- E-075 — 2026-08-05T16:53:16+0200 — A later adversarial review found that re-arm could cross forced sleep and be re-proven by heartbeat/wake status. The new focused RED `swift-test-sleep-terminal-fence-red.log` failed on every absent generation, terminal-phase, tracking, wake, and restore fence. The final implementation also closes queued-disarmed pending intent and `.disarming` plus in-flight re-arm interleavings, removes the unsafe 60-second heuristic, and suppresses scheduled re-entry. `swift-test-presentation-final7.log` passes all 7 tests in the presentation suite.
- E-076 — 2026-08-05T16:53:16+0200 — Final stable-Xcode complete verification passed on both authorities: the exact staged export passed 195 tests in 11 suites and the complete dirty remainder tree passed 197 tests in 11 suites. Accepted complete outputs are `swift-test-full-exact-presentation-stable-final5.log` and `swift-test-full-dirty-presentation-stable-final5.log`. Earlier final4-named runs failed only because an older source-contract assertion still searched for the now-wrapped raw arm call; those failures were preserved and the assertion was corrected without weakening the invariant.
- E-077 — 2026-08-05T16:53:16+0200 — Current exact and dirty App sources pass macOS 15 Swift 6 complete strict-concurrency typechecking with warnings-as-errors in `swiftc-app-typecheck-*-presentation-final4.log`. Exact Debug/Release core builds passed. The current exact App compiled and linked in Debug and optimized Release (`exact-presentation-products-final4-*`); unchanged exact helper and widget Debug/Release outputs from the final2 compile remain valid. All six inspected outputs are arm64 Mach-O and none was launched. Preliminary target-14 and omitted-object link attempts are preserved as setup failures and not counted.
- E-078 — 2026-08-05T16:53:16+0200 — `plutil -lint` passed the exact app/widget Info plists and entitlements plus helper launchd plist; decoded outputs and relevant `project.yml` bindings are preserved in `plutil-*-exact-presentation-final.log` and `project-config-exact-presentation-final.log`. Direct App outputs report only automatic linker ad-hoc signatures (`adhoc,linker-signed`), no TeamIdentifier, no bound Info.plist, no sealed resources, and no entitlements. They are identity-free compile/link evidence, not signed bundle or runtime trust evidence.
- E-079 — 2026-08-05T16:53:16+0200 — Three independent final exact-byte reviews passed the forced-sleep checkpoint after successively exposing and repairing the in-flight Cancel, wake resurrection, queued pending-intent, and `.disarming` plus outstanding re-arm races. The accepted exact AppState SHA-256 is `6b04f93800fa35ce1d780e680de889081ead1fa293df2eb96537a4bbaaee280d`; the focused test SHA-256 is `a98b5b42cab561b7145386b11ed76807db77c6f3bec98cc58ba943ff63920277`. Reviewers retain the non-sleep recovery defects above as a separate remainder and explicitly do not provide hardware/runtime proof.
- E-080 — 2026-08-05T16:53:16+0200 — The design-quality skill was applied because status controls and accessibility semantics changed. No redesign, image generation, screenshot render, preview, or app launch was performed. The checkpoint uses the existing visual language and limits changes to conservative labels, warning states, disabled affordances, and canonical accessibility values. Visual approval remains open.
- E-081 — 2026-08-05T16:53:16+0200 — Every one of the 18 staged code/test paths was compared byte-for-byte with the independently tested exact export and matched its Git index blob. The pre-ledger exact index tree is `7b34173543d6a25d035b04b78cdf62d6df904c7b`; its staged binary-diff SHA-256 is `ee8ec18e22561155d5075c79fa28c6c1888a140ba1d1785408222379517583d5`. Every staged diff was reviewed and `git diff --cached --check` passed.
- E-082 — 2026-08-05T16:53:16+0200 — Final pre-commit main-checkout preservation passed exactly: canonical path, `main` at `7f17aaca11bc6228bed48b9265d63b9e576cdea7`, clean index, empty tracked diff, all three `.playwright-mcp` modes/sizes/SHA-256 values, and NUL-status digest `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18` match the rolling authority. The main checkout was not edited.
- E-083 — 2026-08-05T16:53:16+0200 — The checkpoint is prepared under subject `safety: fail closed on unknown sleep state`. The broader app-recovery/design remainder stays unstaged, so `State: IN_PROGRESS` is intentionally retained. Xcode graph build/analyze was not retried after the already-established nested-sandbox and automatic LaunchServices side-effect risk; direct identity-free compilation is the only build evidence claimed here.

## Fifth recovery audit — non-sleep recovery remainder

- E-084 — 2026-08-05T16:57:45+0200 — Read the canonical handoff, immutable starting-state manifest, rolling remainder manifest and adjacent sidecar, progress log, decision log, architecture, design-reset brief, and this ledger in full. The canonical handoff and immutable manifest matched their supplied SHA-256 values. The sidecar-recorded rolling-manifest SHA-256 `fa40bd4fc4e848a945ce009f30c7b473ea64d3bb87f10dbb44e1e5f6db398e77` matched the manifest bytes. A repository-wide hidden-file scan found no `AGENTS.md`, `CLAUDE.md`, `CODEX.md`, `GEMINI.md`, `.cursorrules`, `copilot-instructions.md`, or matching instruction file.
- E-085 — 2026-08-05T16:57:45+0200 — Applied only the authenticated rolling manifest for recovery. The feature worktree canonical path, linked-worktree registration, branch, HEAD `a1427fef2ed34d37d889f16567c826cfa3b674a1`, Git admin/common directories, clean index, complete nine-path dirty inventory, every recorded status/type/mode/size/raw SHA-256, NUL-status digest `e4dc4eced99157bb454e8bddad1fb5a0c1c877d2b29a2d64376260a1755bb5a9`, and tracked binary-diff digest `cd9e961c131ef371e808dff6ca11e5bfc98c0fbd86167be8219fb4f562b905e9` matched exactly. Starting HEAD `7f17aaca11bc6228bed48b9265d63b9e576cdea7` remains an ancestor through the four named checkpoints. Recovery passed before this append and `State: IN_PROGRESS` remains correct.
- E-086 — 2026-08-05T16:57:45+0200 — Independently reverified the rolling manifest's main-checkout record without editing it: canonical path and linked topology, `main` at `7f17aaca11bc6228bed48b9265d63b9e576cdea7`, clean index, complete three-path `.playwright-mcp` inventory, every recorded status/type/mode/size/raw SHA-256, NUL-status digest `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`, and empty tracked binary-diff digest matched exactly.

## Fifth-checkpoint ruling — coordinated verified disarm

The coherent scope for this invocation is the non-sleep restoration coordinator,
planned as `safety: coordinate verified disarm restoration`. Manual disarm,
failed-arm compensation, cutoff, and application termination now converge on a
UUID-identified recovery generation. A generation cannot complete until all
tracked arm calls have settled, the helper strictly proves restoration, and a
separate fresh registry read independently proves the override OFF. Sleep
takeover invalidates a non-sleep generation before accepting late replies.

Force-sleep authorization is committed once before suspension and is never
replayed after an ambiguous reply. Ordinary quit uses a separate final proof:
the first successful recovery pass advances the pending quit to a final-proof
phase, then a second helper disarm result and fresh independent OFF read are
required immediately before the single deferred termination reply. Cancellation
relinquishes the old generation and, when restoration can still be required,
starts a new non-quit recovery generation. Queueing and scheduled arming are
fenced while termination is pending.

This checkpoint deliberately does **not** close or claim:

- bounded XPC delivery, reply, or heartbeat timeouts, including a peer that
  accepts a request and never replies;
- repair-override, helper re-arm, orphan/reconciliation, and full uninstall
  quiescence paths that remain unstaged in `AppState.swift` and
  `HelperClient.swift`;
- `SessionStore` journal/history durability, stale-v4 or future-version recovery,
  or live helper restart/crash behavior;
- signed bundle identity, XPC trust, `SMAppService`, live arm/restore,
  force-sleep execution, quit behavior, sleep/wake, closed-lid hardware,
  notarization, release, or production readiness.

### Fifth-checkpoint finding and verification matrix

| ID | Invariant | Exact checkpoint evidence | Remaining boundary | Ruling |
| --- | --- | --- | --- | --- |
| S-12 | Every selected non-sleep restoration path shares one generation-safe completion gate | UUID generations, latched completion, cancellation transfer, arm-in-flight accounting, strict helper proof, and independent fresh registry-OFF proof are covered by 9 behavioral tests and the exact 204-test suite | XPC transport remains unbounded and no daemon fault injection or live registry proof was performed | CHECKPOINT VERIFIED OFFLINE — TRANSPORT/LIVE GATES OPEN |
| S-13 | Force sleep is authorized at most once and quit answers only after a distinct final proof | Pure gate tests cover one-shot force dispatch, ambiguous replies, final-proof transition, rejection, cancellation, and exactly-once completion; strict App compilation passes | No process was launched; real force-sleep and `NSApplication` termination were not exercised | CHECKPOINT VERIFIED OFFLINE — RUNTIME GATES OPEN |
| S-14 | Remaining recovery surfaces must not inherit this checkpoint's ruling | Partial staging leaves repair, re-arm, reconciliation/orphan, broader uninstall, helper-client, monitor, persistence-test, and design bytes outside the checkpoint | Those paths require separate root-cause review and a new authenticated rolling remainder | OPEN — SEPARATE CHECKPOINT REQUIRED |

- E-087 — 2026-08-05T17:51:40+0200 — Reviewed the complete nine-path rolling remainder and the complete diff against checkpoint HEAD. The preserved package was not accepted wholesale: repair-override, re-arm, orphan/reconciliation, broader uninstall, helper-client, monitor, persistence-test, and design work remain separate. The exact selected six-path code/test scope is the coordinated non-sleep restoration group above.
- E-088 — 2026-08-05T17:51:40+0200 — Rejected an initial source-shape-only regression as insufficient and added a pure behavioral coordinator first. The accepted RED `swift-test-nonsleep-gate-red.log` failed compilation because `NonSleepRestoreGate` and its generation/actions did not exist. After implementation, focused `swift-test-nonsleep-gate-green6.log` passed 9 tests covering stale generations, retry, zero-arm completion, independent evidence, one-shot force dispatch, quit final proof, rejection, cancellation, and the immediate-termination predicate.
- E-089 — 2026-08-05T17:51:40+0200 — Implemented UUID generation identity rather than an incrementing integer, one completion latch per generation, cancellation transfer, delayed retry after a rejected final proof, and strict two-source completion only after every in-flight arm settles. Manual disarm accepts both armed and arming states; failed-arm recovery uses the same coordinator unless strict restoration is already independently proven; sleep takeover cancels the non-sleep generation before late replies can act.
- E-090 — 2026-08-05T17:51:40+0200 — Termination now fails closed when the app-state provider is missing or the phase is arming, disarming, or unknown. The app sends exactly one deferred reply after awaiting the coordinator. Force-sleep dispatch is committed before suspension and ambiguous replies cannot replay it; ordinary quit requires the second final proof immediately before the terminal reply. The minimal staged uninstall guard prevents the selected coordinator path from uninstalling before disarmed state and a cleared pending action, while broader uninstall quiescence remains open.
- E-091 — 2026-08-05T17:51:40+0200 — Final dirty-tree verification passed 206 tests in 12 suites in `swift-test-nonsleep-restore-full-dirty-green.log`. The exact Git-index export passed 204 tests in 12 suites in `swift-test-nonsleep-exact-index.log`; the count difference is the deliberately unstaged `SmokeTests.swift` remainder. A stale source-contract assertion caused one earlier complete-suite failure and was corrected to assert the central coordinator fence without weakening the invariant; that failed output remains preserved.
- E-092 — 2026-08-05T17:51:40+0200 — The exact index passed Debug and Release `LidlessCore` builds and macOS 15 Swift 6 complete strict-concurrency App typechecking with warnings-as-errors. App, helper, and widget sources compiled and linked in Debug and optimized Release with `CODE_SIGNING_ALLOWED=NO`. All six products are thin arm64 Mach-O executables with only automatic linker ad-hoc signatures, no TeamIdentifier, no bound Info.plist, and no sealed resources. None was launched; these are identity-free compile/link results, not signed or runtime proof.
- E-093 — 2026-08-05T17:51:40+0200 — Exact-index `plutil -lint` and decoded inspection passed for app/widget Info plists and entitlements, helper launchd plist, and export options; relevant bundle identifiers, entitlement paths, deployment target, extension point, helper label/Mach service, and associated-app bindings were also checked in `project.yml` and `project.pbxproj`. `git diff --check` and `git diff --cached --check` passed. Xcode graph build/analyze was not retried after the already documented nested-sandbox failure and automatic LaunchServices side-effect risk.
- E-094 — 2026-08-05T17:51:40+0200 — Three independent adversarial reviews passed the scoped bytes after checking generation ABA resistance, cancellation/latching, sleep takeover, failed-arm and manual-disarm convergence, zero-arm completion, one-shot force dispatch, two-phase quit proof, and the immediate-termination fence. They retained bounded transport, session-store durability, repair/re-arm/reconciliation, broader uninstall, and live behavior as explicit open gates.
- E-095 — 2026-08-05T17:51:40+0200 — Final pre-commit main-checkout preservation passed exactly: canonical path and linked topology, `main` at `7f17aaca11bc6228bed48b9265d63b9e576cdea7`, clean index, empty tracked diff, all three `.playwright-mcp` modes/sizes/SHA-256 values, and NUL-status digest `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18` match the rolling authority. The main checkout was not edited.
- E-096 — 2026-08-05T17:51:40+0200 — The checkpoint is prepared under subject `safety: coordinate verified disarm restoration`. Because separately scoped recovery and design bytes remain unstaged, `State: IN_PROGRESS` is intentionally retained. The supervisor must bind the exact post-commit remainder into a fresh rolling manifest before another invocation.

## Sixth recovery audit — remaining recovery/support package

- E-097 — 2026-08-05T17:58:41+0200 — Read the canonical handoff, immutable starting-state manifest, rolling remainder manifest and adjacent sidecar, progress log, decision log, architecture, design-reset brief, and this ledger in full. The canonical handoff and immutable manifest matched their supplied SHA-256 values. The sidecar-recorded rolling-manifest SHA-256 `fe6f1029290a29a07b59fe22a8e3a3ad7c154f1e06199ade357bb5fa89169cb9` matched the manifest bytes. A repository scan found no `AGENTS.md`, `CLAUDE.md`, `CODEX.md`, or matching instruction file.
- E-098 — 2026-08-05T17:58:41+0200 — Applied only the authenticated rolling manifest for recovery. The feature worktree canonical path, linked-worktree registration, branch, HEAD `027d1934561ac8966efac1afeb91903f86ab2675`, Git admin/common directories, clean index, complete eight-path dirty inventory, every recorded status/type/mode/size/raw SHA-256, NUL-status digest `86ed26322d616187a720fa7c97b9ddc99929e847d3f559951422a4dcd1b12f53`, and tracked binary-diff digest `b33795897c1c3dd98dc47deb6f2fe4ec1620d4c166f3648d25bf07c6b62d2e14` matched exactly. Starting HEAD `7f17aaca11bc6228bed48b9265d63b9e576cdea7` remains the recorded baseline. One preliminary read-only inventory loop shadowed zsh's special `path` parameter, so its apparent command-not-found output was invalid and discarded; it changed no files. The corrected independent loop produced the exact result recorded here.
- E-099 — 2026-08-05T17:58:41+0200 — Independently reverified the rolling manifest's main-checkout record without editing it: canonical path and linked topology, `main` at `7f17aaca11bc6228bed48b9265d63b9e576cdea7`, clean index, complete three-path `.playwright-mcp` inventory, every recorded status/type/mode/size/raw SHA-256, NUL-status digest `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`, and empty tracked binary-diff digest matched exactly. Recovery passed before this ledger append and `State: IN_PROGRESS` remains correct.

## Sixth-checkpoint ruling — terminate on lost arm proof

The coherent scope for this invocation is terminal recovery when an arm request
or established session loses current helper/registry proof, planned as
`safety: terminate sessions on lost arm proof`. A helper interruption,
ineligible helper transition, heartbeat failure or non-proof reply, and a fresh
registry observation that contradicts an armed session now invalidate proof,
clear queued intent, suppress the current schedule occurrence, and enter the
existing generation-bound restore coordinator. No path automatically re-arms
after lost proof. A per-task heartbeat generation fences local effects from a
reply that resumes after its task or session was replaced.

The outside-override concession is deliberately narrower than restoration. A
never-established arm request may stop compensating mutations only when the
exact current helper reports no owned session or pending recovery, every
tracked arm request has settled, and an independent fresh registry read shows
the override ON. An established session cannot use that concession; its
ownership is causally ambiguous and normal sleep must still be proven. Arm,
restore, and outside-ownership proof now require the exact protocol version,
so unknown future helpers fail closed. Established proof loss receives the
durable, user-visible history reason `helperProofLost`.

This checkpoint deliberately does **not** close or claim:

- bounded XPC delivery/reply/heartbeat timeouts, transport cancellation, or a
  session token that prevents an already-dispatched stale remote call;
- stale-v4 recovery, launch reconciliation, repair-override, or complete
  uninstall quiescence;
- the separately preserved monitor, smoke-test, orchestration, and design
  remainder, or release-verifier writable-mode/special-node follow-up;
- signed bundle identity, XPC runtime trust, `SMAppService`, live arm/restore,
  helper crash/restart, sleep/wake, closed-lid hardware, notarization, release,
  or production readiness.

### Sixth-checkpoint finding and verification matrix

| ID | Invariant | Exact checkpoint evidence | Remaining boundary | Ruling |
| --- | --- | --- | --- | --- |
| S-15 | Lost arm proof is terminal and cannot authorize automatic re-arm | Exact-version policy tests plus source-contract regressions cover helper interruption, heartbeat failure/non-proof, registry contradiction, helper ineligibility during armed/arming, schedule suppression, and removal of the re-arm implementation | App integration coverage is structural; no real XPC interruption, heartbeat stall, registry event, or sleep/wake was exercised | CHECKPOINT VERIFIED OFFLINE — TRANSPORT/LIVE GATES OPEN |
| S-16 | A failed, never-established arm does not seize a proven external override | Pure policy/gate tests require exact helper non-ownership, no pending recovery, zero in-flight arms, fresh independent ON evidence, current generation ownership, and no established session | Cross-process registry/`pmset` ownership is not atomic; legacy/orphan recovery remains separate | CHECKPOINT VERIFIED OFFLINE — OWNERSHIP/LIVE GATES OPEN |
| S-17 | Unknown future protocol versions cannot prove arm, restore, or outside ownership | Focused policy tests reject helper version `current + 1`; client readiness requires exact equality; strict compile passes | A safe legacy-v4 recovery mechanism is still absent | CHECKPOINT VERIFIED OFFLINE — LEGACY RECOVERY OPEN |
| V-06 | Exact code authority passes complete tests and compile/static checks | Git-index export tree `a96def0a1ff125c8a954b92429e43e27184ea86c` passed 212 tests in 13 suites, Debug/Release core builds, strict App typecheck, and direct Debug/Release app/helper/widget links | Xcode's package-manifest nested sandbox cannot run in this managed environment | PASS FOR EXACT OFFLINE CODE — XCODE GRAPH OPEN |
| V-07 | Artifact/config evidence is not overstated as signed bundle proof | All six direct outputs are arm64 Mach-O with linker ad-hoc signatures only, no TeamIdentifier, no bound Info.plist, sealed resources, or entitlements; source plists/entitlements and project bindings lint/decode correctly | No signed or Xcode-produced bundle was created, launched, or validated | PARTIAL — SIGNED BUNDLE GATE OPEN |

- E-100 — 2026-08-05T18:36:24+0200 — Reviewed the complete eight-path rolling remainder and the complete diff against checkpoint HEAD before selecting this scope. The initial dirty authority passed 206 tests in 12 suites in `swift-test-sixth-baseline.log` (SHA-256 `e4c1534bfc624ebc15cd71b1248be0b17c838ec3c2f3e2e7ae28a1a7e520f1be`). Repair, launch reconciliation, uninstall, monitors, smoke-test, orchestration, and design bytes were not accepted into this checkpoint.
- E-101 — 2026-08-05T18:36:24+0200 — Added the lost-proof policy regression before implementation. `swift-test-arm-loss-red.log` failed compilation because `failedArmDisposition` did not exist; `swift-test-proof-loss-external-red2.log` later failed because the truthful `helperProofLost` reason and terminal integration did not exist. The accepted implementation adds exact-version arm/restore/ownership proof, the narrow never-established external-override completion gate, and the durable history reason.
- E-102 — 2026-08-05T18:36:24+0200 — Adversarial iterations exposed three additional integration defects before acceptance: a thrown failed arm could retry forever over an outside override, manual/terminal recovery could immediately re-enter the same schedule window, and helper eligibility could change while arm proof was in flight. Corresponding RED/GREEN logs are `swift-test-failed-arm-external-liveness-{red,green}.log`, `swift-test-manual-arming-schedule-{red,green}.log`, and `swift-test-inflight-eligibility-{red,green}.log`.
- E-103 — 2026-08-05T18:36:24+0200 — Final focused integration verification passed 15 tests in 2 suites in `swift-test-inflight-eligibility-integrated-green.log` (SHA-256 `b49e883b0a19bef1b07e59d567bf809c5a08b1a732d16396f8e2a1b3428b1319`). The policy/gate tests are behavioral; AppState integration assertions are source-structural and are not represented as runtime proof.
- E-104 — 2026-08-05T18:36:24+0200 — The complete dirty remainder tree passed 214 tests in 13 suites in `swift-test-sixth-dirty-final5.log` (SHA-256 `5291aeed69b7344f641771cd0f3bc9fb0d7f2a7dc5391c280e35bf7346f4b767`). The exact selected Git-index export passed 212 tests in 13 suites in `swift-test-sixth-exact-final.log` (SHA-256 `0351c9aad8569020bc109209fa2754cf87f82903ba4653a35cbcef2513c42484`). The two-test difference is the deliberately unstaged `SmokeTests.swift` remainder.
- E-105 — 2026-08-05T18:36:24+0200 — The pre-ledger exact code index tree is `a96def0a1ff125c8a954b92429e43e27184ea86c`; its staged binary-diff SHA-256 is `8dfb2ad16a94d413f7d034350d39e9d82b125b063508fa5f393de00d2bf9dd4f`. The immutable export used for exact verification is `sixth-exact-code-final.HEjUwY` under the ignored local verification directory.
- E-106 — 2026-08-05T18:36:24+0200 — Exact Debug and Release `LidlessCore` builds passed. Exact App sources passed macOS 15 Swift 6 complete strict-concurrency typechecking with warnings-as-errors. Exact app, helper, and widget sources compiled and linked in Debug and optimized Release with `CODE_SIGNING_ALLOWED=NO`; complete outputs are preserved in `swift-build-core-*-sixth-exact-final.log`, `swiftc-app-typecheck-sixth-exact-final.log`, and `direct-all-products-*-sixth-exact-final.log`. No product was launched.
- E-107 — 2026-08-05T18:36:24+0200 — `artifact-inspection-sixth-exact-final.log` (SHA-256 `afc1ebf125054b0ea1dc20de36e640ae636d555a15fcb1c97617a8688d074dc6`) records file type, architecture, linkage, build-version load commands, hashes, code-sign metadata, plist/entitlement lint and decode, and relevant project bindings. Every direct executable is only automatic linker ad-hoc code with no TeamIdentifier, bound Info.plist, sealed resources, or entitlements. This is identity-free compile/link evidence, not signed bundle or runtime trust evidence.
- E-108 — 2026-08-05T18:36:24+0200 — Project-native unsigned Debug and Release attempts were redirected to isolated DerivedData/package/module-cache paths. Initial attempts failed before compilation on forbidden user-cache writes; a retry with all discoverable caches redirected reached SwiftPM but failed because the managed outer sandbox prohibits nested `sandbox-exec`. Complete failures are preserved in `xcodebuild-{debug,release}-sixth-exact-final.log` and `xcodebuild-debug-sixth-exact-final-retry.log`. No sandbox bypass, app launch, helper action, or project mutation was attempted.
- E-109 — 2026-08-05T18:36:24+0200 — Three independent adversarial reviews passed the final scoped bytes. Review covered the heartbeat local-generation fence, no-auto-rearm invariant, failed-arm external liveness, established-session exclusion, exact-version policy, in-flight helper-eligibility race, schedule suppression, and truthful history. Reviewers retained already-dispatched remote XPC effects, bounded transport/session tokens, legacy recovery, launch reconciliation, uninstall, monitor lifecycle, and live behavior as explicit open gates.
- E-110 — 2026-08-05T18:37:30+0200 — Final pre-commit main-checkout preservation passed exactly: canonical path and linked topology, `main` at `7f17aaca11bc6228bed48b9265d63b9e576cdea7`, clean index, empty tracked binary diff, complete three-path `.playwright-mcp` inventory, every recorded mode/size/SHA-256, and NUL-status digest `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18` match the rolling authority. The main checkout was not edited.
- E-111 — 2026-08-05T18:37:57+0200 — Reviewed every staged source, test, documentation, and ledger hunk. Exactly 12 paths form this checkpoint; partial staging in `AppState.swift` and `HelperClient.swift` excludes repair, launch reconciliation, uninstall, monitor, smoke-test, orchestration, and design work. Both complete-tree and staged `git diff --check` passed. The checkpoint is prepared under subject `safety: terminate sessions on lost arm proof`. Because the eight-path remainder still requires separate review, `State: IN_PROGRESS` is intentionally retained and the supervisor must bind the exact post-commit remainder into a fresh rolling manifest before another invocation.

## Seventh recovery audit — remaining recovery/support package

- E-112 — 2026-08-05T18:43:22+0200 — Read the canonical handoff, immutable starting-state manifest, rolling remainder manifest and adjacent sidecar, progress log, decision log, architecture, design-reset brief, and the checkpoint ledger. The canonical handoff SHA-256 `95bdacdde663c642c2f97d532c1ec2b931e94a7dfcda47b8031e011ab3944831` and immutable-manifest SHA-256 `d84065171a261e24ae574b98164132472ff1e8bb635647403d814b9fcf58c36a` matched their supplied values. The sidecar-recorded rolling-manifest SHA-256 `7d9e5d3c3c49ff07bd1b91f0fab39d91a1b1c870d7e436e35434858da456020d` matched the manifest bytes. A repository scan found no `AGENTS.md`, `CLAUDE.md`, `CODEX.md`, `INSTRUCTIONS.md`, `.cursorrules`, or `*.instructions.md` file.
- E-113 — 2026-08-05T18:43:22+0200 — Applied only the authenticated rolling manifest for recovery. The feature canonical path, linked-worktree topology, branch, HEAD `90208fab0ad0238499639d0dd7ef4c598397e7a0`, Git admin/common directories, clean index, complete eight-path dirty inventory, every recorded status/type/mode/size/raw SHA-256, NUL-status digest `86ed26322d616187a720fa7c97b9ddc99929e847d3f559951422a4dcd1b12f53`, and tracked binary-diff digest `c46d67f13934bb69d357de4682d820d3df133b4c180573136bac8e2a2c6b8536` matched exactly. One preliminary read-only inventory loop shadowed zsh's special `path` and `status` parameters; it changed no files and its output was discarded. The corrected independent Bash loop produced the exact inventory result.
- E-114 — 2026-08-05T18:43:22+0200 — Independently reverified the rolling manifest's main-checkout record without editing it: canonical path and linked topology, `main` at `7f17aaca11bc6228bed48b9265d63b9e576cdea7`, clean index, complete three-path `.playwright-mcp` inventory, every recorded status/type/mode/size/raw SHA-256, NUL-status digest `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`, and empty tracked binary-diff digest matched exactly. Recovery passed before any product-source edit and `State: IN_PROGRESS` remains correct.
- E-115 — 2026-08-05T18:43:22+0200 — The initial post-gate ledger-creation patch treated this already tracked checkpoint ledger as absent and temporarily replaced its working-tree copy. No product source, index, commit, or main-checkout byte was affected. Before package review continued, the exact 498-line HEAD ledger was restored and this disclosure was appended; prior false-stop evidence, corrections, matrices, and E-001 through E-111 remain byte-for-byte intact.

## Seventh-checkpoint ruling — fence delayed force-sleep authorization

The preserved helper-removal package is not coherent enough to checkpoint.
This invocation therefore selects one narrower root cause: a delayed
`pmset sleepnow` follow-up must not survive an intervening helper or system
lifecycle transition, must expire promptly, and must re-establish physical
authorization immediately before mutation. The checkpoint is planned as
`safety: fence delayed force-sleep authorization`.

The helper now captures an unguessable lifecycle generation only after strict
restore proof. Every valid arm, disarm, repair, uninstall, and root-power
message advances that generation. After the nominal three-second delay, the
same serial queue reads the clamshell and `SleepDisabled` states, captures the
post-read monotonic time, and authorizes `sleepnow` only when the generation is
unchanged, the request is at most five seconds old, no sentinel or pending
restore exists, power-event observation was successfully installed, the
clamshell is still closed, and the override is definitely OFF. Protocol 6
prevents an app that requires this behavior from accepting an older helper.

This checkpoint deliberately does **not** close or claim:

- idempotent uninstall handling for every `SMAppService` state, bounded XPC
  delivery/reply timeouts, or mutual exclusion among uninstall, install,
  repair, termination, and reconciliation;
- a restart-durable uninstall latch, stale-client refresh fencing, transactional
  scheduled-wake ownership, complete helper cleanup postconditions, or a safe
  retry contract after partial cleanup;
- acceptance of the preserved AppState, HelperClient, monitor, SetupPane,
  removal-policy, smoke-test, orchestration, or design bytes. Those remain
  unstaged, including copy shaped under the design doctrine but not visually
  validated because launching the app is prohibited;
- a project-native Xcode bundle, Developer ID identity, signed XPC trust,
  `SMAppService` behavior, live `pmset`, real sleep/wake, closed-lid hardware,
  crash/restart recovery, notarization, release, or production readiness.

### Seventh-checkpoint finding and verification matrix

| ID | Invariant | Exact checkpoint evidence | Remaining boundary | Ruling |
| --- | --- | --- | --- | --- |
| S-18 | A delayed force-sleep request cannot cross a later helper/system lifecycle transition | Pure UUID-generation policy tests plus exact helper source-order assertions cover arm, disarm, repair, uninstall, root-power messages, and nil-active-nil ABA | No real XPC, IOKit power event, lid transition, or `pmset sleepnow` was exercised | CHECKPOINT VERIFIED OFFLINE — LIVE GATE OPEN |
| S-19 | Physical authorization is fresh and fail-closed immediately before `sleepnow` | Pure boundary tests reject expired/reversed monotonic time, missing power observation, open/unknown lid, ON/unknown override, sentinel, and pending restore; source ordering requires reads, post-read timestamp, authorization, then mutation on the serial queue | Registry and `pmset` reads are not a hardware proof and their operating-system semantics remain external | CHECKPOINT VERIFIED OFFLINE — HARDWARE GATE OPEN |
| S-20 | An app requiring the delayed-sleep fence cannot accept the prior helper behavior | Exact index sets `helperVersion` to 6 and updates its protocol regression; current client eligibility logic already requires exact equality | No live helper replacement, registration, or stale-version recovery was performed | CHECKPOINT VERIFIED OFFLINE — REGISTRATION GATE OPEN |
| V-08 | Exact selected code passes complete tests and strict compile/link checks | Pre-ledger Git-index tree `97da4bc1e5885dc59d0c3550c79f61b1eda9e239` passed 215 tests in 14 suites, Debug/Release core builds, strict all-product typechecking, and direct Debug/Release app/helper/widget links | Project-native Xcode graph remains blocked by the managed outer sandbox's rejection of nested SwiftPM `sandbox-exec` | PASS FOR EXACT OFFLINE CODE — XCODE GRAPH OPEN |
| V-09 | Artifact/config evidence is bounded to what was actually inspected | Six direct arm64 outputs, all source plist/entitlement files, `project.yml`, and `project.pbxproj` were inspected; direct outputs have only linker ad-hoc signatures, no team, bound Info.plist, or sealed resources | No signed or Xcode-produced application/helper/widget bundle exists for positive trust validation | PARTIAL — SIGNED BUNDLE GATE OPEN |

- E-116 — 2026-08-05T19:28:44+0200 — Reviewed the complete rolling remainder and diff against checkpoint HEAD before accepting any preserved claim. The initial authority passed 214 tests in 13 suites in `swift-test-seventh-baseline.log` (SHA-256 `48d52d0e1e61fdb73c12468b3b260f9e0af2ef1c499a7f0c097384b3b1f205e1`). Review split helper removal from the delayed-force-sleep race; no pre-existing removal claim was accepted merely because its tests passed.
- E-117 — 2026-08-05T19:28:44+0200 — Added removal regressions before implementation and reached a 221-test/15-suite complete working-tree pass in `swift-test-seventh-working-final2.log` (SHA-256 `511e3d1a3f01669de365f486713bbbcfebbb5ec60db82fe5e62ea3c23cb1b8f5`). Three adversarial reviews nevertheless rejected that package for non-idempotent `.notRegistered` handling; termination/install/repair exclusion gaps; restart and stale-refresh latch gaps; transactional wake-ledger loss; incomplete cleanup postconditions and scope claims; unbounded XPC waits; and unclear partial helper-cleanup retry behavior. Those bytes and tests remain unstaged evidence, not checkpoint authority. The first complete working-tree attempt also failed a stale structural assertion; its output remains preserved and is not counted.
- E-118 — 2026-08-05T19:28:44+0200 — Selected the independently separable delayed-force-sleep ABA/freshness defect. The first RED setup used an unusable module-cache arrangement and is discarded. The corrected RED `swift-test-delayed-sleep-red-corrected.log` (SHA-256 `46f4af0755db72945326673390d9dfc000cae6b504d4523759db6176a5051c7f`) failed compilation because `DelayedSleepSafety` did not exist, establishing the old-code failure before production implementation.
- E-119 — 2026-08-05T19:28:44+0200 — Implemented the pure bounded authorization gate, UUID lifecycle generation, fail-closed power-observer availability, fresh clamshell/override reads, and serial-queue ordering. The uninstall hunk is limited to `advanceLifecycle()` because a valid uninstall must invalidate an already queued `sleepnow`; none of the broader removal latch, cleanup, or UI behavior is staged. Bumped the helper behavior protocol from 5 to 6 and updated its exact regression and architecture wording.
- E-120 — 2026-08-05T19:28:44+0200 — Final focused GREEN passed 3 tests in 1 suite in `swift-test-delayed-sleep-green4.log` (SHA-256 `ad2f9b237cb3526b3fa94fc07394cce3373c8ece36990594da8e46960c43b4f7`). Behavioral coverage includes generation, quiescence, observer availability, both physical readbacks, exact deadline acceptance, overdue rejection, and clock reversal; structural integration coverage enforces invalidation sites and relative read/authorization/mutation order. Structural coverage is not represented as runtime proof.
- E-121 — 2026-08-05T19:28:44+0200 — The final complete dirty working tree passed 221 tests in 15 suites, while the immutable pre-ledger Git-index export passed 215 tests in 14 suites in `swift-test-seventh-staged-final.log` (SHA-256 `abff27121efe3b666ea793a946043d9990fbe7ac1cb04e173aeff393905a9bd2`). The six-test/one-suite difference is deliberately unstaged helper-removal coverage. The exact selected code tree is `97da4bc1e5885dc59d0c3550c79f61b1eda9e239`; its staged binary-diff SHA-256 before this ledger append is `28504da3795d14d647ff70d3b79d6b98250c0ea0c664022ee7fc95a51ed04971`.
- E-122 — 2026-08-05T19:28:44+0200 — Exact-index Debug and Release `LidlessCore` builds passed (`6ea11f88d988005a78e5fc2bbf25119a9bcaabd04e18436efbed6c606bbc777b`, `5a4a2aa202fcf9ec2d629c66b9525649d51a566b4268611580002c591efab9c5`). Exact app, helper, and widget sources passed macOS 15, Swift 6 complete strict-concurrency typechecking with warnings-as-errors (`e0fa178f0e74b347216ee9c964f5dba119aad9f59377ae36b490ac7703bdb229`).
- E-123 — 2026-08-05T19:28:44+0200 — With `CODE_SIGNING_ALLOWED=NO`, exact app, helper, and widget sources compiled and linked in Debug and optimized Release (`direct-all-products-debug-seventh-staged.log`, SHA-256 `4b55e7d90bb5555b7e8915fddc05bcc80eb6ab70d7cdc72ac4e415bef6999de8`; Release SHA-256 `70d50131c9007985fbc2c5d2e3e81f0acd0d5e4c7c500712e414bf5430b76966`). The macOS arm64 linker automatically ad-hoc-signed the six unbundled executables; none has a TeamIdentifier, bound Info.plist, sealed resources, or displayed entitlements. No product was launched.
- E-124 — 2026-08-05T19:28:44+0200 — `staged-artifact-config-inspection-seventh.log` (SHA-256 `bb41f27b175e2be7e275bad547852edd3462d3155e741054113ee698b102fbec`) records file type, build-version load commands, ad-hoc signature metadata, and successful lint/decoded inspection of app/widget Info plists and entitlements, the helper launchd plist, and export options, plus relevant source/generated project bindings. The direct outputs are unbundled compile/link artifacts; no actual Xcode app bundle was available to inspect. Project-native Xcode build/analyze was not retried after the already reproduced nested-sandbox failure and automatic LaunchServices side-effect risk.
- E-125 — 2026-08-05T19:28:44+0200 — The first attempt to isolate only the helper hunk used an overly permissive zero-context cached patch and inserted lines at wrong index positions. Immediate staged-diff review detected it; `git restore --staged Helper/HelperDaemon.swift` removed only that invalid index state, leaving the working tree untouched. The exact helper index blob was then rebuilt from checkpoint HEAD with the reviewed transformations and reverified by full staged diff, exact-index tests, builds, typecheck, and three scoped reviews. No invalid index was committed.
- E-126 — 2026-08-05T19:28:44+0200 — Three independent read-only adversarial reviews found no remaining blocker in the final delayed-sleep scope after requiring UUID identity, observer availability, a five-second monotonic freshness bound, post-read timestamping, exact clamshell/override evidence, ordering assertions, and uninstall-generation invalidation. They confirmed that broader removal guards are excluded and retain every removal, transport, registration, and live gate listed above.
- E-127 — 2026-08-05T19:28:44+0200 — Both unstaged and staged `git diff --check` passed; complete output is `git-diff-check-seventh-precommit.log`. Pre-commit main-checkout preservation passed exactly in `main-preservation-seventh-precommit.log`: canonical path and topology, `main` at `7f17aaca11bc6228bed48b9265d63b9e576cdea7`, clean index, empty tracked diff, complete three-path `.playwright-mcp` inventory with the recorded modes/sizes/SHA-256 values, and NUL-status digest `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`. The main checkout was not edited.
- E-128 — 2026-08-05T19:28:44+0200 — The checkpoint is prepared under subject `safety: fence delayed force-sleep authorization`. Exactly the six reviewed code/test/documentation paths plus this append-only ledger are selected; all helper-removal, AppState, HelperClient, monitor, SetupPane, smoke-test, orchestration, and design remainder stays unstaged. `State: IN_PROGRESS` is intentionally retained. After the single local commit, the supervisor must bind the exact remaining tree into a fresh rolling manifest before another invocation.

## Eighth recovery audit — remaining removal/support package

- E-129 — 2026-08-05T19:35:02+0200 — Read the canonical handoff, immutable starting-state manifest, rolling remainder manifest and adjacent sidecar, progress log, decision log, architecture, design-reset brief, and this ledger in full. The canonical handoff SHA-256 `95bdacdde663c642c2f97d532c1ec2b931e94a7dfcda47b8031e011ab3944831` and immutable-manifest SHA-256 `d84065171a261e24ae574b98164132472ff1e8bb635647403d814b9fcf58c36a` matched their supplied values. The sidecar-recorded rolling-manifest SHA-256 `5e78865e937c2b463d6b1da3f27d158c4ee179310e24401849f46665ead227ad` matched the manifest bytes. A repository scan found no `AGENTS.md`, `CLAUDE.md`, or similarly named instruction file.
- E-130 — 2026-08-05T19:35:02+0200 — Applied only the authenticated rolling manifest for recovery. The feature canonical path, linked-worktree topology, branch, HEAD `ff6ece4cefd8d312525e8abead7bc760db80eea1`, Git admin/common directories, clean index, complete 13-path dirty inventory, every recorded status/type/mode/size/raw SHA-256, NUL-status digest `7b6479eddba2f04883948c3c8c1a2d3ee6649f6707f6226b8f5d73c3962baa76`, and tracked binary-diff digest `30cfd5489a74be2840e14485a0c799ab953437edf10ea20a67477bcad5d49327` matched exactly. Starting HEAD `7f17aaca11bc6228bed48b9265d63b9e576cdea7` remains an ancestor through the seven named checkpoint commits. One preliminary read-only Bash comparison incorrectly escaped a substring expression and therefore falsely labeled only the status column; it changed no files. The corrected comparison passed all fields.
- E-131 — 2026-08-05T19:35:02+0200 — Independently reverified the rolling manifest's main-checkout record without editing it: canonical path and linked topology, `main` at `7f17aaca11bc6228bed48b9265d63b9e576cdea7`, clean index, complete three-path `.playwright-mcp` inventory, every recorded status/type/mode/size/raw SHA-256, NUL-status digest `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`, and empty tracked binary-diff digest matched exactly. Recovery passed before this ledger append and `State: IN_PROGRESS` remains correct.
- E-132 — 2026-08-05T19:38:55+0200 — Reproduced the complete preserved dirty-package baseline before accepting any remainder claim. Stable Xcode 26.5's Swift 6.3.2 toolchain passed 222 tests in 15 suites with writable build/module caches isolated under the ignored verification directory and SwiftPM's nested sandbox disabled. Complete output is `swift-test-eighth-baseline.log` (SHA-256 `807ec627691db14382909b106811d9898bc6ac02bab38fa155e5242465653b17`). The pass establishes only the current test baseline; the removal suite's source-shape assertions and known transaction gaps still require independent review.
- E-133 — 2026-08-05T20:53:53+0200 — Account-switch recovery reverified the sealed recovery pack, feature branch/HEAD, clean index, and main-checkout preservation before resuming. The `5e78865e…` rolling manifest's 13 recorded remainder paths still match their exact statuses, types, modes, sizes, and raw SHA-256 values. The sole additional dirty path is this tracked append-only ledger, changed by E-132 after the prior manifest was generated and before the founder's usage-pause interrupted the worker. No product-source byte changed during the pause. The coordinator will now generate a fresh rolling manifest binding the exact 13-path remainder plus this ledger before restarting exactly one writer and one read-only watchdog.

## Ninth recovery audit — authenticated removal/support remainder

- E-134 — 2026-08-05T20:57:03+0200 — Read the canonical handoff, immutable starting-state manifest, rolling remainder manifest and adjacent sidecar, progress log, decision log, architecture, design-reset brief, and this append-only ledger in full. The canonical handoff SHA-256 `95bdacdde663c642c2f97d532c1ec2b931e94a7dfcda47b8031e011ab3944831` and immutable-manifest SHA-256 `d84065171a261e24ae574b98164132472ff1e8bb635647403d814b9fcf58c36a` matched their supplied values. The sidecar-recorded rolling-manifest SHA-256 `e572b3f7a92e4288d09575cbbb827dd68c0182113cff38cdd7e4a4b193a42906` matched the manifest bytes. A hidden-file scan found no `AGENTS.md`, `CLAUDE.md`, `CODEX.md`, `INSTRUCTIONS.md`, or `copilot-instructions.md` file.
- E-135 — 2026-08-05T20:57:03+0200 — Applied only the authenticated rolling manifest as recovery authority. The feature canonical path, two-worktree linked topology, branch, HEAD `ff6ece4cefd8d312525e8abead7bc760db80eea1`, Git admin/common directories, clean index, complete 14-path dirty inventory, every recorded status/type/mode/size/raw SHA-256, NUL-status digest `2eaa2af46d4ef4362c97b37141883e26299f8d4166b4c6e361d8357bbfb1189b`, and tracked binary-diff digest `f806515eebc5eb6e49d798bc403d9c9f3205defcdb46893a78c2a0efedead909` matched exactly. Starting HEAD `7f17aaca11bc6228bed48b9265d63b9e576cdea7` remains an ancestor through the seven named checkpoint commits. A first hash command omitted its positional shell argument, and a later metadata loop used zsh's read-only `status` variable; both read-only probes were discarded, changed no file, and were rerun correctly before this append.
- E-136 — 2026-08-05T20:57:03+0200 — Independently reverified the rolling manifest's main-checkout record without editing it: canonical path and linked topology, `main` at `7f17aaca11bc6228bed48b9265d63b9e576cdea7`, clean index, complete three-path `.playwright-mcp` inventory, every recorded status/type/mode/size/raw SHA-256, NUL-status digest `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`, and empty tracked binary-diff digest matched exactly. Recovery passed before this ledger append; the top-level `State: IN_PROGRESS` is correct.

## Ninth-checkpoint ruling — reconcile scheduled-wake replies

The preserved removal/support package is still not coherent enough to accept as
one checkpoint. This invocation therefore selects one independently bounded
root cause: the app previously wrote its scheduled-wake cache before XPC
completion and discarded the helper's `ok` value. An explicit helper rejection
could consequently suppress an equivalent retry as though the request had
succeeded.

The selected repair makes `HelperClient.scheduleWake` reject an explicit
negative `HelperReply`, and replaces the optimistic app cache with a
process-local reducer. Only a matching positive reply can establish local
non-provisional evidence. Explicit rejection returns the desired value to a
retryable state. Superseded or invalidated request identities remain tracked
until their exactly-once client completion, pre-dispatch stale tasks are
discarded, stale completions taint newer evidence, and completed transport
uncertainty leaves one bounded sticky ordering hazard instead of an unbounded
set of failure identities. A changed desired value may supersede an older
app-local request so the app can attempt changed intent.

This checkpoint deliberately does **not** claim authoritative helper or RTC
state. The current helper still suppresses scheduled-wake cancellation and
ledger-persistence errors; successful reply order does not prove remote
mutation order; XPC calls have no timeout or cancellation; a dispatched call
that never replies can retain a task/identity indefinitely; equivalent intent
can remain suppressed after provisional success; and the reducer and its
uncertainty marker do not survive app restart. Changed intent bypasses only the
app-local gate and can still wait behind helper serialization or `pmset`.
`notInstalled` and `badProxy` are conservatively treated as uncertain even when
they may be known pre-dispatch, which is a bounded liveness false negative and
not remote-state proof.

The broader preserved removal package remains rejected because it still lacks
a behavior-protocol fence for the proposed uninstall contract, bounded XPC
delivery/reply waits, verified idempotence for `.notRegistered`, a verified
inactive post-unregister condition, restart-durable client/helper latches,
serialization across uninstall/install/repair/reconciliation/termination,
transactional wake cancellation and persistence, fresh post-cleanup status,
safe partial-cleanup retry semantics, and complete error propagation. Its
monitor, SetupPane, smoke-test, orchestration, and design-reset bytes are also
outside this checkpoint; no UI or design verdict was produced.

### Ninth-checkpoint finding and verification matrix

| ID | Invariant | Exact checkpoint evidence | Remaining boundary | Ruling |
| --- | --- | --- | --- | --- |
| S-21 | Dispatch or an explicit negative helper reply cannot be cached as scheduled-wake success | `HelperClient` checks `HelperReply.ok`; the App reducer commits only `.confirmed`, retries `.rejected`, and source-order tests bind current-check/discard/dispatch/outcome ordering | Helper `ok` is acceptance evidence only because cancellation/persistence errors are still suppressed | CHECKPOINT VERIFIED OFFLINE — HELPER TRANSACTION GATE OPEN |
| S-22 | Stale or uncertain completions cannot falsely confirm newer app-local intent | Pure reducer tests cover current/stale success order, supersession, invalidation, undispatched cleanup, repeated current uncertainty, stale uncertainty, bounded completed-failure tracking, and provisional evidence | Remote call/mutation ordering has no generation token; never-replying calls remain unbounded; state is process-local | CHECKPOINT VERIFIED OFFLINE — TRANSPORT/RESTART GATES OPEN |
| S-23 | Changed intent is not blocked solely by an older app-local request | Reducer tests prove changed desired work can be issued while an older identity remains tracked, and the App rechecks currency immediately before its async client call | The check is not atomic with XPC dispatch and helper serial execution can still block | CHECKPOINT VERIFIED OFFLINE — REMOTE LIVENESS GATE OPEN |
| V-10 | Exact selected code passes complete tests and strict compile/link checks | Pre-ledger Git-index tree `fd3f8a3297048735f0e01368ee48be065ad79311` passed 10 focused tests, 225 tests in 15 suites, Debug/Release core builds, strict App typechecking, and direct Debug/Release app/helper/widget links | Project-native Xcode build/analyze was not retried after the established nested-sandbox and LaunchServices side-effect constraints | PASS FOR EXACT OFFLINE CODE — XCODE GRAPH OPEN |
| V-11 | Artifact/config inspection remains bounded to observed bytes | Six exact arm64 direct outputs, source plists/entitlements, export options, identity constants, CI signing setting, `project.yml`, and `project.pbxproj` were inspected | Direct outputs are loose linker-ad-hoc executables with no team, bound Info.plist, sealed resources, or displayed entitlements; no Xcode-produced or signed bundle exists | PARTIAL — SIGNED BUNDLE GATE OPEN |

- E-137 — 2026-08-05T21:39:27+0200 — Reproduced the complete authenticated dirty-package baseline before accepting any preserved remainder claim. Stable Xcode 26.5 passed 222 tests in 15 suites in `swift-test-ninth-baseline.log` (SHA-256 `d6ecf4fbbf89d35427a9fd02a8d70ed1a9c1c961b0d0498fa1d7fe35382a458b`). That pass was treated only as a baseline; structural tests did not waive the removal transaction defects.
- E-138 — 2026-08-05T21:39:27+0200 — Reviewed the complete 14-path remainder and traced the proposed uninstall, wake, client, monitor, UI, test, and documentation claims. Independent adversarial reviews rejected the broad package for the protocol, timeout, idempotence, serialization, restart, stale-status, wake-transaction, error-propagation, and claim-scope gaps listed above. None of those rejected helper-removal, monitor, SetupPane, smoke-test, orchestration, or design bytes is selected.
- E-139 — 2026-08-05T21:39:27+0200 — Added the focused scheduled-wake regression before production implementation. `swift-test-scheduled-wake-reconciliation-red.log` (SHA-256 `f521ea793ca3a49652fece3e053dcc83a3fe913163aeba6e3e4dd21c6893c49a`) failed compilation because `ScheduledWakeReconciliation` did not exist, establishing the old-code RED seam. The old App source was also inspected directly: it assigned `.some(desired)` before dispatch and used `try?`, while the client discarded the decoded reply.
- E-140 — 2026-08-05T21:39:27+0200 — Implemented the reply-committed reducer and narrow explicit-rejection error. Iterative reviews found and corrected stale-reply ordering, changed-intent suppression behind a hung call, superseded-undispatched identity retention, conflation of explicit rejection with uncertain transport, unbounded completed-uncertainty identity growth, and an uncovered stale-uncertainty branch. The final reducer uses exactly one sticky bit for completed uncertainty while retaining only calls that can still complete.
- E-141 — 2026-08-05T21:39:27+0200 — The final immutable pre-ledger Git-index export is tree `fd3f8a3297048735f0e01368ee48be065ad79311`; its four-path staged binary-diff SHA-256 is `b531f0df9af669426f8c561af4f3b9d423b7c2d3306b265af356ba457abb6e0c`. Focused GREEN passed 10 tests in 1 suite in `swift-test-scheduled-wake-reconciliation-ninth-exact-v6-final.log` (SHA-256 `2b281f117733f7a67a98864de01174d75acc70084abda7af80a21fa04068efed`). The complete exact tree passed 225 tests in 15 suites in `swift-test-full-ninth-exact-v6-final.log` (SHA-256 `d8a1a6407e9d412217cd8c1a7f3d8bed3d128999d54bc202e4f7fb079a722db1`).
- E-142 — 2026-08-05T21:39:27+0200 — Exact Debug and Release `LidlessCore` builds passed with signing disabled (`swift-build-core-debug-ninth-exact-v6-final.log`, SHA-256 `76d23160f9351c2e2a16f7d4a5d22d11ee822ee3588f9bea83b139898ae5620a`; Release SHA-256 `bb1050660155a7fa3c8298aceb0c7d3e2319d850a3187ad24be13fded6d87774`). Exact App sources passed macOS 15 Swift 6 complete strict-concurrency typechecking with warnings-as-errors (`swiftc-app-typecheck-ninth-exact-v6-final.log`, SHA-256 `3b522b180ca3ed75a1913e53f1ee338426de7ec767660f792534cc162827fe93`).
- E-143 — 2026-08-05T21:39:27+0200 — With `CODE_SIGNING_ALLOWED=NO`, exact App, helper, and widget source sets compiled and linked in Debug and optimized Release (`direct-all-products-debug-ninth-exact-v6-final.log`, SHA-256 `a4729f2287d6ab92857e7c6336dcfd6308d001e690f1b998658230cf37b8d822`; Release SHA-256 `dfdf1dcdcaf1bb41b98844705610322516d7838d3fd47ce6fdc9c2fd8cbfe2b2`). All six outputs are arm64 Mach-O executables with macOS 15 minimum and SDK 26.5 load commands. No product was launched.
- E-144 — 2026-08-05T21:39:27+0200 — `artifact-config-inspection-ninth-exact-v6-final.log` (SHA-256 `cd5c9f93a1db6f28dcb6565a14a3de578b437028f622b8b9447990a00897b199`) preserves lint/decoded source configuration, project/identity bindings, artifact hashes/UUIDs/headers/dependencies/load commands, and signature inspection. The linker automatically added ad-hoc signatures; every direct output has no TeamIdentifier, bound Info.plist, sealed resources, or displayed entitlements. `codesign --verify --strict` succeeding for those loose ad-hoc binaries is not a trust, bundle, SMAppService, Gatekeeper, or release proof.
- E-145 — 2026-08-05T21:39:27+0200 — Preserved and excluded superseded verification attempts. The first stable focused invocation (`swift-test-scheduled-wake-reconciliation-green-aba.log`, SHA-256 `270ad3cee52edb9af2519e511e9faf1ae722e10d0ded3b2a1a81e64ba85baec6`) failed before compilation because its Clang cache path was not writable. Early direct Debug/Release harness logs (SHA-256 `1dbdfc065f015c568fc0a7d608a844c8d15a453b6b24d060edaf2cec10476735` and `f44fa661dfa8546a143994728e7c102d4ecb5d7a7933447cf0f40eb271bb02cc`) used a macOS 14 helper target against macOS 15 core objects and lacked fail-fast handling, so they are invalid. A later comprehensive artifact pass (`artifact-config-inspection-ninth-exact-v5-final.log`, SHA-256 `0e23bab00df0259c5fd70e5991ce1d20331cdd980a19d6f6fd2ef54c160ef9e3`) stopped at an unsupported bare `dwarfdump --uuid`; the accepted final inspection uses Xcode's `xcrun dwarfdump` and the exact v6 index. No failed or pre-v6 result is counted.
- E-146 — 2026-08-05T21:39:27+0200 — Two independent read-only reviewers exported the staged four-file index, passed `git diff --cached --check`, independently passed all 10 focused tests, and found no reachable reducer counterexample after the stale-uncertainty regression was added. Both limited their verdict to app-local reply-cache reconciliation and retained every helper transaction, XPC timeout, restart, remote-ordering, and live hardware gate above.
- E-147 — 2026-08-05T21:39:27+0200 — Pre-commit main-checkout preservation passed exactly in `main-preservation-ninth-precommit-final.log` (SHA-256 `ad5581577d61d6b97a9bd6b6f6321e89d5112d505bf4de932694aa9311facd97`): `main` remains at `7f17aaca11bc6228bed48b9265d63b9e576cdea7`, its index and tracked diff are clean, all three `.playwright-mcp` paths retain their recorded mode/size/SHA-256, and the complete NUL-status digest is `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`. A preliminary status probe used Git's default collapsed untracked-directory display and produced a different path-list digest; it changed nothing and was replaced by the required `--untracked-files=all` audit before this entry.
- E-148 — 2026-08-05T21:39:27+0200 — No App/helper/widget process was launched; no helper install, activation, registration, approval, unregister, live XPC, `pmset`, sleep setting, sleep/wake, hardware, authentication, network, release, notarization, merge, or push action was performed. Project-native Xcode build/analyze was not retried after the already established managed-sandbox and automatic LaunchServices side-effect constraints; strict Swift typechecking and direct unsigned compile/link are the bounded static evidence.
- E-149 — 2026-08-05T21:39:27+0200 — The checkpoint is prepared under subject `safety: reconcile scheduled wake replies`. Exactly the reviewed `AppState` and `HelperClient` hunks, the new reducer and its tests, plus this append-only ledger are selected. All rejected removal/support/design remainder stays unstaged. `State: IN_PROGRESS` is intentionally retained; after the single local commit the supervisor must bind the exact remaining tree into a fresh rolling manifest before another invocation.

## Tenth recovery audit — authenticated rolling remainder

- E-150 — 2026-08-05 — Read the canonical handoff, immutable starting-state manifest, rolling remainder manifest and adjacent sidecar, progress log, decision log, architecture, design-reset brief, and the complete existing ledger. The canonical handoff and immutable-manifest SHA-256 values matched their supplied values. The sidecar-recorded rolling-manifest SHA-256 `02c49a5fe66676618f6ee9ebbced4ed1009aa94919b27e7cd28d02f21b8e5900` matched the manifest bytes. A repository scan found no `AGENTS.md`, `CLAUDE.md`, `CODEX.md`, `INSTRUCTIONS.md`, or `.cursorrules` file.
- E-151 — 2026-08-05 — Applied only the authenticated rolling manifest as recovery authority. The feature canonical path, two-worktree linked topology, branch, HEAD `b5f9e05b406a84be0a6ce63c150c7fe023d47dd1`, Git admin/common directories, clean index, complete 13-path dirty inventory, every recorded status/type/mode/size/raw SHA-256, NUL-status digest `7b6479eddba2f04883948c3c8c1a2d3ee6649f6707f6226b8f5d73c3962baa76`, and tracked binary-diff digest `3eb5d68f9d0ea3543db6003b2d4f5b8942360167b3a713df3b7bb7e0c26bf275` matched exactly.
- E-152 — 2026-08-05 — Independently reverified the rolling manifest's main-checkout record without editing it: canonical path and linked topology, `main` at `7f17aaca11bc6228bed48b9265d63b9e576cdea7`, clean index, complete three-path `.playwright-mcp` inventory, every recorded status/type/mode/size/raw SHA-256, NUL-status digest `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`, and empty tracked binary-diff digest matched exactly. Recovery passed before any edit; `State: IN_PROGRESS` remains correct.
- E-153 — 2026-08-05 — The first ledger edit incorrectly treated this clean tracked file as absent because it was not listed in the dirty remainder. The resulting deletion-heavy diff was detected immediately before any product-source edit. The exact `b5f9e05` ledger bytes were restored from four bounded read-only Git-object slices through `apply_patch`, and only E-150 through E-153 were appended; no earlier evidence entry was discarded or rewritten.

## Tenth-checkpoint ruling — coordinate outside-override repair

The preserved helper-removal package is not coherent enough to accept as one
checkpoint. This invocation therefore selects one bounded root cause: manual
repair of a registry override that is already ON but is not owned by the
current session previously made one eager `repairOverride` call outside the
generation-bound non-sleep restoration coordinator. It could not retry an
ordinary rejected proof, and a sleep takeover could convert the pending repair
into a plain disarm even though the repair actuation remained necessary.

The selected repair adds an explicit non-sleep actuation policy. A repair
generation uses the existing UUID identity, in-flight accounting, completion
latch, helper proof, and independent fresh registry-OFF proof, but dispatches
`repairOverride` rather than `disarm`. Repair actuation is forbidden for
force-sleep, quit finalization, and the unowned-completion concession. Sleep
takeover captures the stable actuation before cancelling the non-sleep
generation, performs the corresponding actuation, and fences post-await work
by the sleep-transition generation. Repair and uninstall also have a minimal
two-way process-local exclusion latch so neither selected entry point can begin
while the other is active.

This is deliberately an offline, bounded ruling. A dispatched XPC request has
no timeout or remote cancellation: a peer that never replies can park the app
in `.disarming`, and cancelling an app-local generation cannot retract a late
remote mutation. A sufficiently late repair mutation could therefore turn OFF
an override belonging to a later session; that fail-safe but disruptive case
requires a remote transaction token or equivalent daemon protocol, not another
local source-order assertion. The repair/uninstall latch is not restart-durable
or cross-process. No protocol-version bump, full uninstall transaction,
launch-reconciliation repair, or live helper behavior is accepted here.

The broader preserved removal/support package remains rejected. It still lacks
a behavior-protocol fence for its proposed uninstall contract, bounded XPC
delivery/reply waits, proven `.notRegistered` idempotence, a verified inactive
post-unregister condition, restart-durable latches, complete serialization
across install/uninstall/repair/reconciliation/termination, transactional wake
cancellation and persistence, fresh post-cleanup status, safe partial-cleanup
retry semantics, and complete error propagation. Its monitor, SetupPane,
smoke-test, orchestration, and design-reset bytes are outside this checkpoint.

### Tenth-checkpoint finding and verification matrix

| ID | Invariant | Exact checkpoint evidence | Remaining boundary | Ruling |
| --- | --- | --- | --- | --- |
| S-24 | Outside-override repair uses the generation-bound non-sleep coordinator and cannot complete from stale or partial proof | `NonSleepRestoreActuation` policy tests plus source-integration regressions bind synchronous generation entry, repair dispatch, retry, UUID ownership, all-arm-settled gating, exact helper proof, and independent fresh registry-OFF proof | The App integration regression is structural; XPC delivery/reply remains unbounded and no process or registry mutation was exercised | CHECKPOINT VERIFIED OFFLINE — TRANSPORT/LIVE GATES OPEN |
| S-25 | Sleep takeover preserves the pending repair actuation instead of silently downgrading it to disarm | Regression locks capture-before-cancel, first-terminal-transition-only capture, actuation-specific dispatch, post-await generation fencing, and paired generation/actuation clearing | A dispatched remote call is not cancellable and real sleep/wake ordering was not exercised | CHECKPOINT VERIFIED OFFLINE — REMOTE/LIVE GATES OPEN |
| S-26 | Repair cannot inherit force-sleep, quit-finalization, or unowned-completion semantics, and cannot overlap the selected uninstall entry point | Pure policy tests reject each incompatible option; exact App source contains the two-way actor-isolated repair/uninstall latch | The latch is process-local, not restart-durable, and does not close the broader install/reconciliation/termination transaction | CHECKPOINT VERIFIED OFFLINE — RESTART/FULL-TRANSACTION GATES OPEN |
| V-12 | Exact selected code passes focused, complete, strict compile, and unsigned link checks | Pre-ledger tree `b220f36887d40c4d1a520b8458d99f3e2e2056b9` passed 11 focused tests, 227 exact tests, Debug/Release core builds, Swift 6 strict-concurrency typechecking, and direct Debug/Release app/helper/widget links | Project-native Xcode graph build/analyze was not retried under the established managed-sandbox and LaunchServices constraints | PASS FOR EXACT OFFLINE CODE — XCODE GRAPH OPEN |
| V-13 | Artifact/config inspection remains bounded to the observed unsigned outputs | Source configuration and six exact arm64 direct outputs were inspected; outputs carry only automatic linker ad-hoc signatures and no team, bound plist, sealed resources, or displayed entitlements | No signed/Xcode-produced bundle, runtime trust, SMAppService, hardware, notarization, or release proof exists | PARTIAL — SIGNED BUNDLE/RUNTIME GATES OPEN |

- E-154 — 2026-08-05T22:20:50+0200 — Reproduced the complete authenticated dirty-package baseline before accepting any remainder claim. Stable Xcode 26.5's Swift 6.3.2 passed 232 tests in 16 suites in `swift-test-tenth-baseline.log` (SHA-256 `f10695c5b957064c0db8c732720fd229d773d8b634e855c62c59e1d1c255f03f`). This was only a baseline; it did not validate the broad removal transaction or convert source-shape assertions into runtime evidence.
- E-155 — 2026-08-05T22:20:50+0200 — Reviewed the complete 13-path rolling remainder and every diff against checkpoint HEAD. Three independent subsystem audits rejected the broad package for the protocol, timeout, restart/ABA, idempotence, post-unregister proof, transaction-exclusion, wake-persistence, stale-status, cleanup-retry, monitor-lifecycle, and UI-claim gaps recorded above. The exact selected scope is only coordinated outside-override repair, its sleep takeover, and minimal repair/uninstall mutual exclusion.
- E-156 — 2026-08-05T22:20:50+0200 — Established RED evidence before accepting implementation. `swift-test-repair-coordinator-red.log` failed 1 source-integration test with 7 issues because repair did not use the coordinator (SHA-256 `9fa020a4feca14edc0487d8e8534f3c10fa384992a5eb771a90b275aa5c1caae`). `swift-test-repair-actuation-policy-red.log` failed compilation because `NonSleepRestoreActuation` did not exist (SHA-256 `6498fc06ad1a0b0ce433a2aee7ba2c9b03f3546eb40beb2e494c532b39335517`). Independent review then exposed repair-to-disarm downgrade during sleep takeover; `swift-test-repair-sleep-transition-red.log` reproduced 5 source-integration issues (SHA-256 `3065816f11e72f9d61ad2abbe9d82035ba50f17f5101c8018e39dd3297f37ef1`).
- E-157 — 2026-08-05T22:20:50+0200 — Implemented explicit `.disarm` and `.repairOverride` actuation, stored it in each pending restore, and rejected repair actuation with force sleep, session finalization, or unowned-completion semantics. Manual repair now checks termination/uninstall/sleep/session/arm/restore state and fresh exact helper plus registry evidence, synchronously enters the coordinator before its first XPC call, retries only after a completed attempt lacks final proof, and emits no incidental user notification. Quit final proof remains disarm-only. Sleep takeover captures actuation before cancellation on the first terminal generation, dispatches the matching helper operation, applies a post-await generation fence, requires helper plus fresh registry-OFF proof, and clears transition generation and actuation together.
- E-158 — 2026-08-05T22:20:50+0200 — The immutable pre-ledger Git-index tree is `b220f36887d40c4d1a520b8458d99f3e2e2056b9`; its four-path staged binary-diff SHA-256 is `79b89278011bc6fd05d07f09255da473ad45a569a1c7f678a5a20d7bcde2676d`. An independent `git archive` export matched the verified exact export byte-for-byte. Focused GREEN passed 11 tests in 1 suite in `swift-test-repair-coordinator-tenth-exact-green-final5.log` (SHA-256 `2412666f14058e98fb930c2effc4a3fd597dc98f7771ba586fea93ebd8e6c503`). The exact export passed 227 tests in 15 suites in `swift-test-full-tenth-exact-final5.log` (SHA-256 `c631a52aad4b8579d426a14f19a48e146c63c3f90e1c652f54958e8cd02990a9`), and a fresh staged export independently passed the same 227 tests in `swift-test-full-tenth-staged-final3.log` (SHA-256 `f485394b46a499c069989ba0f5f558aef2771d232bf3da89bcbb5197f43847bd`). The complete dirty tree passed 234 tests in 16 suites in `swift-test-full-tenth-dirty-final4.log` (SHA-256 `f556674dc1cc107da92ae45c8136f87bf28ea9893889f784a38253dd45f9f020`); its seven extra tests belong to deliberately unstaged remainder.
- E-159 — 2026-08-05T22:20:50+0200 — Exact Debug and Release `LidlessCore` builds passed (`swift-build-core-debug-tenth-exact-final2.log`, SHA-256 `f0f4d0b0bbde3580883be21a307f098acee245bdf2303c9c520886b522890caf`; Release SHA-256 `b775d8cae40ce76ce6116e61cd31f8098eac031a046c897e18d4836a062a9166`). All exact App, helper, and widget sources passed macOS 15 Swift 6 complete strict-concurrency typechecking with warnings-as-errors (`swiftc-all-products-typecheck-tenth-exact-final3.log`, SHA-256 `c3972d4accdb2f8ee7a1a6dbbcdaf80e3a8c10a20a484d95f07c73e4ce70627e`). With `CODE_SIGNING_ALLOWED=NO`, all three source sets compiled and linked in Debug and optimized Release (`direct-all-products-debug-tenth-exact-final3.log`, SHA-256 `110c9981f64ca5783633e2217193bc9a79fc4c2b8b9470a88bc46095776a2a11`; Release SHA-256 `f096e0a19a8a7c47ea21ae6c8129cfcf2f0a5a03b62603753fe718da73e3e336`). No product was launched.
- E-160 — 2026-08-05T22:20:50+0200 — `artifact-config-inspection-tenth-exact-final3.log` (SHA-256 `b38879312cb569c3fa91a5cb47e79c8d08c7944d48f8505bc21fcc67e45619b1`) preserves plist/entitlement/export/project lint and decoded values plus artifact hashes, architectures, load commands, linkage, and code-sign metadata. The six direct outputs are thin arm64 Mach-O executables with macOS 15 minimum and SDK 26.5 load commands. Their automatic linker ad-hoc signatures have no TeamIdentifier, bound Info.plist, sealed resources, or displayed entitlements. A successful strict verification of those loose ad-hoc outputs is not signed-bundle, XPC-trust, SMAppService, Gatekeeper, or release proof.
- E-161 — 2026-08-05T22:20:50+0200 — Independent adversarial review first found the sleep-transition downgrade and drove the accepted RED/fix. Final reviewers exported the isolated four-path snapshot, checked the actuation policy, both actor orderings of the repair/uninstall latch, cancellation and transition sequencing, post-await generation ownership, and the focused regressions; no blocker remained inside the bounded scope. They retained never-reply liveness, late remote mutation, restart durability, remote protocol/transaction identity, broader helper removal, and all live behavior as explicit open gates.
- E-162 — 2026-08-05T22:20:50+0200 — Preserved and excluded invalid setup probes. The first baseline setup selected a relative cache before its directory existed and failed before compilation. One exact-index staging script used zsh's reserved `path` parameter and consequently could not find `git`; it stopped before changing the index, and the corrected script passed. The first main-preservation probe referenced nonexistent `/usr/bin/realpath`; the corrected read-only audit used Git's canonical root. Preliminary reviewer attempts also encountered cache/sandbox setup failures before the accepted focused rerun. None of those results is counted as verification evidence and none changed product bytes or external state.
- E-163 — 2026-08-05T22:20:50+0200 — Working-tree and staged `git diff --check` both passed in `git-diff-check-tenth-precommit.log` (SHA-256 `3e45e391a2758a1a2531d22ee68f08f7364b9bd0d4f136a54ecf15b54b146f8d`). Final pre-commit main-checkout preservation passed exactly in `main-preservation-tenth-precommit-final.log` (SHA-256 `b74bf2796efa21e81854bd7bf76461aa7f426ef3944d49d702b47652724cecd5`): `main` remains at `7f17aaca11bc6228bed48b9265d63b9e576cdea7`, its index and tracked diff are clean, all three `.playwright-mcp` paths retain their recorded mode/size/SHA-256 values, and the complete NUL-status digest remains `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`.
- E-164 — 2026-08-05T22:20:50+0200 — No App/helper/widget process was launched; no helper install, activation, registration, approval, unregister, live XPC, `pmset`, sleep setting, sleep/wake, hardware, authentication, plugin/provider/connector, Figma, network publication, release, notarization, merge, push, or main-checkout mutation was performed. Builds and static checks kept signing disabled and are not represented as runtime or hardware proof.
- E-165 — 2026-08-05T22:20:50+0200 — The checkpoint is prepared under subject `safety: coordinate outside-override repair`. Exactly the reviewed `ARCHITECTURE.md` update, isolated `AppState.swift` hunks, new actuation policy, focused regression hunks, and this append-only ledger are selected. All rejected helper-removal, monitor, SetupPane, smoke-test, orchestration, and design remainder stays unstaged. `State: IN_PROGRESS` is intentionally retained; after the single local commit the supervisor must authenticate the exact remaining tree in a fresh rolling manifest before another invocation.

## Eleventh recovery audit — authenticated removal/support remainder

- E-166 — 2026-08-05T22:26:55+0200 — Read the canonical handoff, immutable starting-state manifest, rolling remainder manifest and adjacent sidecar, progress log, decision log, architecture, design-reset brief, and this complete append-only ledger. The canonical handoff SHA-256 `95bdacdde663c642c2f97d532c1ec2b931e94a7dfcda47b8031e011ab3944831` and immutable-manifest SHA-256 `d84065171a261e24ae574b98164132472ff1e8bb635647403d814b9fcf58c36a` matched their supplied values. The sidecar-recorded rolling-manifest SHA-256 `58b58d732688e7a24298f4a75f09c4085c0a5a66c09b54102eb75425f07c8c68` matched the manifest bytes. A hidden-file scan found no `AGENTS.md`, `CLAUDE.md`, `CODEX.md`, `.cursorrules`, or `copilot-instructions.md` file.
- E-167 — 2026-08-05T22:26:55+0200 — Applied only the authenticated rolling manifest as recovery authority. The feature canonical path, two-worktree linked topology, branch, HEAD `c76d5febea694410fa506cb9327960b813da0a28`, Git admin/common directories, clean index, complete 13-path dirty inventory, every recorded status/type/mode/size/raw SHA-256, NUL-status digest `7b6479eddba2f04883948c3c8c1a2d3ee6649f6707f6226b8f5d73c3962baa76`, and tracked binary-diff digest `f3a97577cc9106fe3f9da7f3372a973348ba7f9dd9ae959622b54011220ea45a` matched exactly. Starting HEAD `7f17aaca11bc6228bed48b9265d63b9e576cdea7` remains an ancestor through the ten named checkpoint commits. A preliminary read-only canonical-path probe referenced unavailable `/usr/bin/realpath`; Git's canonical root and `pwd -P` supplied the accepted exact path. The probe changed no file.
- E-168 — 2026-08-05T22:26:55+0200 — Independently reverified the rolling manifest's main-checkout record without editing it: canonical path and linked topology, `main` at `7f17aaca11bc6228bed48b9265d63b9e576cdea7`, clean index, complete three-path `.playwright-mcp` inventory, every recorded status/type/mode/size/raw SHA-256, NUL-status digest `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`, and empty tracked binary-diff digest matched exactly. Recovery passed before this ledger append; the top-level `State: IN_PROGRESS` remains correct.

## Eleventh-checkpoint ruling — fence launch reconciliation replies

The preserved helper-removal package is still not coherent enough to accept as
one checkpoint. Its proposed protocol-visible removal behavior retains version
6, has no restart-durable transaction identity, treats ServiceManagement
registration states as more idempotent than the inspected SDK contract
supports, has unbounded XPC waits, does not make wake cancellation and
persistence transactional, can publish status captured before cleanup, and
does not serialize every install, termination, reconciliation, and remote
cleanup path. Its monitor, SetupPane, smoke-test, orchestration, and design
claims also remain outside a verified removal transaction. Those bytes remain
unstaged.

This invocation instead selects one bounded launch-safety defect. The prior
launch task checked app/helper state only before awaiting `helper.status()` and
then called `helper.disarm` directly. A delayed reply could therefore cross a
new app session, pending arm/restore, sleep transition, or helper lifecycle
operation; it could act on obsolete evidence and bypass the generation-bound
normal-sleep restoration coordinator.

The selected repair adds a pure fail-closed launch policy. It snapshots the
MainActor state before the status request, requires a reachable and otherwise
quiescent context, and checks the current phase/session/restore/arm-flight,
termination/removal/sleep-transition, helper state, helper proof epoch, helper
lifecycle epoch and in-flight count, and sleep generation after the await.
App-routed install, refresh, and uninstall intervals increment a process-local
lifecycle count and bump the epoch at both boundaries, so a query cannot begin
during an operation and a suspended query cannot survive an operation or a
same-state ABA. Affirmative `armed` or `restorePending` evidence enters the
existing verified restoration coordinator; only a still-undispatched queued
arm intent is cancelled, and the launch task returns before scheduled-wake
maintenance. Neutral notification copy does not infer that every pending
recovery came from an earlier keep-awake session.

This is deliberately an app-local offline fence. XPC delivery/reply remains
unbounded; remote effects cannot be cancelled; the daemon has no transaction
token or instance identity; an external service/daemon ABA that produces no
App-observed lifecycle change is not detected; a legacy reply with no
`restorePending` is not affirmative recovery evidence; and the App integration
tests are structural. No helper, ServiceManagement, registry, sleep/wake, or
hardware behavior was exercised.

### Eleventh-checkpoint finding and verification matrix

| ID | Invariant | Exact checkpoint evidence | Remaining boundary | Ruling |
| --- | --- | --- | --- | --- |
| S-27 | A delayed launch-status reply cannot cross a new session, arm mutation, pending restore, termination/removal, sleep transition, helper-state change, proof epoch, lifecycle interval, or sleep generation | Six pure-policy and source-integration tests cover safe query entry, stable affirmative/negative replies, each local invalidation family, queued-intent presence changes, and post-await ordering | App wiring is source-structural; XPC can wait indefinitely and external daemon-instance ABA is not tokenized | CHECKPOINT VERIFIED OFFLINE — REMOTE/LIVE GATES OPEN |
| S-28 | App-routed helper install, refresh, and uninstall operations fence launch reconciliation for their complete suspension interval, including same-state ABA | Exact App source wraps every AppState refresh plus install/uninstall; paired in-flight count and begin/end epoch changes were independently reviewed, and old source contracts now require the wrapper rather than a raw refresh | The fence is process-local and does not serialize unobserved external ServiceManagement or daemon actions | CHECKPOINT VERIFIED OFFLINE — CROSS-PROCESS/RESTART GATES OPEN |
| S-29 | Affirmative launch recovery uses the existing proof-gated restore coordinator, cancels only an undispatched queued intent, and cannot fall through to wake maintenance | Reducer tests plus exact source ordering prove cancellation before `beginRestore`, no raw launch disarm, verified coordinator dispatch, neutral copy, widget publication, and an early return | No real status/disarm reply, registry proof, notification, scheduled wake, or crash recovery was exercised | CHECKPOINT VERIFIED OFFLINE — LIVE/FAULT GATES OPEN |
| V-14 | Exact selected code passes focused, complete, strict compile, and unsigned link checks | Pre-ledger tree `716fe21797dddd07d15bbf0126d381f34cb8c2a2` passed 6 launch, 7 presentation, 11 restore-coordinator, and 233 complete tests; Debug/Release core builds, Swift 6 strict-concurrency typechecking, and direct Debug/Release app/helper/widget links passed | Project-native Xcode build/analyze was not retried under the established managed-sandbox and automatic LaunchServices side-effect constraints | PASS FOR EXACT OFFLINE CODE — XCODE GRAPH OPEN |
| V-15 | Artifact/config inspection remains bounded to observed unsigned outputs | Exact source plists, entitlements, export options, and project bindings linted and were decoded; all six direct outputs are thin arm64 Mach-O executables with macOS 15 minimum and SDK 26.5 load commands | Outputs are loose linker-ad-hoc executables with no team, bound plist, sealed resources, or entitlements; no signed bundle/runtime proof exists | PARTIAL — SIGNED BUNDLE/RUNTIME GATES OPEN |

- E-169 — 2026-08-05T22:54:21+0200 — Reproduced the complete authenticated dirty-package baseline before accepting any remainder claim. Stable Xcode 26.5's Swift 6.3.2 passed 234 tests in 16 suites in `swift-test-eleventh-baseline.log` (SHA-256 `400b1a00c799a59a9409a385ef4d9bab4945e04ef6a413d000ef63c70b95798d`). This was only a baseline. Complete diff review and three independent subsystem audits rejected the broad helper-removal package for the protocol, transaction, timeout, restart/ABA, ServiceManagement-idempotence, cleanup-ordering, stale-status, retry, monitor, UI-copy, and documentation gaps recorded above.
- E-170 — 2026-08-05T22:54:21+0200 — Established compile-time RED against an exact HEAD export before implementation. `swift-test-launch-reconciliation-eleventh-red.log` failed because the regression required the absent `LaunchReconciliationSafety` policy (SHA-256 `5a5889a5cfc8f532309e3c6030b5876cd57c08948ad99faf4de9a0949a5d3b3a`). The old source had only pre-await phase/helper checks followed by an uncoordinated `helper.disarm`, so no equivalent generation gate could satisfy the new contract.
- E-171 — 2026-08-05T22:54:21+0200 — Implemented the pure launch context/action reducer, pre/post-await comparison, process-local helper lifecycle interval counter and epoch, fenced App-routed helper refresh/install/uninstall operations, coordinator-only launch recovery, undispatched-intent cancellation, early return before wake maintenance, and neutral verified-recovery copy. The existing presentation and non-sleep source contracts were adapted narrowly to require the fenced wrapper and balanced multi-line lifecycle cleanup; the rejected broad removal assertions were not staged.
- E-172 — 2026-08-05T22:54:21+0200 — The immutable pre-ledger Git-index tree is `716fe21797dddd07d15bbf0126d381f34cb8c2a2`; its five-path staged binary-diff SHA-256 is `f33ffaf1342b2a44106a552b4297a3227226581c91daa67d402a168633a35396`. Independent `git archive` and `git checkout-index` exports matched byte-for-byte, and every selected exported blob matched the index in `exact-index-and-diff-check-eleventh-preledger-final.log` (SHA-256 `6100e93b107aece0ac7d3c96982963f406b1e18275b24a79a14f9f70c3538075`). Focused exact GREEN passed 6 launch tests in `swift-test-launch-reconciliation-eleventh-exact-final2.log` (SHA-256 `8a1ae27fce18a1ac614922feffd1c08fec59b7d756a8e4f87f6df6d54fe1b61d`), 7 presentation tests in `swift-test-sleep-presentation-eleventh-exact-final2.log` (SHA-256 `14e091afd8413a8eef29440ef81a2faf92bd8c5958c53f485718a42e79a80ef7`), and 11 non-sleep coordinator tests in `swift-test-nonsleep-coordinator-eleventh-exact-final2.log` (SHA-256 `01191847ccb8997bea164a0f439786ca1d92ede02e4f23fa9575cea70ad80d1e`). The complete exact export passed 233 tests in 16 suites in `swift-test-full-eleventh-exact-final2.log` (SHA-256 `04cdb055dc9b6b2efde0ba59ea217841ee287c9722409fa26442a2705de0ab1e`).
- E-173 — 2026-08-05T22:54:21+0200 — The complete dirty remainder passed 240 tests in 17 suites in `swift-test-full-eleventh-dirty-final4.log` (SHA-256 `37cfd7289d8ad728bc5831759f3a6c7a0592ab96e9a380cc49fa9cb0848153cf`); its seven extra tests belong to deliberately unstaged helper-removal remainder and are not accepted as proof of that transaction.
- E-174 — 2026-08-05T22:54:21+0200 — Exact Debug and Release `LidlessCore` builds passed (`swift-build-core-debug-eleventh-exact-final2.log`, SHA-256 `d7e8baf4dc5d33c50e3be1e6a4b9a0073397bcf5cec0974f50ea9ed0ddc75843`; `swift-build-core-release-eleventh-exact-final2.log`, SHA-256 `db94f89c5dd6d635c2856e8c1fb12dfe14d97745dbd69703760d04fcdfb98b73`). All 25 App, 4 helper, and 1 widget source files passed macOS 15 Swift 6 complete strict-concurrency typechecking with warnings-as-errors (`swiftc-all-products-typecheck-eleventh-exact-final2.log`, SHA-256 `0e2c5000ef1fceda3baab58fea3e275f2296da256335efb277ae538dd62fabd7`). With `CODE_SIGNING_ALLOWED=NO`, all three exact source sets compiled and linked in Debug and optimized Release (`direct-all-products-debug-eleventh-exact-final2.log`, SHA-256 `b62a195bf12efa361c6631646e029f4e9bf1a08f991b3348f493030135d55467`; `direct-all-products-release-eleventh-exact-final2.log`, SHA-256 `9c43818f5b9905623541f15f52027e9efb714d6657212e42cfa984b08241606b`). No product was launched.
- E-175 — 2026-08-05T22:54:21+0200 — `config-plist-entitlement-inspection-eleventh-exact-final2.log` (SHA-256 `af024d838797efc47f7fb66aab49cae0c71faa2ef83e59edb28ec0d2c0cae954`) preserves source plist/entitlement/export/project lint, decoded values, identifiers, deployment target, and bindings. `artifact-inspection-eleventh-exact-final3.log` (SHA-256 `a810b501ec501a8a1c7d286591b2a5d42089ad5ea497ad37c79afd4a9c35c1ce`) preserves hashes, modes, architectures, UUIDs, Mach headers, build-version commands, and code-sign metadata for all six direct outputs. They are thin arm64 macOS 15 / SDK 26.5 executables with automatic linker ad-hoc signatures, no TeamIdentifier, no bound Info.plist, no sealed resources, and no displayed entitlements. Strict verification of loose ad-hoc outputs is not signed-bundle, XPC-trust, ServiceManagement, Gatekeeper, notarization, or release proof.
- E-176 — 2026-08-05T22:54:21+0200 — Independent adversarial review found the original helper-lifecycle start-only epoch race, inaccurate orphan-session copy, and weak negative/source-order coverage. The accepted repair added a full in-flight interval, paired epoch transitions, neutral copy, and expanded six-test matrix. A final exact-index reviewer then found that the uninstall cleanup assertion could match the lifecycle-property initializer instead of the `uninstall()` defer. The assertion was scoped to the extracted `uninstall()` body and now requires the exact paired multi-line cleanup. Final re-review found no blocker inside the bounded app-local checkpoint while retaining unbounded XPC, external daemon ABA, remote transaction identity, legacy-status, and live behavior as explicit gates.
- E-177 — 2026-08-05T22:54:21+0200 — Preserved and excluded invalid setup/verification attempts. One focused rerun selected the default beta toolchain and unwritable Clang cache and failed before compilation. The first complete dirty run then exposed a stale raw-refresh assertion and failed one test; after adapting it to the required wrapper, the next exact run exposed an older one-line uninstall-defer assertion that the dirty removal remainder had deleted. That assertion was restored and narrowed to balanced lifecycle cleanup, after which all focused and complete exact/dirty suites passed. A preliminary artifact inspection used Homebrew `dwarfdump` with an unsupported long option; the corrected final inspection uses `/usr/bin/dwarfdump -u` and is the only artifact log counted. None of these attempts launched a product or changed external state.
- E-178 — 2026-08-05T22:54:21+0200 — Working-tree and staged `git diff --check` passed. Pre-commit main-checkout preservation passed exactly in `main-preservation-eleventh-precommit.log` (SHA-256 `99663a9fa976ac82816eaebb5dc0af6dca95d1295efd874055e560975d400ebe`): `main` remains at `7f17aaca11bc6228bed48b9265d63b9e576cdea7`, its index and tracked diff are clean, all three `.playwright-mcp` paths retain their recorded mode/size/SHA-256 values, and the complete NUL-status digest remains `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`.
- E-179 — 2026-08-05T22:54:21+0200 — No App/helper/widget process was launched; no helper install, activation, registration, approval, unregister, live XPC, `pmset`, sleep setting, sleep/wake, hardware, authentication, plugin/provider/connector, Figma, network publication, release, notarization, merge, push, or main-checkout mutation was performed. Project-native Xcode build/analyze was not retried after the established managed-sandbox and automatic LaunchServices side-effect constraints; strict Swift checks and direct unsigned compilation/linking are the bounded static evidence.
- E-180 — 2026-08-05T22:54:21+0200 — The checkpoint is prepared under subject `safety: fence launch reconciliation replies`. Exactly the reviewed isolated AppState hunks, pure policy, focused regression suite, two narrow legacy source-contract adaptations, and this append-only ledger are selected. All rejected helper-removal, monitor, SetupPane, smoke-test, orchestration, and design remainder stays unstaged. `State: IN_PROGRESS` is intentionally retained; after the single local commit the supervisor must authenticate the exact remaining tree in a fresh rolling manifest before another invocation.

## Twelfth recovery audit — authenticated removal/support remainder

- E-181 — 2026-08-05T23:06:59+0200 — Read the canonical handoff, immutable starting-state manifest, rolling remainder manifest and adjacent sidecar, progress log, decision log, architecture, design-reset brief, and this complete append-only ledger. The canonical handoff SHA-256 `95bdacdde663c642c2f97d532c1ec2b931e94a7dfcda47b8031e011ab3944831` and immutable-manifest SHA-256 `d84065171a261e24ae574b98164132472ff1e8bb635647403d814b9fcf58c36a` matched their supplied values. The sidecar-recorded rolling-manifest SHA-256 `d424ca9bff5ca27173bb95c808540970bf472f46ba7f56d69c4de8782a21a3b9` matched the manifest bytes. A repository-wide hidden-file scan found no `AGENTS.md`, `CLAUDE.md`, `CODEX.md`, or `GEMINI.md` file.
- E-182 — 2026-08-05T23:06:59+0200 — Applied only the authenticated rolling manifest as recovery authority. The feature canonical path, two-worktree linked topology, branch, HEAD `0b0f42e0ba499a24beb7328d1efcf8bf0b76ea7d`, Git admin/common directories, clean index, complete 13-path dirty inventory, every recorded status/type/mode/size/raw SHA-256, NUL-status digest `7b6479eddba2f04883948c3c8c1a2d3ee6649f6707f6226b8f5d73c3962baa76`, and tracked binary-diff digest `5c8a486c50509d1d1738f8c30fdb5aebbf8b3243612b01ae3daa3aaef1c17905` matched exactly. Starting HEAD `7f17aaca11bc6228bed48b9265d63b9e576cdea7` remains an ancestor through the ten named checkpoint commits. Recovery passed before this append; the top-level `State: IN_PROGRESS` remains correct.
- E-183 — 2026-08-05T23:06:59+0200 — Independently reverified the rolling manifest's main-checkout record without editing it: canonical path and linked topology, `main` at `7f17aaca11bc6228bed48b9265d63b9e576cdea7`, clean index, complete three-path `.playwright-mcp` inventory, every recorded status/type/mode/size/raw SHA-256, NUL-status digest `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`, and empty tracked binary-diff digest matched exactly.
- E-184 — 2026-08-05T23:06:59+0200 — One preliminary read-only all-in-one verifier exited before emitting a comparison result under the default shell. It changed no file and supplied no state verdict. The corrected explicit Bash verifier then checked every field and produced the exact matches recorded in E-182 and E-183.

## Twelfth-checkpoint ruling — require current proof before helper deregistration

The preserved helper-removal package is still not coherent enough to accept as
one removal transaction. Its proposed daemon behavior remains on helper
version 6; scheduled-wake mutation and persistence are not transactional;
optional restore failures can be discarded; the returned status can precede
cleanup; XPC waits are unbounded; the latches are process-local; daemon
instance and removal transaction identities do not exist; inactive
ServiceManagement handling is not idempotent under the inspected SDK contract;
and there is no verified inactive state after unregister. AppState operation
overlap, monitor lifecycle, SetupPane copy, smoke-test, orchestration, and
design-reset bytes also remain outside a coherent removal checkpoint. All of
those bytes remain unstaged.

This invocation selects one narrower fail-closed defect in the existing
enabled-service client path. Before this checkpoint, an XPC or decode failure
could be caught and replaced by one app-side registry-OFF read, after which the
client proceeded to `unregister()`. That removed launchd recovery supervision
without any current helper reply, exact protocol-version proof, complete
restore receipt, or agreement between two observations.

The selected repair requires the enabled helper's uninstall XPC call to return
a decoded `HelperReply`, then applies the existing strict
`SleepOverrideSafety.isRestoreProven(_:independentlyObserved:)` policy to that
reply and a fresh app-side registry read taken after the reply. The policy
requires `reply.ok`, the exact current helper version, no armed session, a
readable helper-side registry result reporting normal sleep, and no pending
restore; the independent read must also report normal sleep. Any XPC, decode,
version, helper-proof, app-read, or disagreement failure throws before the
existing static unregister call. The former generic-error plus one-read
fallback is removed.

This is only a necessary precondition for one enabled-helper deregistration
attempt. It does not prove that daemon cleanup completed, that every scheduled
wake or optional setting was restored, that registration stayed stable between
proof and unregister, that unregister succeeded or reached `.notRegistered`,
or that a retry is idempotent. The inactive path is unchanged. No wire shape or
daemon behavior changed in this checkpoint, so no helper-version bump is
introduced for this client-only authorization fence; the incompatible broader
version-6 daemon remainder is explicitly not accepted. No helper,
ServiceManagement, registry, app, sleep/wake, or hardware behavior was
exercised.

### Twelfth-checkpoint finding and verification matrix

| ID | Invariant | Exact checkpoint evidence | Remaining boundary | Ruling |
| --- | --- | --- | --- | --- |
| S-30 | An enabled helper cannot be deregistered after an XPC, decoding, current-version, or helper-side restore-proof failure | Focused behavior and source-integration regressions require a decoded reply and the existing exact-version complete restore policy before `Self.unregisterDaemon()`; the former generic-error registry-only fallback is forbidden | XPC delivery/reply is unbounded, App operations are not fully serialized, and the source-order integration test does not execute ServiceManagement | CHECKPOINT VERIFIED OFFLINE — TRANSPORT/LIVE GATES OPEN |
| S-31 | Deregistration requires agreement between the current helper's complete restore receipt and a fresh later app-side registry-OFF read | The pure policy matrix accepts only exact-current complete proof plus independent `false`, and rejects `nil`, `true`, wrong version, and `reply.ok == false`; exact source ordering places the app read after the reply and combined proof before unregister | A daemon restart/ABA or new arm after either observation is not transaction-tokenized, and no real registry was read | CHECKPOINT VERIFIED OFFLINE — REMOTE-IDENTITY/LIVE GATES OPEN |
| S-32 | The accepted scope is a pre-deregistration authorization fence, not complete uninstall | Only the enabled branch's proof/error block and its focused tests are staged; the inactive branch, daemon cleanup, AppState remainder, monitors, UI, docs, and broad removal policy remain excluded | Inactive registration idempotence, cleanup retry, post-unregister verification, restart durability, transactionality, and complete removal all remain open | PASS FOR BOUNDED SCOPE — REMOVAL TRANSACTION OPEN |
| V-16 | Exact selected code passes focused, complete, strict compile, and explicitly unsigned Debug/Release link checks | Pre-ledger tree `9284e35645beb7a73eb21731cf24dc09ef679fca` passed 2 focused tests and 235 complete tests; Debug/Release core builds, Swift 6 complete-concurrency typechecking with warnings-as-errors, and direct Debug/Release App/helper/widget links passed | Project-native Xcode graph build/analyze was not retried under the established nested-sandbox and automatic LaunchServices side-effect constraints | PASS FOR EXACT OFFLINE CODE — XCODE GRAPH OPEN |
| V-17 | Artifact and configuration inspection is bounded to actual observed output | Exact source plists, entitlements, identifiers, project bindings, and linkage were checked; all six direct products are thin arm64 macOS 15 / SDK 26.5 executables with linker ad-hoc signing disabled, no `LC_CODE_SIGNATURE`, no embedded Info.plist, and no signature | They are loose executables, not bundles; no bound entitlements, team identity, designated requirement, XPC trust, ServiceManagement, Gatekeeper, notarization, or runtime proof exists | PARTIAL — BUNDLE/SIGNED/RUNTIME GATES OPEN |

- E-185 — 2026-08-05T23:26:05+0200 — Reproduced the complete authenticated dirty-package baseline before accepting any remainder claim. Stable Xcode 26.5's Swift 6.3.2 passed 240 tests in 17 suites in `swift-test-twelfth-baseline.log` (SHA-256 `38efe8fc501aab30879371076d4789563b6c669d29dd25c9d36a6a282ac95735`). This was only a baseline. Complete diff review and independent client/daemon audits rejected the broad helper-removal package for the version, transaction, persistence, timeout, restart/ABA, ServiceManagement-idempotence, stale-status, cleanup, retry, operation-overlap, monitor, UI-copy, test-claim, and documentation gaps recorded above.
- E-186 — 2026-08-05T23:26:05+0200 — Established RED against an exact HEAD export plus the new regression before accepting the source change. `swift-test-helper-client-removal-proof-red.log` failed 1 of 2 focused tests because the old enabled-helper path had no post-reply independent observation/combined proof and still contained the generic-XPC-error registry-only fallback (SHA-256 `cb1c9f9e3222daa98b15b7310dca3dfcfcf405f5c52779b8b4be34bddeed7535`). The behavioral policy matrix already passed and confirmed the reusable strict policy; the source integration test supplied the failing defect witness.
- E-187 — 2026-08-05T23:26:05+0200 — Implemented only the enabled-service client authorization fence: the call must return a decoded reply, the later app registry observation is combined with the current helper's complete proof through `SleepOverrideSafety.isRestoreProven`, and all failures throw before static unregister. No IPC type, helper daemon, version, inactive branch, AppState, ServiceManagement wrapper, monitor, UI, orchestration, or design byte is selected. A client-only authorization change does not require a wire-version bump; no broader version-6 helper behavior is accepted by that statement.
- E-188 — 2026-08-05T23:26:05+0200 — The immutable pre-ledger Git-index tree is `9284e35645beb7a73eb21731cf24dc09ef679fca`; its two-path staged binary-diff SHA-256 is `762f77e88e9122b6e438c104391da76f271374e24b6acb232deef9a6534f8692`. Both selected blobs matched the independent exact export byte-for-byte in `exact-index-and-diff-check-twelfth-preledger.log` (SHA-256 `18b4f6e9d434c16484db7b57b1cd1bdfc54543bbef697b9f1f72935a30e0e0f3`). Focused dirty GREEN passed 2 tests in `swift-test-helper-client-removal-proof-green.log` (SHA-256 `4fc7f0ed4063a4be98133dac12f158ab28257d9c9546f4e6f2fad222e7d61aed`), and the exact staged export independently passed the same 2 tests in `swift-test-helper-client-removal-proof-twelfth-exact.log` (SHA-256 `e593edf10a2107aeff338f79ddf6173e65cfc598f84de809bb3d6e9c7cd9f632`). The complete exact export passed 235 tests in 17 suites in `swift-test-full-twelfth-exact.log` (SHA-256 `53d288a4a6be563c2a9a753185a12af12d46b0f1cc541d5db9a5d64c675d3fd2`). The complete dirty tree passed 242 tests in 18 suites in `swift-test-full-twelfth-dirty.log` (SHA-256 `83648746d2c034818dde2d3a2d016619f77e94771805d6190e760b2001b4b27d`); its seven broad-removal tests remain unaccepted remainder.
- E-189 — 2026-08-05T23:26:05+0200 — Exact Debug and Release `LidlessCore` builds passed (`swift-build-core-debug-twelfth-exact.log`, SHA-256 `72bd4ce6ca8a14d3d88fe621a89680b918ca4f2b75af720921e6215e221685fa`; `swift-build-core-release-twelfth-exact.log`, SHA-256 `3a8c5f96117153f1b78c63e51ef213b661732e72f05b8c4693a158bbe2dfb03b`). All 25 App, 4 helper, and 1 widget source files passed macOS 15 Swift 6 complete strict-concurrency typechecking with warnings-as-errors (`swiftc-all-products-typecheck-twelfth-exact.log`, SHA-256 `70c93240a31db30d3e02e94a9cf357dad423803627565a91edd16f08bee4f7f8`). With `CODE_SIGNING_ALLOWED=NO` and linker ad-hoc signing explicitly disabled, all three exact source sets compiled and linked in Debug and optimized Release (`direct-all-products-debug-twelfth-exact.log`, SHA-256 `459f75cbf8e2041b8205b35dde38144f634310b848c15d988bbd3dbf2d3d1be5`; `direct-all-products-release-twelfth-exact.log`, SHA-256 `4f2465386bd0d11e451b75bce049b20fec51c84f3893eeef18094bbfe7d2a3d1`). No product was launched.
- E-190 — 2026-08-05T23:26:05+0200 — `artifact-inspection-twelfth-exact.log` (SHA-256 `cb1f6d3ce1c86581f93d4a449c9663f3166db91efeaba55f93ac44598de01fd3`) preserves hashes, modes, architectures, UUIDs, Mach headers, build-version commands, absence of `LC_CODE_SIGNATURE`, and `codesign`'s unsigned result for all six outputs. `config-plist-entitlement-inspection-twelfth-exact.log` (SHA-256 `a64bd61b4775213de13983bff8f5429a262fe9d255ca59ccb25344b473bb54d8`) preserves source lint/decoded values, project bindings, and the absence of embedded Info.plists. `config-linkage-consistency-twelfth-exact.log` (SHA-256 `58ff086401dc2939c94f4c4486cd3a43ecdbb7d901c31841055d778a67ed9e6c`) independently asserts central IDs, app-group/helper/sentinel/plist/project consistency, one macOS 15 / SDK 26.5 build-version command, no signature or embedded plist, and captures linkage for every output. These loose unsigned executables are not bundle, entitlement, trust, registration, notarization, or release proof.
- E-191 — 2026-08-05T23:26:05+0200 — Independent adversarial review accepted the exact narrow client checkpoint and rejected the broad removal package. It confirmed that the selected enabled path requires a decoded exact-current restore reply plus a later registry-OFF observation, that any error stops before unregister, and that no wire-version change is involved. It also retained reentrancy, late arm delivery, unbounded XPC, restart/ABA, inactive-registration idempotence, cleanup retry, post-unregister verification, and complete uninstall as explicit gates. Separate daemon review confirmed that versioning, wake persistence/cancellation, stale status, optional-setting restoration, restart identity, inactive handling, timeouts, and source-shape test limitations prevent accepting the broader package.
- E-192 — 2026-08-05T23:26:05+0200 — Excluded invalid setup attempts from verification. A preliminary support observer selected an unwritable default module cache and failed before compilation; an attempted temporary-file patch was refused before mutation; the first typecheck harness used blocked process substitution; and the next omitted Swift's `-disable-sandbox`, so the Observation macro server failed under the nested managed sandbox. The corrected stable-toolchain typecheck disabled only Swift's nested compiler sandbox, used writable ignored caches, and passed. None of the invalid attempts launched a product, changed product source or the index, or supplied a safety verdict.
- E-193 — 2026-08-05T23:26:05+0200 — Working-tree and staged `git diff --check` passed in `exact-index-and-diff-check-twelfth-preledger.log`. Final pre-commit main-checkout preservation passed exactly in `main-preservation-twelfth-precommit.log` (SHA-256 `dce7aaf668fc42925d255be867037684698a3e961453f659997f367765645e24`): `main` remains at `7f17aaca11bc6228bed48b9265d63b9e576cdea7`, its index and tracked diff are clean, all three `.playwright-mcp` paths retain their recorded mode/size/SHA-256 values, and the complete NUL-status digest remains `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`.
- E-194 — 2026-08-05T23:26:05+0200 — No App/helper/widget process was launched; no helper install, activation, registration, approval, unregister, live XPC, `pmset`, sleep setting, sleep/wake, hardware, authentication, plugin/provider/connector, Figma, network publication, release, notarization, merge, push, or main-checkout mutation was performed. Project-native Xcode build/analyze was not retried after the established managed-sandbox and automatic LaunchServices side-effect constraints; strict Swift checks and direct explicitly unsigned compilation/linking are the bounded static evidence.
- E-195 — 2026-08-05T23:26:05+0200 — The checkpoint is prepared under subject `safety: require current proof before helper deregistration`. Exactly the reviewed enabled-branch HelperClient hunk, focused two-test regression file, and this append-only ledger are selected. All rejected daemon-removal, AppState, monitor, SetupPane, smoke-test, orchestration, and design remainder stays unstaged. `State: IN_PROGRESS` is intentionally retained; after the single local commit the supervisor must authenticate the exact remaining tree in a fresh rolling manifest before another invocation.

## Thirteenth recovery audit — authenticated removal/support remainder

- E-196 — 2026-08-05T23:34:22+0200 — Read the canonical handoff, immutable starting-state manifest, rolling remainder manifest and adjacent sidecar, progress log, decision log, architecture, design-reset brief, and this complete append-only ledger. The canonical handoff SHA-256 `95bdacdde663c642c2f97d532c1ec2b931e94a7dfcda47b8031e011ab3944831` and immutable-manifest SHA-256 `d84065171a261e24ae574b98164132472ff1e8bb635647403d814b9fcf58c36a` matched their supplied values. The sidecar-recorded rolling-manifest SHA-256 `86d911a58eaa63dcf5c58e280734e9d7788c2c313674bb85975308ae99cf1272` matched the manifest bytes. A repository-wide scan found no `AGENTS.md`, `CLAUDE.md`, `CODEX.md`, `GEMINI.md`, or `.cursorrules` file.
- E-197 — 2026-08-05T23:34:22+0200 — Applied only the authenticated rolling manifest as recovery authority. The feature canonical path, two-worktree linked topology, branch, HEAD `23bf93956da12c928c525835bf552615a08cd362`, Git admin/common directories, clean index, complete 13-path dirty inventory, every recorded status/type/mode/size/raw SHA-256, NUL-status digest `7b6479eddba2f04883948c3c8c1a2d3ee6649f6707f6226b8f5d73c3962baa76`, and tracked binary-diff digest `05cd94be1ffc9ca2a706a1e237b5f58b78578ee14911481b093e9b6545133b86` matched exactly. Starting HEAD `7f17aaca11bc6228bed48b9265d63b9e576cdea7` remains an ancestor through the twelve named checkpoint commits. Recovery passed before this append; the top-level `State: IN_PROGRESS` remains correct.
- E-198 — 2026-08-05T23:34:22+0200 — Independently reverified the rolling manifest's main-checkout record without editing it: canonical path and linked topology, `main` at `7f17aaca11bc6228bed48b9265d63b9e576cdea7`, clean index, complete three-path `.playwright-mcp` inventory, every recorded status/type/mode/size/raw SHA-256, NUL-status digest `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`, and empty tracked binary-diff digest matched exactly.
- E-199 — 2026-08-05T23:34:22+0200 — Two preliminary read-only verifier summaries were discarded: the first used a BSD-`awk` NUL-record count and lacked fail-fast handling, and the second omitted a semicolon in a Perl count expression. Neither changed a file or supplied a state verdict. The corrected explicit Bash verifier used strict failure handling, order-independent inventory comparison, and reproduced every field recorded in E-197 and E-198 before this ledger append.

## Fourteenth recovery audit — authenticated removal/support remainder

- E-200 — 2026-08-05T23:57:41+0200 — Read the canonical handoff, immutable starting-state manifest, authenticated rolling remainder manifest and adjacent sidecar, progress log, decision log, architecture, and design-reset brief in full. The canonical handoff SHA-256 `95bdacdde663c642c2f97d532c1ec2b931e94a7dfcda47b8031e011ab3944831` and immutable-manifest SHA-256 `d84065171a261e24ae574b98164132472ff1e8bb635647403d814b9fcf58c36a` matched their supplied values. The sidecar-recorded rolling-manifest SHA-256 `8101a49db07a51e04843fc0dbb0ce9ec61df7f60b40fe5aae68a3ee0ff559a4f` matched the manifest bytes. A repository-wide scan found no `AGENTS.md`, `CLAUDE.md`, `CODEX.md`, `GEMINI.md`, or equivalent instruction file.
- E-201 — 2026-08-05T23:57:41+0200 — Applied only the authenticated rolling manifest as recovery authority. The feature canonical path, two-worktree linked topology, branch, HEAD `23bf93956da12c928c525835bf552615a08cd362`, Git admin/common directories, clean index, complete 16-path dirty inventory, every recorded status/type/mode/size/raw SHA-256, NUL-status digest `c44201cb6f9d4acf97b0c7e89b283f0914df153efb65b45315589dac7394b567`, and tracked binary-diff digest `c83608bd6f9375f21e0a8da71bd77b2b0d86a4a654d9a3d1bbffde7cce8b948b` matched exactly. Starting HEAD `7f17aaca11bc6228bed48b9265d63b9e576cdea7` remains the recorded baseline; the top-level `State: IN_PROGRESS` was already correct and remains unchanged.
- E-202 — 2026-08-05T23:57:41+0200 — Independently reverified the rolling manifest's main-checkout record without editing it: canonical path and linked topology, `main` at `7f17aaca11bc6228bed48b9265d63b9e576cdea7`, clean index, complete three-path `.playwright-mcp` inventory, every recorded status/type/mode/size/raw SHA-256, NUL-status digest `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`, and empty tracked binary-diff digest matched exactly. Recovery passed before this append.

## Fourteenth-checkpoint ruling — avoid monitor observer retain cycles

The preserved helper-removal package is not coherent enough to accept as one
checkpoint. Independent client, daemon, and supporting-surface audits retained
hard blockers: changed daemon removal behavior still advertises helper protocol
version 6; wake cancellation and persistence are not one transaction; uninstall
status is captured before wake cleanup; cleanup failure can leave stale wake
persistence and a disabled file sink; optional managed-setting restoration
failures are discarded; removal fences are process-local and lost on restart;
the app can report uninstall success despite a later enabled/not-responding
registration observation; failure copy can promise supervision even when the
service is not registered; and the current source-shape tests do not execute
faults, races, reply loss, or restart behavior. AppState, HelperClient,
HelperDaemon, SetupPane, helper-removal policy/tests, smoke/coordinator tests,
orchestration, and design bytes therefore remain unstaged.

This invocation selects only the three block-based notification callbacks in
`SystemStateMonitor` and `PMSetThermalMonitor`. Each outer observer block now
captures its monitor weakly before creating the already weak-capturing
MainActor task. The bounded invariant is that these NotificationCenter blocks
do not themselves strongly retain their monitor owners. A focused
source-integration regression fixes the exact expected callback shapes in each
`start()` section and reproduced the old HEAD failure in an isolated export.

This checkpoint does not prove runtime deallocation or notification delivery,
does not make `SystemStateMonitor.start()` idempotent, does not show an owner
calling either `stop()`, does not prove observer-token removal, and does not
prove termination of the thermal polling task after owner loss. No process,
notification, registration, XPC, power-setting, sleep/wake, or hardware action
was exercised.

### Fourteenth-checkpoint finding and verification matrix

| ID | Invariant | Exact checkpoint evidence | Remaining boundary | Ruling |
| --- | --- | --- | --- | --- |
| S-33 | Block-based workspace sleep/wake and thermal-state observers do not strongly retain their monitor owners | Corrected isolated-HEAD RED observes two System and one Thermal strong outer callbacks; exact staged GREEN requires two and one outer `[weak self]` captures respectively, preserves the already weak MainActor tasks, and rejects any strong outer callback in those `start()` sections | Regression is source-structural; runtime deallocation, delivery, stop/removal, repeated start, and polling-task termination remain unproved | CHECKPOINT VERIFIED OFFLINE — LIFECYCLE/RUNTIME GATES OPEN |
| V-18 | Exact selected code passes focused, complete, strict compile, and unsigned build checks | Pre-ledger tree `abd8fc9d7ad191f74ecb522e1b10cb492744d0be` passed 2 focused and 237 complete exact tests, Debug/Release core builds, strict Swift 6 typechecking, and direct Debug/Release app/helper/widget compilation and linking | Project-native Xcode build/analyze was not retried under the established managed-sandbox and automatic LaunchServices side-effect constraints | PASS FOR EXACT OFFLINE CODE — XCODE GRAPH OPEN |
| V-19 | Artifact and configuration inspection remains bounded to observed loose unsigned outputs and source configuration | All six direct outputs lacked `LC_CODE_SIGNATURE`, reported unsigned, and had their hashes, modes, architectures, UUIDs, build-version commands, and linkage preserved; six source plist/entitlement files plus project bindings and central identifiers were inspected | These are not Xcode-produced bundles and prove no embedded plist/entitlement, signing identity, XPC trust, registration behavior, notarization, runtime behavior, or release readiness | PARTIAL — BUNDLE/SIGNING/RUNTIME GATES OPEN |

- E-203 — 2026-08-06T00:09:21+0200 — Reproduced the complete authenticated dirty-package baseline before accepting any remainder claim. The first attempt selected Xcode beta's Swift 6.4 and an unwritable module cache, so it failed before compilation and supplies no verdict (`swift-test-fourteenth-baseline.log`, SHA-256 `73331a8c69bf0bd40e0ef39c6840940c062c6f37bc157d81724d95851b8caef4`; toolchain log SHA-256 `fd8bf7ac92a5d602175129c311272f44899c7b659b91e5636f449a9cbed66dc1`). The corrected stable Xcode 26.5 Swift 6.3.2 run used an ignored writable module cache and passed 246 tests in 19 suites (`swift-test-fourteenth-baseline-stable.log`, SHA-256 `fe7cde5cfca22d0db4b827135d6954099a2cb863c525539dde635f82916725fc`; toolchain log SHA-256 `3b522b180ca3ed75a1913e53f1ee338426de7ec767660f792534cc162827fe93`). This was only a dirty-tree baseline and did not validate the broad removal transaction.
- E-204 — 2026-08-06T00:09:21+0200 — Reviewed every path and hunk in the 16-path authenticated remainder and traced the claimed removal invariants through the client, app state, daemon, UI, policies, tests, and documents. Three independent read-only audits rejected the broad removal package for the version collision, non-transactional wake ownership, pre-cleanup status, cleanup retry/persistence, discarded restoration errors, restart durability, stale deregistration success, inaccurate failure copy, dead/duplicated policy, source-shape-only coverage, and stale or unverifiable orchestration/design claims recorded above. The exact selected scope is only monitor observer-block ownership.
- E-205 — 2026-08-06T00:09:21+0200 — Established corrected RED before accepting the monitor source changes. An exact `git archive` export of HEAD `23bf93956da12c928c525835bf552615a08cd362` with only the new regression overlaid failed both focused tests: HEAD contained zero weak and two strong System outer callbacks, and zero weak and one strong Thermal outer callback (`swift-test-monitor-observer-red-corrected-fourteenth.log`, SHA-256 `a8bdc950e72de43fcc45aa447de724865baa1ee984454f842c8204e2f12e8f93`). The first RED attempt selected the Thermal protocol declaration instead of the implementation's `start()` section and was discarded as an invalid test setup (`swift-test-monitor-observer-red-fourteenth.log`, SHA-256 `c35c593091becd2328ffa8ac95f4df62316fa4a1c0f3f72fd30176d4e7fc2614`).
- E-206 — 2026-08-06T00:09:21+0200 — Changed only two System workspace-notification outer blocks and one Thermal notification outer block to `[weak self]`; the existing inner MainActor tasks remain weak. Added two focused source-integration tests that isolate each concrete `start()` through `stop()` section, require the exact weak outer/inner counts, and reject the old strong outer shape. Working-tree focused GREEN passed 2 tests in 1 suite (`swift-test-monitor-observer-green-fourteenth.log`, SHA-256 `27cd4e84f0e20094a02fe03907e62482ea8f8672f7a91d576c1862916c13fba1`).
- E-207 — 2026-08-06T00:09:21+0200 — The immutable pre-ledger Git-index tree is `abd8fc9d7ad191f74ecb522e1b10cb492744d0be`; its three-path staged binary-diff SHA-256 is `1611653f03ca802f0661ebda4f24f8193c395a1098c2f282901e47c5b5c5f32e`. An independent exact-index export passed the 2 focused tests (`swift-test-monitor-observer-exact-fourteenth.log`, SHA-256 `1c127965af005fb6f7f75f3d562ad692b562ef33c5631caa5442ff6527d87e35`) and 237 complete tests in 18 suites (`swift-test-full-exact-fourteenth.log`, SHA-256 `7e215aa88dd47fceb7887fa36426a25ef82071af5d7d2a205d1a908bb9cc9ef6`). The complete dirty tree passed 248 tests in 20 suites (`swift-test-full-dirty-fourteenth.log`, SHA-256 `8a4ea0c64f27f5c38137b7f702e52cd88b97745fa16949557219eb731f1599ca`); its nine extra broad-removal tests are deliberately unaccepted remainder.
- E-208 — 2026-08-06T00:09:21+0200 — Exact Debug and Release `LidlessCore` builds passed (`swift-build-core-debug-exact-fourteenth.log`, SHA-256 `072aa9fcf0d44386495557de424e715c8dcf1e339227afb7e2b15b36389075dc`; Release SHA-256 `c59e5cb4376cb1c99e165f05698bceecd930fc42f18d0d9e2034afe581d65729`). All 25 App, 4 helper, and 1 widget source files passed macOS 15 Swift 6 complete strict-concurrency typechecking with warnings-as-errors (`swiftc-all-products-typecheck-exact-corrected-fourteenth.log`, SHA-256 `70c93240a31db30d3e02e94a9cf357dad423803627565a91edd16f08bee4f7f8`). The first harness incorrectly applied `-parse-as-library` to the helper's top-level `main.swift` and was discarded after the App typecheck passed but before a valid helper verdict (`swiftc-all-products-typecheck-exact-fourteenth.log`, SHA-256 `e09ee835ab2d30af48075e10a52e5e5fd66517972df88efe9df37c9c1b3fa72e`).
- E-209 — 2026-08-06T00:09:21+0200 — With `CODE_SIGNING_ALLOWED=NO` and linker ad-hoc signing explicitly disabled, every exact App, helper, and widget source compiled and linked in Debug and optimized Release (`direct-all-products-debug-exact-fourteenth.log`, SHA-256 `b9cfbb237bb48a948561f6cb75c077fe826070bdf673a44ef596a563b6644899`; Release SHA-256 `f2dcc1294c66fba5e08c2268a98edee2b5ed5c32b2a1e2c74693a4391c322bd2`). `artifact-inspection-exact-fourteenth.log` (SHA-256 `dcbe2436b1f01820ea58f3dd5540c81af6e38ec8881c93851bb7ceb1c6257280`) preserves hashes, modes, thin arm64 architecture, UUIDs, macOS 15 / SDK 26.5 build-version commands, linkage, absence of `LC_CODE_SIGNATURE`, and unsigned results for all six loose outputs. `config-plist-entitlement-inspection-exact-fourteenth.log` (SHA-256 `375b71a3924ca855e88f85d6d698b41a276652dd6fee722daf913c3a056d4169`) preserves source lint/decoded values for all six plist/entitlement files plus project bindings and central identifiers. No product was launched, and these outputs are not runtime or bundle trust evidence.
- E-210 — 2026-08-06T00:11:32+0200 — Final working-tree and staged `git diff --check` passed, and the complete staged diff was reviewed as exactly the two monitor capture changes, the two-test regression file, and this append-only ledger. Final pre-commit main-checkout preservation passed in `main-preservation-fourteenth-precommit.log` (SHA-256 `de2d25f29724e3ecd3d6af3f91f87c752b7307b154ced7de8db29abd36122673`): the canonical paths and two-worktree topology remain exact; `main` remains at `7f17aaca11bc6228bed48b9265d63b9e576cdea7`; its index and tracked diff remain clean; all three `.playwright-mcp` paths retain the recorded type/mode/size/SHA-256; the NUL-status digest remains `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`; and the tracked binary-diff digest remains empty-file SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.
- E-211 — 2026-08-06T00:11:32+0200 — No App/helper/widget process was launched; no helper install, activation, registration, approval, unregister, live XPC, `pmset`, sleep setting, sleep/wake, hardware, authentication, plugin/provider/connector, Figma, network publication, release, notarization, merge, push, or main-checkout mutation was performed. Project-native Xcode build/analyze was not retried after the established managed-sandbox and automatic LaunchServices side-effect constraints. All accepted build evidence is explicitly unsigned, offline, and non-runtime.
- E-212 — 2026-08-06T00:11:32+0200 — The checkpoint is prepared under subject `safety: avoid monitor observer retain cycles`. Exactly the two monitor files, focused regression file, and this append-only ledger are selected. All rejected helper-removal, AppState, HelperClient, HelperDaemon, SetupPane, coordinator/smoke-test, orchestration, and design remainder stays unstaged. `State: IN_PROGRESS` is intentionally retained; after this single local commit the supervisor must authenticate the exact remaining tree in a fresh rolling manifest before another invocation.

## Fifteenth recovery audit — authenticated removal/support remainder

- E-213 — 2026-08-06T00:19:23+0200 — Read the canonical handoff, immutable starting-state manifest, authenticated rolling remainder manifest and adjacent sidecar, progress log, decision log, architecture, design-reset brief, and this complete append-only ledger. The canonical handoff SHA-256 `95bdacdde663c642c2f97d532c1ec2b931e94a7dfcda47b8031e011ab3944831` and immutable-manifest SHA-256 `d84065171a261e24ae574b98164132472ff1e8bb635647403d814b9fcf58c36a` matched their supplied values. The sidecar-recorded rolling-manifest SHA-256 `35a5d11cf8716240d6f9b451b8767df4fb03c6947cae702c17c38c5c43794480` matched the manifest bytes. A repository-wide hidden-file scan found no `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `.cursorrules`, `copilot-instructions.md`, or matching instruction file.
- E-214 — 2026-08-06T00:19:23+0200 — Applied only the authenticated rolling manifest as recovery authority. The feature canonical path, exact two-worktree linked topology, branch, HEAD `c6c3fdcc662fa800c80d1efeddf5bf9ee2d39a04`, Git admin/common directories, clean index, complete 13-path dirty inventory, every recorded status/type/mode/size/raw SHA-256, NUL-status digest `e4ad4f2d08be2c4f680473ee475878481409e071c18b0d010dfabc0c6df14749`, and tracked binary-diff digest `46ecffbbe3d308dd77d5545c6580c4d716cbc82ad280f832d7b727655899faa7` matched exactly. A second independent read-only audit reproduced the same fields and bytes. Recovery passed before this append; the top-level `State: IN_PROGRESS` remains correct.
- E-215 — 2026-08-06T00:19:23+0200 — Independently reverified the rolling manifest's main-checkout record without editing it: canonical path and linked topology, `main` at `7f17aaca11bc6228bed48b9265d63b9e576cdea7`, clean index, complete three-path `.playwright-mcp` inventory, every recorded status/type/mode/size/raw SHA-256, NUL-status digest `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`, and empty tracked binary-diff digest `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` matched exactly. A separate read-only reviewer repeated the audit with optional Git locks disabled and confirmed the main checkout remained unchanged.
- E-216 — 2026-08-06T00:19:23+0200 — Discarded three preliminary read-only summary defects before accepting the recovery verdict: BSD `awk` counted the NUL-delimited feature status stream as one record, an order-sensitive inventory comparison reported only manifest-array versus Git-stream ordering, and a main-common-directory probe resolved relative `.git` against the feature shell directory. Corrected Perl counting, order-independent tuple comparison, and absolute Git path-format checks produced the exact results in E-214 and E-215. The preliminary probes changed no file and supplied no recovery authority.

## Fifteenth-checkpoint ruling — classify helper deregistration state

The preserved broad helper-removal package is not coherent enough to accept as
one checkpoint. Complete diff review and independent client, daemon, and
supporting-surface audits retained the protocol-version collision, in-memory
removal fences that disappear on daemon restart, enabled-to-enabled ABA,
unbounded XPC, non-transactional wake persistence and cancellation, status
captured before cleanup, discarded optional-setting restoration failures,
missing post-unregister proof, inaccurate UI completion copy, and source-shape
tests that do not execute faults or races. The daemon, AppState, SetupPane,
removal-commit latches, broad policy/tests, smoke/coordinator tests,
orchestration, and design bytes therefore remain unstaged.

The selected defect is narrower. The prior client treated every
`SMAppService.Status` other than `.enabled` as equivalent, accepted anything
other than positive registry-ON evidence, and then always invoked
`unregister()`. The installed ServiceManagement SDK distinguishes an
explicitly unregistered service from approval-required and not-found/error
states, and documents that unregistering an already unregistered service
returns `kSMErrorJobNotFound`. The selected repair maps only `.notRegistered`
to an inactive state, maps approval-required, not-found, and future states to
unknown, and chooses an explicit action rather than erasing the distinction
into a Boolean. Enabled registration retains the previously checkpointed
two-source restore proof and selects `.unregister`; explicitly inactive
registration requires an exact independent registry-OFF observation and
selects `.alreadyInactive`, which returns before any unregister call. Unknown
states fail closed. A second coarse status classification must still match the
first before either action is taken.

This is a point-in-time client authorization fence only. It cannot detect an
enabled-to-enabled daemon replacement, cannot make the registry read and
unregister atomic, and cannot prevent a change after the final check. It does
not bound XPC, identify one daemon instance, prove helper cleanup or wake
cancellation, verify unregister success, prove `.notRegistered` after return,
or prove that the already-inactive service remains absent while the method
returns. No wire or daemon behavior changes, so this checkpoint introduces no
helper-version change. No process, ServiceManagement operation, helper XPC,
registry mutation, power-setting change, sleep/wake event, or hardware action
was exercised.

### Fifteenth-checkpoint finding and verification matrix

| ID | Invariant | Exact checkpoint evidence | Remaining boundary | Ruling |
| --- | --- | --- | --- | --- |
| S-34 | Only an explicitly `.notRegistered` service may complete through the already-inactive path, and that path never asks ServiceManagement to unregister | The pure action matrix requires independent exact OFF for `.inactive`; the exact source regression maps only `.notRegistered` to inactive, requires two policy calls and one unregister call, and proves the inactive action returns before the unregister action | The registry may change after the last observation; the later refresh is not accepted as proof that registration remains absent | CHECKPOINT VERIFIED OFFLINE — LIVE/POSTCONDITION GATES OPEN |
| S-35 | Approval-required, not-found/error, future, or coarsely changed registration evidence fails closed before client deregistration | Exact source maps `.requiresApproval`, `.notFound`, and `@unknown default` to unknown; pure policy rejects unknown; an immediate second classification must equal the first before the action switch | Same-category enabled-to-enabled replacement, cross-process mutation, and post-check/pre-unregister races are not detected | CHECKPOINT VERIFIED OFFLINE — ABA/TRANSACTION GATES OPEN |
| S-36 | The action distinction cannot be accidentally collapsed into unconditional unregister within the selected policy surface | The staged policy exposes only `RegistrationRemovalAction` plus `removalAction`; the legacy Boolean wrapper, app-quiescence policy, `removalCommitted`, daemon, and broad removal bytes are absent from the exact index | Other callers and complete uninstall orchestration remain outside this checkpoint; no runtime ServiceManagement sequence was executed | PASS FOR BOUNDED SCOPE — FULL REMOVAL OPEN |
| V-20 | Exact selected code passes focused, complete, strict compile, and explicitly unsigned Debug/Release checks | Pre-ledger tree `62ffda5157ac9176a48e895a8f5db14cbc8340db` passed 4 focused tests and 239 complete exact tests; Debug/Release core builds, Swift 6 complete-concurrency typechecking with warnings-as-errors, and direct Debug/Release App/helper/widget links passed | Project-native Xcode build/analyze was not retried under the established managed-sandbox and automatic LaunchServices side-effect constraints | PASS FOR EXACT OFFLINE CODE — XCODE GRAPH OPEN |
| V-21 | Artifact/config inspection remains bounded to loose unsigned outputs and source configuration | All six direct outputs are thin arm64 macOS 15 / SDK 26.5 executables without `LC_CODE_SIGNATURE` and report unsigned; six source plist/entitlement files linted and decoded, and project bindings plus central identifiers were inspected | The outputs are not bundles and prove no embedded plist/entitlement, signing identity, XPC trust, registration behavior, notarization, runtime behavior, or release readiness | PARTIAL — BUNDLE/SIGNING/RUNTIME GATES OPEN |

- E-217 — 2026-08-06T00:46:41+0200 — Reproduced the complete authenticated dirty-package baseline before accepting any remainder claim. Stable Xcode 26.5 Swift 6.3.2 passed 248 tests in 20 suites in `swift-test-fifteenth-baseline.log` (SHA-256 `be9c479e39be1b528cc9d9496dce0d5c492b69a3d0f36aa0ea1c82d836320dda`). This was only a baseline and did not validate the broad removal transaction. Complete review of every authenticated path and hunk, plus independent client, daemon, and support/documentation audits, rejected the broad package for the version, transaction, restart/ABA, wake persistence, stale-status, optional-restoration, timeout, postcondition, UI-copy, source-test, and stale-documentation defects recorded above.
- E-218 — 2026-08-06T00:46:41+0200 — Inspected the installed Xcode 26.5 ServiceManagement header rather than relying on remembered API behavior. `servicemanagement-registration-contract.log` (SHA-256 `7421ce0c1aa7e0959f490fbcce1e09ee89ecc3632a4907bb19d7771cebaac849`) preserves the SDK definitions: `.notRegistered` means never registered or unregistered, `.enabled` means registered and eligible, `.requiresApproval` is a successful registration lacking current consent, `.notFound` represents an error/no service, and both unregister variants report `kSMErrorJobNotFound` when already unregistered. The old client fallthrough therefore could call unregister for explicit inactivity and treated error/approval states as removable.
- E-219 — 2026-08-06T00:46:41+0200 — Established compile-time RED before adding the action policy. The focused regression against the preserved pre-fix package required the absent `RegistrationRemovalAction`/`removalAction` surface and failed compilation (`swift-test-helper-removal-registration-action-red.log`, SHA-256 `d6813699dda55511a7c5f995611f22845d8361aada84802852644c237bed27e5`). The exact old client source separately showed one non-enabled fallthrough followed by unconditional `Self.unregisterDaemon()`; no existing API could express an already-inactive no-op.
- E-220 — 2026-08-06T00:46:41+0200 — Implemented the pure registration/action classifier and client wiring only: two exact-evidence action calls, fail-closed unknown mapping, a coarse category recheck, an early already-inactive return, and one enabled-only unregister call. The existing enabled two-source proof remains intact. Independent re-review accepted this bounded action split only after confirming the exact snapshot omits `canBeginAppRemoval`, the Boolean `canRemoveRegistration` wrapper, and every `removalCommitted` byte. The reviewer also caught the overbroad transition-error sentence `Nothing was deregistered`; the final copy truthfully says only that Lidless did not request deregistration, and read-only re-review cleared the blocker.
- E-221 — 2026-08-06T00:46:41+0200 — The immutable pre-ledger Git-index tree is `62ffda5157ac9176a48e895a8f5db14cbc8340db`; its four-path staged binary-diff SHA-256 is `83f8cc189c84e55c2901590abec9384686c2bb269daf0b710ad2a4f17e690746`. Every selected index blob matched the independent exact snapshot and a complete `git checkout-index` export byte-for-byte; the exact export contained no other changed or missing HEAD path and both new files retained mode `100644`. Working and staged diff checks passed in `exact-index-and-diff-check-fifteenth-registration-preledger.log` (SHA-256 `4e94b3701859131d32ac546b7bb31572ced47699b25527c44e319594fdc8fbec`).
- E-222 — 2026-08-06T00:46:41+0200 — Final exact focused GREEN passed 4 tests in 2 suites (`swift-test-helper-removal-registration-exact-final.log`, SHA-256 `eb29c3d90ee5221856b28abfb8455e8f4ab855bbe08291e5ba316b40750e88f9`). The same exact snapshot passed all 239 tests in 19 suites (`swift-test-full-fifteenth-registration-exact-final.log`, SHA-256 `67f06ab92751b6f0ac784122995fb36e60f03e093cd8198b606ef58fc0c34b8b`). The complete preserved dirty tree passed 250 tests in 21 suites (`swift-test-full-fifteenth-dirty-final-3.log`, SHA-256 `92b5a4b7966bec281b0f869dfc98dfddba2c464670a7607af712204179029979`); its eleven additional broad-removal tests are deliberately not accepted as transaction, fault, concurrency, or runtime proof.
- E-223 — 2026-08-06T00:46:41+0200 — Exact Debug and Release `LidlessCore` builds passed (`swift-build-core-debug-fifteenth-registration-exact.log`, SHA-256 `f1d59d321ae8c936b1cb473a0143f51923d353c84c2a244f7770f1281d2f3057`; Release SHA-256 `994d13847db172a24ad85fb795953a49cd8a4caa3c0a76fa0663a8da20f8ed62`). All 25 App, 4 helper, and 1 widget source files passed macOS 15 Swift 6 complete strict-concurrency typechecking with warnings-as-errors (`swiftc-all-products-typecheck-fifteenth-registration-exact-final.log`, SHA-256 `6b78a776f18f1f6dc1959942f1e8f474a9e0e343892e68105767bf7e23c9b620`). With `CODE_SIGNING_ALLOWED=NO` and linker ad-hoc signing disabled, all exact sources compiled and linked in Debug and optimized Release (`direct-all-products-debug-fifteenth-registration-exact-final.log`, SHA-256 `90a60d0f64dc0ceb7049fdb33361365f9884ca1879da81005ffcc608e81d38a6`; Release SHA-256 `fa26c59cf872ca1cedaed6fe0ba2767edfe0594f55f52ed08b5172b418b4c08f`). No product was launched.
- E-224 — 2026-08-06T00:46:41+0200 — `artifact-inspection-fifteenth-registration-exact-final.log` (SHA-256 `c27493b5c42c22ee343f9b76c65f9a821be07ceea3705c5328be6ee5eacafaf9`) preserves hashes, modes, thin arm64 architecture, macOS 15 / SDK 26.5 build-version commands, absence of `LC_CODE_SIGNATURE`, and `codesign`'s unsigned result for all six loose outputs. `config-plist-entitlement-inspection-fifteenth-registration-exact-final.log` (SHA-256 `e7ff612f5e7f0ea6f55f85cc462a986241597717341c40a6628ca2b4aee15a2a`) preserves lint and decoded values for all six source plist/entitlement files plus project bindings and central identifiers. These outputs are not signed bundles or ServiceManagement/runtime evidence.
- E-225 — 2026-08-06T00:46:41+0200 — Discarded three verifier-harness defects without using them as evidence. A first focused filter used human-readable suite titles and ran zero tests (`swift-test-helper-removal-registration-focused-final.log`, SHA-256 `972f3597744b836de98e5dfc316ad923a48c90a8d95e71b236d0394921cb11a1`); the corrected type-name filter ran the 4 tests in E-222. A first direct typecheck omitted Swift's required `-disable-sandbox`, so the Observation macro server was blocked before a valid App result; the corrected command passed all products in E-223. A first main-preservation loop shadowed zsh's special `path` array and aborted when `stat` became unreachable (`main-preservation-fifteenth-precommit.log`, SHA-256 `c18aebc78bf6c7ff0fcf6911ccbbeed63a47ba6d7b65b26da652b1a661ea6efa`); the corrected verifier uses task-specific variable names. None of these attempts changed product source, supplied a safety verdict, or launched a product.
- E-226 — 2026-08-06T00:49:29+0200 — Reviewed the complete staged code/test diff and the complete append-only ledger diff. The first staged-review harness incorrectly expected `State: IN_PROGRESS` on line 1 rather than below the ledger title and stopped without a verdict (`final-staged-review-fifteenth-registration.log`, SHA-256 `a6f34ab3cd247cb351c00084b3d02538cd1b628a687316adc03442f136d0277f`). The corrected review (`final-staged-review-fifteenth-registration-corrected.log`, SHA-256 `a2ac648cda5eb054d4aea5fcadae5879001025af96d53db519805b9a32af236a`) confirmed the exact five-path stage, `State: IN_PROGRESS`, all four selected code/test blobs equal to the independently tested snapshot, and both working and staged diff checks passing. Its pre-final-evidence index tree was `6f6aca79c373ecf48ed95fe110aa7557e95ad07d`; only these final evidence entries are appended afterward.
- E-227 — 2026-08-06T00:49:29+0200 — Final pre-commit main-checkout preservation passed in `main-preservation-fifteenth-final-precommit.log` (SHA-256 `8f1dab16b730a286e5190b22c9fd06e9fd523e392cf4e1b762c7ee9c2c9bf9d5`): both canonical paths, the two-worktree topology, feature branch/HEAD and Git directories remain exact; `main` remains at `7f17aaca11bc6228bed48b9265d63b9e576cdea7`; its index and tracked diff remain clean; all three `.playwright-mcp` files retain the recorded type/mode/size/SHA-256; the NUL-status digest remains `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`; and the tracked binary-diff digest remains empty-file SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.
- E-228 — 2026-08-06T00:49:29+0200 — No App/helper/widget process was launched; no helper install, activation, registration, approval, unregister, live XPC, `pmset`, sleep setting, sleep/wake, hardware, authentication, plugin/provider/connector, Figma, network publication, release, notarization, merge, push, or main-checkout mutation was performed. Project-native Xcode build/analyze was not retried after the established managed-sandbox and automatic LaunchServices side-effect constraints. Every accepted build result is explicitly unsigned, offline, and non-runtime.
- E-229 — 2026-08-06T00:49:29+0200 — The checkpoint is prepared under subject `safety: classify helper deregistration state`. Exactly the curated HelperClient registration/action hunk, narrow action policy, adapted enabled-proof source regression, two focused registration-action tests, and this ledger are selected. Every daemon, AppState, SetupPane, `removalCommitted`, Boolean-policy wrapper, broad removal test/policy, smoke/coordinator, orchestration, and design remainder stays unstaged. `State: IN_PROGRESS` is intentionally retained; after this single local commit the supervisor must authenticate the exact remaining tree in a fresh rolling manifest before another invocation.

## Sixteenth recovery audit — authenticated removal/support remainder

- E-230 — 2026-08-06T00:54:58+0200 — Read the canonical handoff, immutable starting-state manifest, authenticated rolling remainder manifest and adjacent sidecar, progress log, decision log, architecture, design-reset brief, CONTRIBUTING guidance, and this complete append-only ledger. The canonical handoff SHA-256 `95bdacdde663c642c2f97d532c1ec2b931e94a7dfcda47b8031e011ab3944831` and immutable-manifest SHA-256 `d84065171a261e24ae574b98164132472ff1e8bb635647403d814b9fcf58c36a` matched their supplied values. The sidecar-recorded rolling-manifest SHA-256 `7c5eb91bf52ad8e1445f54d9ff8574dae225663ad5ac3924e5743f40bf9f87ed` matched the manifest bytes. A repository-wide hidden-file scan found no `AGENTS.md`, `CLAUDE.md`, `CODEX.md`, `GEMINI.md`, `.cursorrules`, `copilot-instructions.md`, or matching instruction file.
- E-231 — 2026-08-06T00:54:58+0200 — Applied only the authenticated rolling manifest as recovery authority. The feature canonical path, exact two-worktree linked topology, branch, HEAD `01bf0c97021b20b0b4247388e97b10970830875a`, Git admin/common directories, clean index, complete 13-path dirty inventory, every recorded status/type/mode/size/raw SHA-256, NUL-status digest `39da5b6392f6e3eb9a002843c754338df5854e372a6c8a2a46dcdb4d84296d5e`, and tracked binary-diff digest `61245ff13899c085be13a8fbc969fb3b2a58628f09326db5ca9dda91eede1f93` matched exactly. Starting HEAD `7f17aaca11bc6228bed48b9265d63b9e576cdea7` remains an ancestor through the fifteen named checkpoint commits. Recovery passed before this append; the top-level `State: IN_PROGRESS` remains correct.
- E-232 — 2026-08-06T00:54:58+0200 — Independently reverified the rolling manifest's main-checkout record without editing it: canonical path and linked topology, `main` at `7f17aaca11bc6228bed48b9265d63b9e576cdea7`, clean index, complete three-path `.playwright-mcp` inventory, every recorded status/type/mode/size/raw SHA-256, NUL-status digest `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`, and empty tracked binary-diff digest `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` matched exactly. The main checkout remains untouched.
- E-233 — 2026-08-06T00:54:58+0200 — Discarded two preliminary recovery-inventory harness attempts before accepting the verdict: one command was rejected before execution because it included unnecessary temporary-file deletion, and the next read-only zsh loop shadowed the shell's read-only `status` parameter. The corrected loop used task-specific variable names and reproduced every file field recorded in E-231 and E-232. Neither preliminary attempt changed a file or supplied recovery authority.

## Sixteenth-checkpoint ruling — verify helper deregistration completion

The preserved broad helper-removal package is still not coherent enough to
accept as one checkpoint. Complete diff review and independent client, daemon,
and evidence-scope audits retained the unchanged protocol version despite
changed daemon behavior, restart-volatile removal latches, unbounded XPC,
enabled-to-enabled ABA, non-transactional wake persistence/cancellation,
status captured before cleanup, discarded optional-setting restoration
failures, inactive-registration cleanup gaps, and source-shape tests that do
not execute faults, races, reply loss, or restart behavior. The daemon,
AppState concurrency remainder, removal latches, broad policy/tests,
smoke/coordinator tests, orchestration progress/decisions, and design-reset
brief therefore remain outside this checkpoint.

The selected defect is the final client completion boundary. The prior client
returned after the already-inactive path, or after asynchronous unregister and
a refresh, without requiring an explicit final `.notRegistered` status plus a
fresh independent registry-OFF observation. AppState could consequently
delete local data and report success without that two-source final
postcondition. Both selected paths now converge on one synchronous final gate:
the XPC connection is invalidated, ServiceManagement is classified again, the
registry is read again, and only explicit inactivity plus exact OFF sets the
client to `.notInstalled`. An unregister error or failed postcondition sets
the client state to `.unknown` and reports that deregistration may already
have happened. Simulation is rejected by authoritative AppState policy before
helper work or success side effects and is also disabled in SetupPane.
Completion copy now says only that registration is inactive and the helper is
not registered; it does not claim helper bits, data, or every component was
removed.

This is point-in-time, sequential evidence only. The status and registry reads
are not atomic, do not identify one daemon instance, do not prevent another
process from registering or mutating after the reads, and do not prove helper
cleanup, wake cancellation, optional-setting restoration, crash/restart
durability, filesystem absence, signed XPC trust, or complete uninstall. The
integration checks are source-structural; no ServiceManagement, registry,
helper, app, sleep/wake, or hardware behavior was exercised.

### Sixteenth-checkpoint finding and verification matrix

| ID | Invariant | Exact checkpoint evidence | Remaining boundary | Ruling |
| --- | --- | --- | --- | --- |
| S-37 | Neither unregister nor the already-inactive branch can report completion without explicit final inactive registration and a fresh registry-OFF observation | The pure truth table accepts only `.inactive` plus `false`; exact source ordering makes both actions converge after any awaited unregister, then invalidates XPC, reads registration and registry synchronously, applies the gate, and assigns `.notInstalled` only afterward | The observations are sequential and non-atomic; no daemon identity, transaction token, or live ServiceManagement/registry execution exists | CHECKPOINT VERIFIED OFFLINE — ATOMICITY/LIVE GATES OPEN |
| S-38 | Ambiguous deregistration outcomes and simulation cannot become success | Unregister errors and final-proof failures set `.unknown` with non-assumptive recovery copy; a pure simulation policy and an AppState guard precede helper work, while SetupPane disables and explains the action in simulation | Source wiring is not an injected AppState/ServiceManagement runtime test; external mutation after proof remains possible | CHECKPOINT VERIFIED OFFLINE — RUNTIME/EXTERNAL-MUTATION GATES OPEN |
| S-39 | User-visible completion language is no stronger than the selected evidence | App notification, confirmation, success alert, failure alert, and footer regressions require “registration inactive / is not registered,” reject whole-removal and “remains installed” assumptions, and retain the manual normal-sleep fallback | Helper data/process/bits, login-item effects, cleanup completeness, and full uninstall are not asserted or proved | PASS FOR BOUNDED COPY — FULL REMOVAL OPEN |
| V-22 | Exact selected code passes focused, complete, strict compile, and explicitly unsigned Debug/Release checks | Pre-ledger tree `962f2bb03c5cd425045591b03becd243643cff5b` passed 5 completion tests, 4 related registration/client tests, and 244 complete exact tests; Debug/Release core builds, Swift 6 complete-concurrency typechecking with warnings-as-errors, and direct Debug/Release App/helper/widget links passed | Project-native Xcode graph build/analyze was not retried under the established nested-sandbox and automatic LaunchServices side-effect constraints | PASS FOR EXACT OFFLINE CODE — XCODE GRAPH OPEN |
| V-23 | Artifact/configuration inspection remains bounded to actual loose unsigned outputs and source configuration | All six direct outputs are thin arm64 macOS 15 / SDK 26.5 executables without `LC_CODE_SIGNATURE` and report unsigned; six source plist/entitlement files linted and decoded, and project bindings plus central identifiers were inspected | Outputs are not bundles and prove no bound entitlements, signing identity, XPC trust, registration behavior, notarization, runtime behavior, or release readiness | PARTIAL — BUNDLE/SIGNING/RUNTIME GATES OPEN |

- E-234 — 2026-08-06T01:20:34+0200 — Reproduced the complete authenticated dirty-package baseline before accepting any remainder claim. Stable Xcode 26.5 Swift 6.3.2 passed 250 tests in 21 suites in `swift-test-sixteenth-baseline.log` (SHA-256 `f0eaaaaf61c76dcaa833e313260d3ae87655ab4ebc40f15aadac820edbf73e3a`). This was baseline evidence only. Complete review plus three independent audits rejected the broad package for the protocol, transaction, restart/ABA, wake persistence, stale-status, cleanup, optional-restoration, timeout, inactive-path, test-evidence, and stale-documentation gaps recorded above.
- E-235 — 2026-08-06T01:20:34+0200 — Inspected the installed Xcode 26.5 ServiceManagement header instead of relying on remembered API behavior. `servicemanagement-unregister-completion-contract-sixteenth-final.log` (SHA-256 `9d8136cb1858fd58c0fa0dc0fd0d861444931720b34577e5843d72aa524606a1`) preserves the header hash and relevant contract: `.notRegistered` means never registered or later unregistered; successful asynchronous unregister completion follows termination of a running launch daemon and is the point after which re-registration is safe; an already-unregistered service returns `kSMErrorJobNotFound`. This SDK text informed the final postcondition but is not evidence that a live call occurred.
- E-236 — 2026-08-06T01:20:34+0200 — Established RED in three bounded steps. An exact HEAD export plus the new regression failed compilation because `HelperRemovalCompletionSafety` did not exist (`swift-test-helper-removal-completion-red.log`, SHA-256 `27646eb78a22fa1ba579e0781b607838f1b3f8fc92a3ccb8cb81d4bec2014ef3`). After adding only the pure gate, the old integration failed 6 issues because no final client postcondition or truthful failure copy existed (`swift-test-helper-removal-completion-integration-red.log`, SHA-256 `5a4b3f0a41c560778562af9ff4c4105b27246bf60b57ad31ea2e892599b84db6`). Independent staged review then found simulation could bypass the proof; the added regression against the pre-fix exact snapshot failed compilation on the absent eligibility policy (`swift-test-helper-removal-simulation-red.log`, SHA-256 `b92276468b0baa8485fa14523eba22e6457dc0012d89cbec77ba3e013c8ad0ae`).
- E-237 — 2026-08-06T01:20:34+0200 — Implemented only the shared final postcondition, ambiguous-outcome handling, authoritative simulation rejection, UI disable, and evidence-bounded copy. Both removal actions converge on the synchronous final gate; unregister failure and postcondition failure invalidate XPC and set `.unknown`; no refresh or await follows the final proof. The earlier working-tree GREEN passed 4 tests (`swift-test-helper-removal-completion-green.log`, SHA-256 `6aedba2fb991d5bd757f442fc13990e6d9c6039c056386dcdde2a7da87ccf51f`), before the independent simulation finding expanded the same root-cause checkpoint.
- E-238 — 2026-08-06T01:20:34+0200 — Independent adversarial review initially blocked the stage because `SimulatedHelper` could return success without ServiceManagement or registry evidence and because “Helper removed” overstated both the already-inactive path and the proven state. After the authoritative guard, UI disable, regression, and copy correction, read-only re-review found no remaining blocker in the narrow cached checkpoint. It retained sequential/non-atomic observation and source-structural integration coverage as explicit open limits.
- E-239 — 2026-08-06T01:20:34+0200 — The immutable pre-ledger Git-index tree is `962f2bb03c5cd425045591b03becd243643cff5b`; its six-path staged binary-diff SHA-256 is `53f7a34516e93a6bf905b307a6181b861ecf652e1b5d358d67d9b41c02ead69c`. Every selected index blob matched the independently assembled exact snapshot byte-for-byte, and both working and staged diff checks passed in `exact-index-and-diff-check-sixteenth-preledger.log` (SHA-256 `6a3212a0b2efdd7a29e2bf06a787c59259f0223588a7eb70f73979a13944b744`).
- E-240 — 2026-08-06T01:20:34+0200 — Final exact focused GREEN passed 5 tests in the completion suite (`swift-test-helper-removal-completion-exact-focused-final.log`, SHA-256 `99b1e47c2c0ac829b3d387fcff7cb431909863bf6d3903b5dcc54c30f44c9aab`), and the related registration/client suites passed 4 tests (`swift-test-helper-removal-related-exact-final.log`, SHA-256 `306754f937f3caa6a278b58aa8e3ca7f43f96dbf15cece9a8e8c6cbdda14d2be`). The exact snapshot passed all 244 tests in 20 suites (`swift-test-full-sixteenth-exact-final.log`, SHA-256 `5d53269d2370855e4d1ee0fdf827c4cde5816a98414b8636d84ad4693f359572`). The complete preserved dirty tree passed 255 tests in 22 suites (`swift-test-full-sixteenth-dirty-final3.log`, SHA-256 `6cf2b79861789e085260f6895ea052ee6b468c9d2ef615226227a0fff8722db7`); its additional broad-removal tests remain unaccepted as transaction, race, restart, or runtime proof.
- E-241 — 2026-08-06T01:20:34+0200 — Exact Debug and Release `LidlessCore` builds passed (`swift-build-core-debug-sixteenth-exact-final2.log`, SHA-256 `677efdce0c1ec0c1d5eb554febf5c3f175eba1e5fa0cfccf9fc58b0f476934d6`; Release SHA-256 `008ec473c733d63a15342d12b2215a134f1649ac6258459db98658da5f644e72`). All 25 App, 4 helper, and 1 widget sources passed macOS 15 Swift 6 complete strict-concurrency typechecking with warnings-as-errors (`swiftc-all-products-typecheck-sixteenth-exact-final.log`, SHA-256 `6b78a776f18f1f6dc1959942f1e8f474a9e0e343892e68105767bf7e23c9b620`). With `CODE_SIGNING_ALLOWED=NO`, SDKROOT pinned to 26.5, and linker ad-hoc signing disabled, every exact source set compiled and linked in Debug and optimized Release (`direct-all-products-debug-sixteenth-exact-final3.log`, SHA-256 `b55360f6129f50423ce04008274a72df21545035be21ea478a927dc780459cc1`; Release SHA-256 `4134d88e849fab8749c962fe0c3296a602569761f8fdd5d47020f00e41c39c3d`). No product was launched.
- E-242 — 2026-08-06T01:20:34+0200 — `artifact-inspection-sixteenth-exact-final3.log` (SHA-256 `ba40bf4a99dfae42447069f8e0d2ce9c3a5b5f27ba4715a3235aa35091a7de7f`) preserves hashes, modes, thin arm64 architecture, macOS 15 / SDK 26.5 build-version commands, absence of `LC_CODE_SIGNATURE`, and `codesign`'s unsigned result for all six loose products. `config-plist-entitlement-inspection-sixteenth-exact-final2.log` (SHA-256 `cb500a539cbddf1a628d5c7d4bf4ec92651a027dded8365c9f2e63c36eb972e9`) preserves lint and decoded values for all six source plist/entitlement files plus project bindings and central identifiers. These are not signed bundles or ServiceManagement/runtime evidence.
- E-243 — 2026-08-06T01:20:34+0200 — Discarded or superseded verifier-harness results without using them as safety evidence. Initial core builds selected Xcode-beta and hit its nested SwiftPM sandbox before compiling (`swift-build-core-debug-sixteenth-exact.log`, SHA-256 `7bb062c76d0aacddd20b96eab8f5b85c185a6f849736c62e8aac4b92cdc9d82b`; Release SHA-256 `3f818f0a979a553fbd9145c7994626953d726efe0a9358159c58a50f4ed63fed`); stable Xcode with the package sandbox disabled passed in E-241. The first complete dirty run found one stale untracked broad-remainder copy assertion (`swift-test-full-sixteenth-dirty-final.log`, SHA-256 `6b0667b045248419cc5f639b754d3360109585245b6638b9815f2f2e563aa695`); that redundant unstaged assertion was updated to the truthful selected copy and the complete rerun passed in E-240. A first artifact loop stopped on an `otool`/`awk` pipe-status harness defect before signature verdicts (`artifact-inspection-sixteenth-exact-final2.log`, SHA-256 `432b59323d55e8c288edaf77d989e30ef5936e52e4fd3e5354bcc7cbcbe7a312`); the corrected file-backed inspection passed in E-242. A first main-preservation harness referenced unavailable `/usr/bin/realpath` and stopped before a verdict (`main-preservation-sixteenth-precommit.log`, SHA-256 `f2106c0f19d5e9ad74375ebd0bfcbd958d527f4573aa560ca9022b0c8b49ffc4`). None launched a product or supplied an accepted safety result.
- E-244 — 2026-08-06T01:20:34+0200 — The design-craft skill informed only the removal copy's hierarchy, specificity, and state-dependent simulation explanation. Its visual-render step was not performed because the user expressly prohibited app launch and visual/SwiftUI redesign; no visual-quality claim is made. Project-native Xcode graph build/analyze was not retried after the established nested-sandbox and automatic LaunchServices side-effect constraints. No App/helper/widget process, helper install/activation/registration/approval/unregister, live XPC, `pmset`, sleep setting, sleep/wake, hardware, authentication, plugin/provider/connector, Figma, network publication, release, notarization, merge, push, or main-checkout mutation was performed.
- E-245 — 2026-08-06T01:20:34+0200 — Final pre-commit main-checkout preservation passed in `main-preservation-sixteenth-final-precommit.log` (SHA-256 `fc1b291c1d5659e182d148c56fde844cf643df726ccf6b2c261b0d2ce6eee882`): both canonical paths, two-worktree topology, shared Git common directory, main branch/HEAD, clean main index and tracked diff, all three `.playwright-mcp` path type/mode/size/raw SHA-256 values, NUL-status digest `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`, and empty tracked binary-diff digest all matched the authenticated rolling manifest exactly.
- E-246 — 2026-08-06T01:20:34+0200 — The checkpoint is prepared under subject `safety: verify helper deregistration completion`. Exactly the curated final HelperClient proof, pure completion/simulation policy, authoritative AppState simulation guard and bounded notification copy, SetupPane disable/copy, focused five-test regression, prior registration-test adaptation, and this append-only ledger are selected. Every broad daemon/removal, concurrency, wake, smoke/coordinator, orchestration, and design remainder stays unstaged. `State: IN_PROGRESS` is intentionally retained; after this single local commit the supervisor must authenticate the exact remaining tree in a fresh rolling manifest before another invocation.

## Seventeenth recovery audit — authenticated removal/support remainder

- E-247 — 2026-08-06T01:26:34+0200 — Read the canonical handoff, immutable starting-state manifest, authenticated rolling remainder manifest and adjacent sidecar, progress log, decision log, architecture, design-reset brief, and this complete append-only ledger. The canonical handoff SHA-256 `95bdacdde663c642c2f97d532c1ec2b931e94a7dfcda47b8031e011ab3944831` and immutable-manifest SHA-256 `d84065171a261e24ae574b98164132472ff1e8bb635647403d814b9fcf58c36a` matched their supplied values. The sidecar-recorded rolling-manifest SHA-256 `ef765a1acf4a6ffb2c1578d25ab1a1246b6294eaf59098b49f9c9ccb596c20ed` matched the manifest bytes. A repository-wide hidden-file scan found no `AGENTS.md`, `CLAUDE.md`, `CODEX.md`, `GEMINI.md`, `.cursorrules`, `copilot-instructions.md`, or matching instruction file.
- E-248 — 2026-08-06T01:26:34+0200 — Applied only the authenticated rolling manifest as recovery authority. The feature canonical path, exact two-worktree linked topology, branch, HEAD `6ba227b0a4342d8481dee21c82b701aae9d0c0d1`, Git admin/common directories, clean index, complete 12-path dirty inventory, every recorded status/type/mode/size/raw SHA-256, NUL-status digest `06c3356f8cc3d0113c414d764c544496ff8d2f7139a4db12b9ecb2f6e970b558`, and tracked binary-diff digest `6d0e8884c50ff6feca06682313cb09fea66eae31dd1d39cff5be0ba0230e94b4` matched exactly. Starting HEAD `7f17aaca11bc6228bed48b9265d63b9e576cdea7` remains an ancestor through the fourteen named checkpoint commits. Recovery passed before this append; the top-level `State: IN_PROGRESS` remains correct.
- E-249 — 2026-08-06T01:26:34+0200 — Independently reverified the rolling manifest's main-checkout record without editing it: canonical path and linked topology, `main` at `7f17aaca11bc6228bed48b9265d63b9e576cdea7`, clean index, complete three-path `.playwright-mcp` inventory, every recorded status/type/mode/size/raw SHA-256, NUL-status digest `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`, and empty tracked binary-diff digest `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` matched exactly. The main checkout remains untouched.

## Seventeenth-checkpoint ruling — serialize AppState-routed helper-removal admission

The preserved broad removal remainder is still not coherent enough to accept
as one checkpoint. Complete diff review and independent App, helper, and
package-scope audits retained the unchanged helper protocol version despite
changed daemon behavior; restart-volatile daemon removal state and an
enabled-to-enabled ABA window; unbounded XPC and therefore an unbounded app
removal latch; non-transactional scheduled-wake/persistence cleanup; a success
reply assembled before all cleanup; discarded optional low-power/TCP restore
errors; residual-cleanup gaps on the already-inactive path; a client
`removalCommitted` latch that is not reset after reported success and can make
a same-process reinstall appear `.notResponding`; duplicated/dead removal
policy; source-shape tests without actor races, cancellation, reply loss,
restart, or live faults; and stale orchestration claims. The helper client,
daemon, broad removal policy/tests, smoke tests, progress/decision documents,
and design-reset brief remain outside this checkpoint.

The selected invariant is narrower: one `AppState` must acquire a process-local
removal latch before its first suspension and only while no tracked helper
lifecycle or quit-recovery operation is active. Once held, the same state
rejects new arm confirmation, helper install/refresh, outside-override repair,
scheduled arm/wake maintenance, and termination entry; it invalidates local
wake reconciliation and queued arm intent, restores an active or arming
session, and requires selected arm/restore fields to be quiescent before
calling the removal client. Refresh now returns whether it acquired its
tracked lifecycle interval, so an arm verification cannot continue through a
removal that began while it was suspended.

This is process-local admission control only. It neither cancels nor counts an
already-dispatched wake, status, or heartbeat XPC call, constrains another
process, bounds XPC completion, proves helper cleanup/deregistration, makes
status and registry reads atomic, survives process restart, or closes any live
ServiceManagement, signed-XPC, sleep/wake, crash, hardware, notarization, or
release gate. The integration regressions inspect exact source ordering; they
do not execute an AppState actor race or a live helper fault.

### Seventeenth-checkpoint finding and verification matrix

| ID | Invariant | Exact checkpoint evidence | Remaining boundary | Ruling |
| --- | --- | --- | --- | --- |
| S-40 | Removal and tracked AppState helper lifecycle/quit entry cannot newly overlap | A pure fail-closed policy requires non-simulation, no removal, no termination, and an exactly zero lifecycle count; the latch is set before the first suspension, and helper install/refresh plus arm verification reject or abort while it is held | Already-dispatched untracked XPC, another process, process restart, and unbounded suspension are outside the latch | CHECKPOINT VERIFIED OFFLINE — CROSS-PROCESS/TIMEOUT GATES OPEN |
| S-41 | AppState cannot dispatch removal until selected local arm/restore state is quiescent | The latch invalidates queued wake reconciliation and arm intent, disarms `.armed` or `.arming`, then a pure gate requires `.disarmed`, no session/arm/restore/sleep termination, and exactly zero arm requests; new arm, repair, wake maintenance, and termination entry are fenced | Local wake invalidation only discards stale replies; heartbeat/status/wake calls already dispatched are not counted; no actor-race or cancellation execution exists | CHECKPOINT VERIFIED OFFLINE — IN-FLIGHT/RUNTIME GATES OPEN |
| V-24 | Exact selected code passes RED/GREEN, focused, complete, strict compile, and unsigned Debug/Release checks | Pre-ledger tree `e0712abe4858f3919e50c560dfc5de59d3104aee` reproduced a 7-issue RED, then passed 4 admission tests, 11 related restore tests, all 248 exact tests, Debug/Release core builds, Swift 6 complete-concurrency typechecking with warnings-as-errors, and direct Debug/Release App/helper/widget links | Project-native Xcode graph build/analyze was not retried under the established nested-sandbox and automatic LaunchServices side-effect constraints | PASS FOR EXACT OFFLINE CODE — XCODE GRAPH OPEN |
| V-25 | Actual loose products and source configuration remain bounded evidence | All six direct outputs are thin unsigned arm64 Mach-O executables targeting macOS 15 / SDK 26.5; the Debug app contains the selected policy symbols; six exact source plist/entitlement files linted and decoded, and project bindings/identifiers were inspected | These are not bundles and prove no bound entitlement, signing identity, XPC trust, registration behavior, runtime behavior, notarization, or release readiness | PARTIAL — BUNDLE/SIGNING/RUNTIME GATES OPEN |

- E-250 — 2026-08-06T01:38:03+0200 — Reproduced the complete authenticated dirty-package baseline before accepting a remainder claim. Stable Xcode 26.5 Swift 6.3.2 passed 255 tests in 22 suites in `swift-test-seventeenth-dirty-baseline.log` (SHA-256 `4d2774c3dcba75411fed68e103b021ade996c2682e58815c5df21da7cdbd019e`). This broad-tree pass is baseline evidence only and does not cure the protocol, transaction, restart/ABA, timeout, cleanup, client-liveness, or evidence-scope defects recorded above. Complete review plus three independent read-only audits selected only the AppState admission root-cause group; no reviewer edited a file.
- E-251 — 2026-08-06T01:38:03+0200 — Established an independently assembled RED from exact HEAD plus only the new pure policy and regression file. Both pure truth tables passed, while the two AppState wiring tests failed with seven issues because the lifecycle-return contract and admission fences were absent (`swift-test-app-removal-red.log`, SHA-256 `331995752fb74baec49f9450aba0a34058a0855140045a628bfbeaa4c3753f32`). The first working-tree GREEN then passed all 4 selected tests (`swift-test-app-removal-green.log`, SHA-256 `e5364fb429cfb732ba6510b3ae94103249d5605f089c3044001504467484030a`).
- E-252 — 2026-08-06T01:38:03+0200 — Implemented only the process-local admission interval described above. `HelperRemovalAppSafety` deliberately names the evidence limit; `AppState` acquires the latch before suspension, tracks its lifecycle interval, aborts a refresh-dependent arm safely, fences selected new work, invalidates local wake reconciliation/queued intent, restores before removal, and applies the quiescence truth table. The related non-sleep source assertion now checks the shared pending-restore gate. No helper client, daemon, protocol, release, design, or orchestration remainder was staged.
- E-253 — 2026-08-06T01:38:03+0200 — Independent adversarial re-review found no blocker in the exact four-file code/test stage after the regression was strengthened to assert the refresh guard before tracked arm dispatch, deterministic arm-abort copy, `.arming` disarm, wake invalidation ordering, latch cleanup, and every policy argument. Review retained uncounted already-dispatched wake/status/heartbeat calls, unbounded XPC, process-local scope, no actor-race/fault execution, and incomplete helper-removal semantics as explicit open limits.
- E-254 — 2026-08-06T01:38:03+0200 — The immutable pre-ledger Git-index tree is `e0712abe4858f3919e50c560dfc5de59d3104aee`; its four-path staged binary-diff SHA-256 is `692a2945e793aacb89bb9dc8869bb7277fdc3b373a1b4cc7ac5c252c4b0cffdc`. Every selected index blob was exported into the exact snapshot used below, and `git diff --cached --check` passed. `exact-index-and-diff-check-seventeenth-preledger.log` preserves the path list, 346-insertion/19-deletion stat, tree, digest, and verdict (SHA-256 `d2286cf3c5402c8785ff0956acccec067bdc1e72bc419943509c1202ccc9c5a4`).
- E-255 — 2026-08-06T01:38:03+0200 — Final exact focused GREEN passed all 4 App-local admission tests (`swift-test-app-removal-exact-final-focused.log`, SHA-256 `05ca4e4bf2072d9cfb4d4e74c3cf6845d1370640c3e9da2afabdad73b822694f`) and all 11 non-sleep restore coordinator tests (`swift-test-nonsleep-exact-final-focused.log`, SHA-256 `8bb5c8c193bc5f7fdc875c005e6afbe34fe9edfd6ff0e8d4e2e863dec1171185`). The same exact snapshot passed all 248 tests in 21 suites (`swift-test-app-removal-exact-final-full.log`, SHA-256 `ab49862e7d534e723ac690cac14ef0056a4a327222c0e00685e0771f06a5f14a`). Complete outputs are preserved; no test launched an App, helper, or widget product.
- E-256 — 2026-08-06T01:38:03+0200 — Exact Debug and Release `LidlessCore` builds passed (`swift-build-core-debug-app-removal-exact-final.log`, SHA-256 `2466592ea99778fc071cc8716f3ed6ea67794c2349960788f4b89d44d50ee3dc`; Release SHA-256 `365af9b4ea7e269edac194e9082d9fbe15e1e15fb0ecbef71905200d39bc57a7`). All 25 App, 4 helper, and 1 widget sources passed macOS 15 Swift 6 complete strict-concurrency typechecking with warnings-as-errors and the compiler plugin sandbox disabled (`swiftc-strict-typecheck-app-removal-exact-final-nosandbox.log`, SHA-256 `a2c5bcff8f2620717aa4da556604a33bdf43f5b4cc16749321ba8078e4b06b80`). With `CODE_SIGNING_ALLOWED=NO`, stable SDK 26.5, and linker ad-hoc signing disabled, all three exact source sets compiled and linked in Debug (`swiftc-link-debug-app-removal-exact-final.log`, SHA-256 `2a38ae062604a363f5defd2b2111752b206be6c8ac78498dd71d338d49584346`) and optimized Release (`swiftc-link-release-app-removal-exact-final.log`, SHA-256 `138375fa2f19139458468eab72d246d4690b7cae9f81fa55c4d782e15d3143a9`). No product was launched.
- E-257 — 2026-08-06T01:38:03+0200 — `artifact-config-inspection-app-removal-exact-final.log` (SHA-256 `d630af9e2b1614ce2f82707cdce676e7440baa744f551bed25dc9f65a56244ca`) preserves file type, thin arm64 architecture, macOS 15 / SDK 26.5 build version, raw SHA-256, and `codesign`'s unsigned verdict for all six loose Debug/Release outputs; the Debug app exports the selected pure-policy symbols. The same log preserves lint and decoded values for the exact App/helper/widget plist and entitlement sources plus project identity/configuration bindings. These are unbundled compile artifacts, not signed runtime or release evidence.
- E-258 — 2026-08-06T01:38:03+0200 — The first strict direct App typecheck was discarded as an environment failure: Swift's Observation macro plugin attempted `sandbox-exec`, which the enclosing host sandbox denied, yielding a malformed plugin-server response rather than a source diagnostic (`swiftc-strict-typecheck-app-removal-exact-final.log`, SHA-256 `68a57197da126d42ae07b2d6fc489128b6d810f49d4de360f6993f6c0e71df21`). The identical exact sources passed after the compiler plugin sandbox alone was disabled in E-256. Project-native Xcode build/analyze was not retried because its nested-sandbox failure and automatic LaunchServices registration side effect were already established.
- E-259 — 2026-08-06T01:38:03+0200 — Final pre-commit main-checkout preservation passed in `main-preservation-seventeenth-final-precommit.log` (SHA-256 `01577b57e994f92c2cf9a921fe1231ec75352c9f6ca06348cfc3d7424fb3b42c`): both canonical paths, exact two-worktree topology, common Git directory, main `main` branch/starting HEAD, clean index and tracked diff, complete three-path `.playwright-mcp` inventory, every type/mode/size/raw SHA-256, NUL-status digest `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`, and empty tracked binary-diff digest matched the authenticated rolling manifest exactly. No App/helper/widget process, helper install/activation/registration/approval/removal, live XPC, `pmset`, sleep-setting, sleep/wake, hardware, authentication, plugin/provider/connector, Figma, network publication, release, notarization, merge, push, or main-checkout mutation was performed.
- E-260 — 2026-08-06T01:38:03+0200 — The checkpoint is prepared under subject `safety: serialize helper removal admission`. Exactly the four-file AppState admission code/test stage and this append-only ledger are selected; every broader helper client/daemon/removal, smoke, orchestration, and design remainder stays unstaged. `State: IN_PROGRESS` is intentionally retained. After this single local commit, the supervisor must authenticate the exact remaining tree in a fresh rolling manifest before another invocation.
- E-261 — 2026-08-06T01:39:55+0200 — Reviewed the complete five-path staged diff. `final-staged-review-seventeenth.log` (SHA-256 `7f3f01335e2e21080345d37fdadc2d3e35aa74b637e5e2edf2390bae1f21f074`) confirmed the exact curated stage, verified every selected code/test index blob byte-for-byte against the independently tested snapshot, preserved the four-file code-diff digest `692a2945e793aacb89bb9dc8869bb7277fdc3b373a1b4cc7ac5c252c4b0cffdc`, confirmed `State: IN_PROGRESS`, and passed both complete working tracked-diff and staged-diff whitespace checks. Its pre-final-evidence index tree was `a5ee7708a4b7490da179a765d1f7c0bb915fb987`; only this final evidence entry is appended afterward.

## Eighteenth recovery audit — authenticated helper-removal remainder

- E-262 — 2026-08-06T01:46:12+0200 — Read the canonical handoff, immutable starting-state manifest, authenticated rolling remainder manifest and adjacent sidecar, progress log, decision log, architecture, design-reset brief, and this complete append-only ledger. The canonical handoff SHA-256 `95bdacdde663c642c2f97d532c1ec2b931e94a7dfcda47b8031e011ab3944831` and immutable-manifest SHA-256 `d84065171a261e24ae574b98164132472ff1e8bb635647403d814b9fcf58c36a` matched their supplied values. The sidecar-recorded rolling-manifest SHA-256 `3193b3582428929959ea77fb374a9bd47341e6376c0a5d9259236981a9c5f6ca` matched the manifest bytes. A repository-wide hidden-file scan found no `AGENTS.md`, `CLAUDE.md`, `CODEX.md`, `GEMINI.md`, `.cursorrules`, `copilot-instructions.md`, or matching instruction file.
- E-263 — 2026-08-06T01:46:12+0200 — Applied only the authenticated rolling manifest as recovery authority. The feature canonical path, exact two-worktree linked topology, branch, HEAD `f60a8dfc61a509fd6ac2b570d0323508dddcba7c`, Git admin/common directories, clean index, complete eight-path dirty inventory, every recorded status/type/mode/size/raw SHA-256, NUL-status digest `1586f4f4d11e6fce98cb0fd26d30a6bd725cd57f5b21bffed6e8d5e6fce77af3`, and tracked binary-diff digest `9553209f1034cfe2df16d71ddab88833baf98b32b4ae9a7b461af5befcdc9ffa` matched exactly. Starting HEAD `7f17aaca11bc6228bed48b9265d63b9e576cdea7` remains the recorded baseline. Recovery passed before this append; the top-level `State: IN_PROGRESS` remains correct.
- E-264 — 2026-08-06T01:46:12+0200 — Independently reverified the rolling manifest's main-checkout record without editing it: canonical path and linked topology, `main` at `7f17aaca11bc6228bed48b9265d63b9e576cdea7`, clean index, complete three-path `.playwright-mcp` inventory, every recorded status/type/mode/size/raw SHA-256, NUL-status digest `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`, and empty tracked binary-diff digest `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` matched exactly. The main checkout remains untouched.
- E-265 — 2026-08-06T01:46:12+0200 — The first post-gate ledger patch incorrectly treated this clean tracked file as absent and temporarily replaced its working copy. The deletion-heavy diff was detected before package review, staging, commit, or any product-source edit. A first bounded restoration attempt used truncated Git-object output and did not match; it was immediately superseded. The exact 1,124-line, 240,506-byte `f60a8df` ledger was then reconstructed from bounded read-only Git-object slices through `apply_patch` and verified byte-for-byte at SHA-256 `9c314966ab33ae501be9dc60763e608893659730f34dc471608f83cda08a185a` before this append. No prior evidence entry was discarded or rewritten, and no product source, index, main-checkout file, app/helper process, registration, or system setting was affected.

## Eighteenth-checkpoint ruling — fence ambiguous client cleanup outcomes

The authenticated broad helper-removal remainder is not coherent enough for a
single checkpoint. Complete diff review and three independent read-only audits
confirmed an unchanged protocol version despite changed daemon semantics; a
success reply carrying status captured before wake cleanup; non-transactional
wake-ledger, file-sink, work-directory, low-power-mode, and TCP restoration;
process-lifetime-only daemon removal state; restart and enabled-to-enabled ABA
exposure; no safe already-registered helper replacement path; already-inactive
residual-cleanup gaps; unbounded XPC and ServiceManagement waits; stale XPC
connection callbacks; source-shape-heavy broad tests; and a pre-existing signal
path that can exit while restoration remains pending. The daemon, broad removal
policy/tests, protocol/version, smoke tests, orchestration documents, and design
brief remain outside this checkpoint.

The selected invariant is narrower. Once this app process dispatches cleanup
to an enabled helper, it records an unresolved outcome before the XPC await. A
lost transport reply or malformed payload therefore cannot leave that client
eligible to reinstall, arm, extend the watchdog, request forced sleep, or
schedule a new wake. Observation, normal-sleep restoration, wake cancellation,
and cleanup retry remain available. Only an explicit inactive registration plus
a fresh independent `SleepDisabled == false` observation reopens the fence;
the same proof clears it before `.notInstalled`, so a proven same-process
cleanup does not poison a later reinstall. Ambiguous registration categories
remain `.unknown` instead of being presented as “installed but not responding.”

This is process-local, pre-dispatch admission only. It cannot revoke an XPC call
already past its guard, constrain another process, persist across app restart,
make ServiceManagement and registry observations atomic, prevent cross-process
ABA, bound any await, repair stale connection-handler ordering, cancel cleanup
already dispatched, prove daemon cleanup, or establish safe helper replacement.
No signed XPC, live ServiceManagement, sleep/wake, crash-restart, hardware,
notarization, or release conclusion follows from this checkpoint.

### Eighteenth-checkpoint finding and verification matrix

| ID | Invariant | Exact checkpoint evidence | Remaining boundary | Ruling |
| --- | --- | --- | --- | --- |
| S-42 | Ambiguous enabled-helper cleanup cannot leave this client process open to new risk-increasing work | The fence is set before `callForReply`; transport/decode failures do not clear it; install, arm, heartbeat, force-sleep disarm, and new wake scheduling consult the operation policy | Calls already dispatched, another process, restart, ABA, timeout, and daemon delivery remain outside the fence | CHECKPOINT VERIFIED OFFLINE — IN-FLIGHT/PROCESS/RUNTIME GATES OPEN |
| S-43 | Recovery-reducing work remains available while the outcome is unresolved | The pure operation table permits observation, ordinary disarm/repair, wake cancellation, and cleanup retry; production wiring classifies force sleep and new wake separately from restore and cancellation | No live fault injection or executable `HelperClient`/ServiceManagement test exists | CHECKPOINT VERIFIED OFFLINE — LIVE/FAULT GATES OPEN |
| S-44 | The client reopens only on the existing two-source completion proof and does not invent a registration presentation | The reducer accepts only inactive registration plus fresh registry OFF; refresh resolves only from `.notRegistered`; final proof precedes resolution and `.notInstalled`; unresolved categories use `.unknown` | Observations are non-atomic and the fence is not restart-durable | CHECKPOINT VERIFIED OFFLINE — ATOMICITY/PERSISTENCE GATES OPEN |
| V-26 | Exact selected code passes RED/GREEN, focused, complete, strict compile, and unsigned Debug/Release checks | Pre-ledger tree `2eb6804f25be8e60694b9bd10a3459a4c187fc32` reproduced missing-policy REDs, passed 4 focused tests and all 252 exact tests, Debug/Release core builds, Swift 6 complete-concurrency typechecking with warnings-as-errors, and direct Debug/Release App/helper/widget links | Project-native Xcode build/analyze was not retried under the established nested-sandbox and automatic LaunchServices side-effect constraints | PASS FOR EXACT OFFLINE CODE — XCODE GRAPH OPEN |
| V-27 | Loose products and source configuration remain bounded evidence | Six direct outputs are thin unsigned arm64 Mach-O executables targeting macOS 15 / SDK 26.5 with no `LC_CODE_SIGNATURE`; source plists/entitlements linted and decoded, project bindings were inspected, and the Debug app contains the selected policy symbols | These are not bundles and prove no bound entitlement, identity, XPC trust, registration behavior, runtime behavior, notarization, or release readiness | PARTIAL — BUNDLE/SIGNING/RUNTIME GATES OPEN |

- E-266 — 2026-08-06T02:03:33+0200 — Reproduced the complete authenticated dirty-package baseline before accepting a remainder claim. Stable Xcode 26.5 Swift passed 255 tests in 22 suites in `swift-test-eighteenth-dirty-baseline.log` (SHA-256 `5f406526cfb8e7d0925da0750b6328dbd93df163e514c67f6441241d107b55ad`). Complete source and diff review plus three independent read-only audits rejected the broad daemon/removal remainder for the concrete defects and evidence limits listed above. No reviewer edited a file.
- E-267 — 2026-08-06T02:03:33+0200 — Confirmed the separable client defect: the preserved `removalCommitted` Boolean was set only after a decodable restore-proven reply, so a daemon could commit cleanup and lose or corrupt the reply while the client remained eligible for new work; after proven removal, the Boolean was never cleared, so same-process reinstall could remain permanently reported as unresponsive. The initial focused RED failed because `HelperRemovalClientSafety` did not exist (`swift-test-helper-removal-client-fence-red.log`, SHA-256 `f6dd92e7a0279b40f71d5d5fac45a97d8746132488b14cc9c5779d372b00fdbc`).
- E-268 — 2026-08-06T02:03:33+0200 — Implemented the process-local outcome fence and then tightened it after adversarial review identified an ungated watchdog heartbeat, force-sleep disarm, recovery-blocking repair/wake cancellation, and false `.notResponding` presentation. A second RED lacked the operation-aware policy (`swift-test-helper-removal-client-policy-red.log`, SHA-256 `f7b33adb07a08d523027cf1766b1ac2bcaa3618ac0741f3e1895a174711d3894`). The first operation-policy GREEN attempt exposed and preserved a missing Swift `return` (`swift-test-helper-removal-client-policy-green.log`, SHA-256 `ed6533d797dc8ab34f0b5cdcd869004d6980ebb536c94016b10d19c7f05f918b`) and is not counted. Corrected GREEN passed 4 tests, and final hardened focused GREEN passed the same 4 tests in `swift-test-helper-removal-client-policy-final.log` (SHA-256 `6f640103f7c0fe422ff1cb7ea99227024e8cdc268b5c609ac60bb2ca3ee5a908`).
- E-269 — 2026-08-06T02:03:33+0200 — The first complete working-tree rerun exposed three stale source-shape expectations after the new client guard and was not counted (`swift-test-eighteenth-client-fence-full-dirty.log`, SHA-256 `229ce1f797bb67c5592d561292f34a75261dd342ee88cffd12dce8f48c53fbe9`). The existing scheduled-wake assertion was narrowed to the exact function signature; the unstaged broad removal test was adapted to the selected fence name without selecting its broad content. After final policy and wording hardening, the complete dirty tree passed 259 tests in 23 suites in `swift-test-full-eighteenth-client-fence-dirty-final.log` (SHA-256 `7d0534fa7847c20e2ddcd9539ba69afb1d420a3548118e7c8921d6d70a1f3bea`). This broad-tree pass does not cure the rejected remainder.
- E-270 — 2026-08-06T02:03:33+0200 — The immutable pre-ledger Git-index tree is `2eb6804f25be8e60694b9bd10a3459a4c187fc32`; its four-path staged binary-diff SHA-256 is `61858a566d6218f13902cc0466b385bf6d9a74fdc474f1af3d6641d0beeebb59`. Every selected index blob matched its independently exported exact snapshot, and `git diff --cached --check` passed. `exact-index-and-diff-check-eighteenth-preledger.log` preserves the path list, 306-insertion/9-deletion stat, blobs, tree, digest, and verdict (SHA-256 `fb17391dea37cda9335cc0190c847c8f59806ee255cb16dd3d562e012e5ee189`). The first comparison harness shadowed zsh's special `path` array after the archive was created, losing `git` lookup before comparison; the corrected same-tree comparison used a non-special variable and passed without altering source or index.
- E-271 — 2026-08-06T02:03:33+0200 — The exact snapshot passed all 4 client-fence tests in `swift-test-helper-removal-client-fence-eighteenth-exact.log` (SHA-256 `84e0117c0d28d747dcf14237457ddec1c23aaf6b9a1d490e3bd1ecc8ca85fdfc`) and all 252 exact tests in 22 suites in `swift-test-full-eighteenth-client-fence-exact.log` (SHA-256 `08be0bcf482c1b568bb5622d4716ca9b7533d9098d6a4eef5c90dec5f858cbd4`). Complete output is preserved; no App, helper, or widget product was launched.
- E-272 — 2026-08-06T02:03:33+0200 — Exact Debug and Release `LidlessCore` builds passed (`swift-build-core-debug-eighteenth-client-fence-exact.log`, SHA-256 `eb3752a7055aa3cc1b27436ecd7475cbb1315e83d088357dc1850b4ba478c19b`; Release SHA-256 `34227a7c6258e36d336bdf358fae70c10ebb3ae51c043abc76b23fea58962c9d`). All 25 App, 4 helper, and 1 widget sources passed macOS 15 Swift 6 complete strict-concurrency typechecking with warnings-as-errors and the compiler plugin sandbox disabled (`swiftc-strict-typecheck-eighteenth-client-fence-exact.log`, SHA-256 `2c26e6cef6cd16f8f3d1f3ab6bbc19f6f2b3f4a4d082bc516acd0f1bd991c700`). With `CODE_SIGNING_ALLOWED=NO`, stable SDK 26.5, and linker ad-hoc signing disabled, all three source sets compiled and linked in Debug (`swiftc-link-debug-eighteenth-client-fence-exact.log`, SHA-256 `445b282ca88705c7c5100203cd720f26f42810a5073714a671ffcd77058469e8`) and optimized Release (`swiftc-link-release-eighteenth-client-fence-exact.log`, SHA-256 `3ad7ea023280820168e90ca32e9f7e7783a581c2d53c7a6c83760376c7ca9b93`).
- E-273 — 2026-08-06T02:03:33+0200 — `artifact-config-inspection-eighteenth-client-fence-exact.log` (SHA-256 `344580f257340ea44149f05b1104e49d9bbb6fdb715b0d0f1a331b05cd801d2a`) preserves raw hashes, modes, sizes, thin arm64 architecture, macOS 15 / SDK 26.5 build versions, linkage, absence of `LC_CODE_SIGNATURE`, and `codesign`'s unsigned verdict for all six loose Debug/Release products; the Debug app exports the selected policy symbols. The same log preserves lint and decoded values for all six exact source plist/entitlement files plus central IDs and project bindings. These are unbundled compile artifacts, not signed-runtime or release evidence.
- E-274 — 2026-08-06T02:03:33+0200 — Post-build main-checkout preservation passed in `main-preservation-eighteenth-final-precommit.log` (SHA-256 `ae7bbe9de8342727222f22b329e7e2c6727ab4ad17d3cbb595be93ba7c8b6569`): canonical path, exact two-worktree topology, main `main` branch/starting HEAD, clean index and tracked worktree, complete three-path `.playwright-mcp` inventory, every type/mode/size/raw SHA-256, NUL-status digest `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`, and empty tracked binary-diff digest matched the authenticated rolling manifest exactly.
- E-275 — 2026-08-06T02:03:33+0200 — No App/helper/widget process, helper install/activation/registration/approval/unregister, live XPC, `pmset`, sleep setting, sleep/wake, hardware, authentication, plugin/provider/connector, Figma, network publication, release, notarization, merge, push, or main-checkout mutation was performed. Project-native Xcode build/analyze was not retried after the established nested-sandbox failure and automatic LaunchServices side effect. All accepted evidence is offline, explicitly unsigned, and non-runtime.
- E-276 — 2026-08-06T02:03:33+0200 — The checkpoint is prepared under subject `safety: fence ambiguous helper cleanup outcomes`. Exactly the client fence policy/wiring, focused regression, scheduled-wake source-anchor adaptation, and this append-only ledger are selected. Every daemon, broad removal policy/test, protocol/version, smoke, orchestration, and design remainder stays unstaged. `State: IN_PROGRESS` is intentionally retained; after this single local commit, the supervisor must authenticate the exact remaining tree in a fresh rolling manifest before another invocation.
- E-277 — 2026-08-06T02:05:30+0200 — Reviewed the complete five-path staged diff. `final-staged-review-eighteenth.log` (SHA-256 `bc28a63b1c9e853095afb9784371c05c6426e1bd362171288c01c58daf9259b6`) confirmed the exact curated stage, verified every selected code/test index blob byte-for-byte against the independently tested snapshot, preserved the four-file code-diff digest `61858a566d6218f13902cc0466b385bf6d9a74fdc474f1af3d6641d0beeebb59`, confirmed `State: IN_PROGRESS`, and passed complete working-tree and staged-diff whitespace checks. Its pre-final-evidence index tree was `669e19cb866cb8d7717ceed6190753324cdd279b`; only this final evidence entry is appended afterward.

## Nineteenth recovery audit — authenticated daemon cleanup remainder

- E-278 — 2026-08-06T02:11:29+0200 — Read the canonical handoff,
  immutable starting-state manifest, authenticated rolling remainder manifest
  and adjacent sidecar, progress log, decision log, architecture, and
  design-reset brief in full. The canonical handoff SHA-256
  `95bdacdde663c642c2f97d532c1ec2b931e94a7dfcda47b8031e011ab3944831`
  and immutable-manifest SHA-256
  `d84065171a261e24ae574b98164132472ff1e8bb635647403d814b9fcf58c36a`
  matched their supplied values. The sidecar-recorded rolling-manifest SHA-256
  `3837fa6f8b7cb4ebd71f6afb5efd9fb2dae3f002a076dfac7b0c99c7dc61be4e`
  matched the manifest bytes. A repository-wide hidden-file scan found no
  `AGENTS.md`, `CLAUDE.md`, `CODEX.md`, `GEMINI.md`, `.cursorrules`,
  `copilot-instructions.md`, or matching instruction file.
- E-279 — 2026-08-06T02:11:29+0200 — Applied only the authenticated rolling
  manifest as recovery authority. The feature canonical path, exact
  two-worktree linked topology, branch, HEAD
  `1fbcb9e1ac55e7ebbfde8757eacef35e87847f6e`, Git admin/common directories,
  clean index, complete seven-path dirty inventory, every recorded
  status/type/mode/size/raw SHA-256, NUL-status digest
  `b776d916f5d2a7b21364484ee4ede9d5194dcc1be1fcb313fd526bc803890183`,
  and tracked binary-diff digest
  `982d7e3380b85a7cdaceff7d733307cb6862c06d6dd661ffa62c3d372c853bd4`
  matched exactly before editing. One preliminary presentation of the mode
  field incorrectly converted `stat`'s octal digit string as decimal and
  printed `01204`; direct string-preserving reproduction immediately proved
  every actual mode was the required `0644`. This was an audit-harness
  formatting error, not a filesystem mismatch, and changed no file.
- E-280 — 2026-08-06T02:11:29+0200 — Independently reverified the rolling
  manifest's main-checkout record without editing it: canonical path and
  linked topology, `main` at
  `7f17aaca11bc6228bed48b9265d63b9e576cdea7`, clean index, complete
  three-path `.playwright-mcp` inventory, every recorded
  status/type/mode/size/raw SHA-256, NUL-status digest
  `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`,
  and empty tracked binary-diff digest
  `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`
  matched exactly. The main checkout remains untouched.
- E-281 — 2026-08-06T02:11:29+0200 — The first post-gate ledger patch
  incorrectly treated this clean tracked file as absent and temporarily
  replaced its working copy. The deletion-heavy diff was detected before any
  product-source edit, test, build, staging, commit, or live action. The exact
  1,188-line, 256,764-byte `1fbcb9e` ledger was reconstructed from bounded
  read-only Git-object slices through `apply_patch` and verified byte-for-byte
  at SHA-256
  `e3736d3b9337c9877116b75e749f01d8b12430963646aaa60084c9ab625c875b`
  before this append. No prior evidence entry was discarded or rewritten, and
  no product source, index, main-checkout file, app/helper process,
  registration, or system setting was affected.

## Nineteenth-checkpoint ruling — retain helper-owned recovery through termination

The authenticated seven-path remainder is not coherent enough to accept as a
single package. Complete diff review and three independent read-only audits
confirmed stale uninstall status, non-transactional scheduled-wake persistence
and cancellation, permanently disabled file logging after failed cleanup,
process-lifetime-only uninstall fencing, duplicate/dead removal policy,
source-shape-heavy broad tests, stale orchestration claims, and unrelated
design/Figma material. None of those daemon-uninstall, broad removal-policy,
smoke, orchestration, or design bytes is selected.

The selected defect is narrower. The prior SIGTERM/SIGINT handler made one
restore attempt and then called `exit(0)` unconditionally, even when exact
normal-sleep readback failed or sentinel deletion left recovery pending. The
selected implementation establishes both managed signal dispositions and
sources before synchronous launch recovery, validates XPC peer identity only
after recovery is live and still before listener exposure, latches termination
on the serial state queue, invalidates delayed lifecycle work, and attempts an
owned restore. A voluntary exit is permitted only when both the sentinel and
pending-restore record are absent. Restore failures retain recovery state and
become eligible at the next five-second supervision tick. New arm, repair,
wake, and delayed force-sleep work are refused after the latch, while ordinary
disarm/restoration and observation remain available.

This is an offline source checkpoint, not runtime signal proof. A queued signal
waits behind work already executing on the serial queue; process startup before
handler installation and the small disposition-to-source construction interval
remain unproved; the OS can forcibly terminate the daemon; and no test executes
a real signal, launchd escalation, timer, XPC call, `pmset`, sleep/wake, or
shutdown. The protocol value deliberately remains v6 because the XPC schema and
app-visible proof semantics did not change. Equality with v6 does not attest
that an installed helper contains these bytes. The current app has no safe
already-registered executable-replacement transaction, so this checkpoint is
not deployable, independently review-ready, or release-ready until replacement
and build-freshness evidence are implemented and tested.

### Nineteenth-checkpoint finding and verification matrix

| ID | Invariant | Exact checkpoint evidence | Remaining boundary | Ruling |
| --- | --- | --- | --- | --- |
| S-45 | A failed signal-triggered restore cannot authorize voluntary helper exit | The pure exit truth table requires a latched request plus no sentinel and no pending restore; all five restore-failure sites retain recovery and use the termination-aware retry scheduler; the handler and tick share the final exit gate | Tests do not deliver a signal, fault `pmset`, delete a real sentinel, run the timer, or control OS termination | CHECKPOINT VERIFIED OFFLINE — SIGNAL/FAULT/LIVE GATES OPEN |
| S-46 | Once termination is observed, new risk-increasing helper work cannot extend the recovery interval | Pure operation policy rejects arm, repair, all wake work, and delayed force sleep; exact source wiring guards each operation, advances lifecycle in the handler, and leaves ordinary disarm wired to `performRestore` | Already-running serial work precedes the handler; no live concurrent XPC/signal execution or forced-kill behavior was exercised | CHECKPOINT VERIFIED OFFLINE — QUEUE/RUNTIME GATES OPEN |
| S-47 | Launch recovery and peer validation cannot be deferred until after XPC listener exposure | Exact startup source ordering is synchronous: both signal dispositions/sources, recovery, remaining setup, peer validation, listener construction, then resume | Pre-handler process lifetime and disposition/source capture windows remain; source ordering is not launchd execution evidence | CHECKPOINT VERIFIED OFFLINE — STARTUP/LIVE GATES OPEN |
| V-28 | Exact selected bytes pass focused, complete, strict compile, and unsigned Debug/Release checks | Pre-ledger tree `b470694bbf67ddf27b6833996f932b84bd6626d7` passed 6 focused tests, all 258 exact tests, Debug/Release core builds, Swift 6 complete-concurrency typechecking with warnings-as-errors, and direct Debug/Release App/helper/widget links | Project-native Xcode graph build/analyze was not retried under the established nested-sandbox and automatic LaunchServices side-effect constraints | PASS FOR EXACT OFFLINE CODE — XCODE GRAPH OPEN |
| V-29 | Artifact/configuration evidence is bounded to observed loose products and source files | Six thin arm64 macOS 15 / SDK 27.0 outputs have no `LC_CODE_SIGNATURE` and fail code-sign inspection as unsigned; the Debug helper contains the selected policy symbols; six plist/entitlement sources linted and decoded, and project bindings were inspected | Outputs are not bundles and prove no bound entitlement, identity, installed executable, XPC trust, registration, notarization, or runtime behavior | PARTIAL — BUNDLE/SIGNING/RUNTIME GATES OPEN |
| V-30 | Helper compatibility equality is not represented as executable-freshness proof | `helperVersion` stays 6 and its comment explicitly rejects freshness inference; local SDK and exact client-source inspection prove changed daemon bytes require a separate safe replacement lifecycle | `install()` calls register on stale/already-registered states; no unregister/re-register transaction or installed-build identity exists | DEFERRED — REPLACEMENT/FRESHNESS GATE BLOCKS DEPLOYMENT |

- E-282 — 2026-08-06T02:35:19+0200 — Reproduced the complete authenticated dirty-package baseline before accepting any remainder claim. Xcode-beta 27.0 Swift 6.4 passed 259 tests in 23 suites in `swift-test-nineteenth-dirty-baseline-corrected.log` (SHA-256 `b593f9f4844c2c45a9e341144808acac3a2d573d48b9b052cd8a631cb8bb0de5`). The first attempt lacked writable module-cache routing and failed before manifest evaluation (`swift-test-nineteenth-dirty-baseline.log`, SHA-256 `2db66ecf938c89661c95e9952656f35cc9c3bf9fca8039b94a08df50067a5ec7`); it is environment evidence only. Complete diff review and three independent read-only audits rejected the broad remainder for the uninstall transaction, persistence, logging, protocol/replacement, timeout, stale-callback, optional-restoration, test-scope, documentation, and design defects described above.
- E-283 — 2026-08-06T02:35:19+0200 — Established RED incrementally against the unsafe handler. The initial structural regression recorded four failures because the old handler neither latched termination nor gated exit/retry (`swift-test-helper-termination-nineteenth-red.log`, SHA-256 `fe12796319a502ee37e8579e5be52acdf6ceb20a73095a94b4e80009b76ff9af`). The pure-policy RED failed because `HelperTerminationSafety` did not exist (`swift-test-helper-termination-policy-nineteenth-red.log`, SHA-256 `7b0a5f97b3013ae5460aac6958ac07a0caff7d688ff119dc04a7c243167d641d`). Startup ordering and peer-validation REDs are preserved at SHA-256 `7f7b01d6e3c086eb6b9b93947f1631fb9dcfd4fdf34cd41e5e9026c0e483d1cf` and `c6859be93b6879c4e78f5ee88775439473825b87043e0ccc8a89c10ab4b29f7f`. A final focused RED proved the one-loop signal setup left the second signal at default disposition while the first source was constructed (`swift-test-helper-termination-signal-dispositions-nineteenth-red-corrected2.log`, SHA-256 `6c99f4fde6d587914d26e9ad1ed60b174c4c156f3ba6a8f60e1c5f5a5e29c9c8`); the two preceding attempts failed only on module-cache and nested-sandbox constraints and are not counted.
- E-284 — 2026-08-06T02:35:19+0200 — Implemented only the signal latch, owned-recovery exit gate, next-tick retry eligibility, risk-increasing operation guards, synchronous recovery-first startup, two-pass signal setup, deferred-but-pre-listener peer validation, pure policy, bounded architecture wording, and focused regression. The final working-tree signal suite passed all 6 tests in `swift-test-helper-termination-signal-dispositions-nineteenth-green.log` (SHA-256 `5f1e8eb062647f21541c25e7478a72eb1344876efa6f436eb441fce3f27d9d28`). An intermediate proposed wake-cancellation allowance was rejected because cancellation cannot be safely admitted while owned recovery is pending; its RED is preserved at SHA-256 `8ec836cac5c643a956f07628403fa62d2e6d22ac099d9daac6fbafa4c5d8b688` and none of that proposal is selected.
- E-285 — 2026-08-06T02:35:19+0200 — Adversarial review caught that a provisional v6-to-v7 bump would strand an already registered v6 helper: exact source inspection shows stale/not-responding UI routes to `install()`, which only calls `register()`, while exact-version proof would reject old status. The provisional bump and every v7 assertion were reverted. `same-version-helper-freshness-gate-signal-nineteenth.log` (SHA-256 `59b7eff6f3068cc590ec29e7acc386753fc0696915d6a93fd0e8d68bbe3a85bf`) records the final v6 declaration, client, UI, and proof-policy bytes. The local SDK 27.0 `SMAppService.h` (SHA-256 `859ec2a7c4471dc1ac1e36b4de67e76d0a62ce4e4d145c942fd80cc4c2d8f8ff`) says changed daemon executables must be re-registered, recommends unregister-before-register, reports already-registered as `kSMErrorAlreadyRegistered`, and defines asynchronous unregister completion as the safe re-registration point; the bounded extract is `smappservice-replacement-contract-signal-nineteenth.log` (SHA-256 `7a9828d7b5a74ae4baf3be056f1e84c825fbf72bd356f9d5d5d32d433c60b877`). No ServiceManagement call occurred.
- E-286 — 2026-08-06T02:35:19+0200 — Curated exactly five pre-ledger paths and synthesized the HelperDaemon index blob from HEAD plus only reviewed signal hunks, excluding every overlapping `uninstallCommitted` and cleanup hunk. The immutable pre-ledger Git-index tree is `b470694bbf67ddf27b6833996f932b84bd6626d7`; its staged binary-diff SHA-256 is `ea8f57e2f9b873dba12d3a255524f8288277b965e44cdfc3e47a70e4f8c484e8`. Every index blob/mode matched the exported snapshot byte-for-byte, and both complete working-tree and staged diff checks passed in `exact-index-snapshot-compare-signal-nineteenth.log` (SHA-256 `b7b0064234af8d9635a8bbcb5ec26869eb9b09efbfef45c77d89067ba9e677ff`).
- E-287 — 2026-08-06T02:35:19+0200 — The exact index export passed all 6 termination tests in `swift-test-helper-termination-nineteenth-exact-final.log` (SHA-256 `34ece7a5dafddf2fed5b8672bf8f1cfe0584eeaa35adf91c197c7f38f05c1492`) and all 258 tests in 23 suites in `swift-test-full-signal-nineteenth-exact-final.log` (SHA-256 `b100d88789a862614b9a3d81d9bb2e796c632ab53397f6dd4530d715b22f8d3a`). These pure/source tests did not run the app, helper, widget, signals, launchd, XPC, `pmset`, or sleep hardware.
- E-288 — 2026-08-06T02:35:19+0200 — Exact Debug and Release `LidlessCore` builds passed with `CODE_SIGNING_ALLOWED=NO` (`swift-build-core-debug-signal-nineteenth-exact-final.log`, SHA-256 `b82334418c2dbdd27896e506c3b1660a7d896fc4e75ddbe2c8f7a46cf67ad784`; Release SHA-256 `c6772db40902e12c3b57336404a16c30eff91ac28584b6a07e277892b423d434`). All 25 App, 4 helper, and 1 widget sources passed macOS 15 Swift 6 complete-concurrency typechecking with warnings-as-errors and compiler-plugin sandboxing disabled (`swiftc-strict-typecheck-signal-nineteenth-exact-final.log`, SHA-256 `29378f4b438ae885f257df2beeacba05f3ae3931e670e2b9071c309519a7798b`). With signing disabled and linker ad-hoc signing suppressed, all three exact source sets compiled and linked in Debug (`swiftc-link-debug-signal-nineteenth-exact-final.log`, SHA-256 `477cc1d603b1dff1ac7d2ebd04626aff2275d76dd86849e04b9c83c61e55ccee`) and optimized Release (SHA-256 `5c804908ec04d852b65a1080228b4ce49f4a23e35390e63340af96bdcbbbf178`). No product was launched.
- E-289 — 2026-08-06T02:35:19+0200 — `artifact-config-inspection-signal-nineteenth-exact-final.log` (SHA-256 `6e7776cd933e923d1e4c221fb36d2ba38e945501b7f90164b075cafe689110c0`) records modes, sizes, hashes, thin arm64 architecture, macOS 15 / SDK 27.0 build-version commands, absence of `LC_CODE_SIGNATURE`, and `codesign`'s unsigned verdict for all six loose products; the Debug helper exports the selected policy symbols. It also records lint and decoded values for all six exact source plist/entitlement files plus central IDs and project bindings. No actual App/helper/widget bundle, bound entitlement, signed identity, or embedded launchd artifact was produced.
- E-290 — 2026-08-06T02:35:19+0200 — A first direct all-product typecheck used a stale Swift 6.3 module with Swift 6.4 and lacked fail-fast handling, so its apparent trailing pass was invalid (`swiftc-all-products-typecheck-nineteenth-dirty.log`, SHA-256 `b2c6e688465628db89f4658c2c38f8d201ccac2890c6e35c3542a0654031218d`). Correct dirty-tree helper/all-product checks subsequently passed but were superseded by the immutable exact checks in E-288. Likewise, a 265-test dirty-tree pass preceded the final startup/signal-disposition hardening and is not used as final checkpoint evidence. Every invalid, superseded, or broad-tree log remains preserved rather than silently promoted.
- E-291 — 2026-08-06T02:35:19+0200 — Three independent read-only adversarial reviews approved the exact five-file stage only as `IN_PROGRESS`. They confirmed the restore/exit trace, operation fences, startup/XPC order, v6 compatibility wording, and exclusion of broad removal/version bytes. They retained same-version executable ambiguity, safe replacement, queue latency, process-start and disposition/source windows, OS force-kill, real timer/signal/launchd, `pmset`, XPC, sleep/wake, signed bundle, and hardware behavior as open gates. No reviewer edited a file or performed a live action.
- E-292 — 2026-08-06T02:35:19+0200 — Final pre-commit main-checkout preservation passed in `main-preservation-signal-nineteenth-precommit-corrected.log` (SHA-256 `4b3136d461b222d9323c3d711d99c8e8a5b30c561813cd9728738a62000fa74c`): canonical path, exact two-worktree topology, shared Git common directory, main `main` branch/starting HEAD, clean index and tracked diff, complete three-path `.playwright-mcp` inventory, every type/mode/size/raw SHA-256, NUL-status digest `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`, and empty tracked binary-diff digest matched the authenticated rolling manifest exactly. The first harness resolved main's relative `.git` against the feature directory and stopped on the resulting false common-directory mismatch before file comparison (`main-preservation-signal-nineteenth-precommit.log`, SHA-256 `5d64630d66ee580605930ebd7936fe524723bc4f4127e84769066fe7afbe40a3`); it changed nothing and is not counted.
- E-293 — 2026-08-06T02:35:19+0200 — No App/helper/widget process, helper install/activation/registration/approval/unregister, live XPC, `pmset`, sleep-setting mutation, sleep/wake, hardware, authentication, plugin/provider/connector, Figma, network publication, release, notarization, merge, push, or main-checkout mutation was performed. Project-native Xcode build/analyze was not retried after the established nested-sandbox failure and automatic LaunchServices side-effect constraint. The checkpoint is prepared under subject `safety: retain helper recovery on termination`. Exactly the five reviewed signal code/test/documentation paths plus this append-only ledger are selected; all uninstall, broad removal, smoke, orchestration, and design remainder stays unstaged. `State: IN_PROGRESS` is intentionally retained. After this single local commit, the supervisor must authenticate the exact remaining tree in a fresh rolling manifest before another invocation.
- E-294 — 2026-08-06T02:38:28+0200 — Reviewed the complete six-path staged diff. `final-staged-review-signal-nineteenth.log` (SHA-256 `f411901ba39394a94650ecd1ad30b9d5f9d1834152d144fd10b119479f60a477`) records the full patch and confirmed the exact path set, `State: IN_PROGRESS`, a 110-addition/zero-deletion ledger append, staged tree `0c83815f70f5664a666476799845f43ad53371a2`, full staged binary-diff SHA-256 `45ae367d8331771de072f04f6bfa2eba12aefabb6defc152cb0cc64ab7d6ad19`, unchanged five-file code-diff SHA-256 `ea8f57e2f9b873dba12d3a255524f8288277b965e44cdfc3e47a70e4f8c484e8`, byte equality between every selected code/test index blob and the independently tested export, exclusion of uninstall/version/remainder bytes, and both complete working-tree and staged-diff whitespace checks. Only this final append is added afterward.

## Twentieth recovery audit — authenticated helper-removal remainder

- E-295 — 2026-08-06T02:43:45+0200 — Read the canonical handoff,
  immutable starting-state manifest, authenticated rolling remainder manifest
  and adjacent sidecar, progress log, decision log, architecture, and
  design-reset brief in full. The canonical handoff SHA-256
  `95bdacdde663c642c2f97d532c1ec2b931e94a7dfcda47b8031e011ab3944831`
  and immutable-manifest SHA-256
  `d84065171a261e24ae574b98164132472ff1e8bb635647403d814b9fcf58c36a`
  matched their supplied values. The sidecar-recorded rolling-manifest SHA-256
  `5e7ceefb948791e370212bcd8cb46fa9185fce69c3a29f65fa6d78bc41dbe848`
  matched the manifest bytes. A recursive repository scan found no
  `AGENTS.md`, `CLAUDE.md`, `CODEX.md`, or equivalent instruction file. The
  existing 1,299-line ledger working copy matched its HEAD blob byte-for-byte
  at SHA-256
  `7880830ef9cdba70076be95372b5bcc86dc96b5475db83d4da19165e31dc6cc3`
  before this append; its required top-level `State: IN_PROGRESS`, branch, and
  starting HEAD were already exact.
- E-296 — 2026-08-06T02:43:45+0200 — Applied only the authenticated rolling
  manifest as recovery authority. The feature canonical path, exact
  two-worktree linked topology, branch, HEAD
  `5a3dbedd5a34316f905676d8773532e6af6c346f`, Git admin/common directories,
  clean index, complete seven-path dirty inventory, every recorded
  status/type/mode/size/raw SHA-256, NUL-status digest
  `b776d916f5d2a7b21364484ee4ede9d5194dcc1be1fcb313fd526bc803890183`,
  and tracked binary-diff digest
  `213546c6be72f57d69bdcfcc0161bb27c535b7737171d3fa1c561c1b0dbdb87f`
  matched exactly before editing. A preliminary newline-delimited status hash
  differed because it did not preserve the manifest's NUL encoding; the
  immediately corrected NUL-delimited reproduction matched and changed no
  file. Starting HEAD
  `7f17aaca11bc6228bed48b9265d63b9e576cdea7` remains an ancestor of the
  authenticated checkpoint HEAD.
- E-297 — 2026-08-06T02:43:45+0200 — Independently reverified the rolling
  manifest's main-checkout record without editing it: canonical path and
  linked topology, `main` at
  `7f17aaca11bc6228bed48b9265d63b9e576cdea7`, clean index, complete
  three-path `.playwright-mcp` inventory, every recorded
  status/type/mode/size/raw SHA-256, NUL-status digest
  `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`,
  and empty tracked binary-diff digest
  `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`
  matched exactly. The main checkout remains untouched.

## Twentieth-checkpoint ruling — fence the daemon cleanup handoff

The authenticated seven-path remainder is not coherent enough to accept as a
single package. Complete diff review and three independent read-only audits
confirmed duplicate and unused removal-policy APIs, source-shape-heavy broad
tests, duplicate smoke assertions, stale orchestration claims, unrelated
design material, and unresolved daemon cleanup defects. In particular, the
uninstall reply still reuses status captured before wake/data cleanup; wake
ledger removal and data deletion are not one transaction; failed data deletion
can disable the file sink; the cleanup fence is not restart-durable; and
ServiceManagement replacement/freshness, blocking-call timeouts, and live
failure behavior remain open. None of those broad policy, smoke,
orchestration, design, or additional uninstall bytes is selected.

The selected defect is narrower. Once this daemon process began its fallible
cleanup sequence, a partial failure or lost reply could leave the same serial
queue willing to accept a new arm, heartbeat extension, forced sleep, wake
schedule, or unowned override-repair transaction. The selected implementation
latches a queue-local, monotonic `cleanupStarted` fence before cleanup's first
restore, wake-cancellation, or file-deletion side effect. It rejects those
risk-increasing operations while preserving observation, restoration of state
the helper already owns, wake cancellation, and cleanup retry. The direct
wake-cancellation path now retains its in-memory/persisted record when `pmset`
cancellation fails instead of clearing proof with `try?`.

This is a same-process admission checkpoint, not a durable cleanup protocol.
A daemon restart resets the fence; another process cannot observe it; work
already executing on the serial queue precedes it; the helper protocol remains
v6 and cannot prove that an installed executable contains these bytes; and no
test invokes a daemon, XPC request, `pmset`, ServiceManagement, sleep/wake,
launchd restart, or cleanup fault. The production-wiring regression is exact
source-order evidence rather than an executable daemon integration test.

### Twentieth-checkpoint finding and verification matrix

| ID | Invariant | Exact checkpoint evidence | Remaining boundary | Ruling |
| --- | --- | --- | --- | --- |
| S-48 | Cleanup admission closes before this daemon process performs its first fallible cleanup side effect | The queue-local fence is assigned `.cleanupStarted` before restore, wake cancellation, data deletion, or success reply; pure operation tables reject arm, heartbeat, force sleep, new wake scheduling, and new override repair | The fence is not persistent or cross-process, does not cover already-running queue work, and does not prove cleanup completion | CHECKPOINT VERIFIED OFFLINE — RESTART/CROSS-PROCESS/COMPLETION GATES OPEN |
| S-49 | Cleanup ambiguity does not block already-owned recovery work | The policy admits observation, owned restoration, wake cancellation, and cleanup retry; repair classifies existing sentinel/pending recovery separately from a new repair; uninstall remains callable after the latch | No live retry, restore, XPC, `pmset`, or failure-injection path was executed | CHECKPOINT VERIFIED OFFLINE — LIVE/FAULT GATES OPEN |
| S-50 | Failed direct wake cancellation cannot discard the daemon's only scheduled-wake record | The `epoch <= 0` branch returns a failure before clearing or persisting `scheduledWake`; the focused RED caught the prior `try?`/clear ordering | Wake persistence and uninstall-time cancellation remain non-transactional; external state was not observed | CHECKPOINT VERIFIED OFFLINE — PERSISTENCE/PMSET GATES OPEN |
| V-31 | Exact selected bytes pass RED/GREEN, focused, complete, strict compile, and unsigned Debug/Release checks | Pre-ledger tree `d96cd5a370153f87f14b7f59a9cfb6c8bcdac05f` passed 3 exact focused tests, all 261 exact tests, Debug/Release core builds and App/helper/widget links, plus Swift 6 complete-concurrency typechecking with warnings-as-errors | The wiring test reads exact source; project-native Xcode build/analyze was not retried under the established nested-sandbox and automatic LaunchServices side-effect constraint | PASS FOR EXACT OFFLINE CODE — EXECUTABLE-INTEGRATION/XCODE GRAPH OPEN |
| V-32 | Loose build and source-configuration evidence remains bounded to what was inspected | Six direct arm64 outputs target macOS 15 / SDK 26.5, lack `LC_CODE_SIGNATURE`, and fail `codesign` inspection as unsigned; source plists/entitlements and the project file linted, decoded, and matched project bindings | Outputs are not bundles and prove no bound entitlement, signing identity, installed helper, XPC trust, registration, notarization, or runtime behavior | PARTIAL — BUNDLE/SIGNING/RUNTIME GATES OPEN |

- E-298 — 2026-08-06T03:03:15+0200 — Reproduced the complete authenticated
  dirty-package baseline before accepting a remainder claim. Xcode-beta 27.0
  Swift passed 265 tests in 24 suites in
  `swift-test-twentieth-dirty-baseline.log` (SHA-256
  `dad6813069607f07228031bc40a523e05dcd635655714a6598b4ce625bd2e362`).
  Complete diff review plus three independent read-only audits rejected the
  broad remainder for the concrete defects and evidence limits listed above.
  No reviewer edited a file.
- E-299 — 2026-08-06T03:03:15+0200 — Confirmed the separable daemon defect:
  cleanup could begin and fail ambiguously while the same daemon process
  remained open to new risk-increasing work. The initial focused RED failed
  because `HelperRemovalDaemonSafety` did not exist
  (`swift-test-helper-removal-daemon-fence-red.log`, SHA-256
  `c37e216fdfccb2e6ee0f7b7bb85e19b2ce0a05388f91f05fccef36ce12a52f28`).
  The policy and queue-local wiring then made the operation table GREEN.
- E-300 — 2026-08-06T03:03:15+0200 — Adversarial review tightened the
  checkpoint to cover request-time and delayed force sleep, watchdog
  heartbeat, existing-owned versus new override repair, new wake versus wake
  cancellation, and latch ordering. The hardened test exposed a second RED:
  direct wake cancellation used `try?`, cleared `scheduledWake`, and persisted
  that loss even when cancellation failed
  (`swift-test-helper-removal-daemon-cancel-red.log`, SHA-256
  `79b29d25943f435f17cb0e3f2d84496090ca7b319a054cbb63153c410b178d8a`).
  The focused correction returns failure and retains the record.
- E-301 — 2026-08-06T03:03:15+0200 — Final focused working-tree GREEN passed
  all 3 daemon-fence tests in
  `swift-test-helper-removal-daemon-fence-hardened-green2.log` (SHA-256
  `9861fcf46d26746f7e5f156b1cc81aaee6a606bdbf7b99443d8bb36870fa816c`),
  and 23 related removal tests passed in 6 suites in
  `swift-test-helper-removal-related-green.log` (SHA-256
  `1a2717b4759a61f9d37f0e6e48c2dbc3943441a670b8161ac52af005d261cbf2`).
  The complete dirty tree passed 268 tests in 25 suites in
  `swift-test-twentieth-dirty-final.log` (SHA-256
  `63d55ba1067c29702f83e2037c24737032f2e9c1682068c48b9ca69fed85ca9e`).
  The unstaged broad removal test needed a source-anchor adaptation for that
  dirty-tree pass; those adaptation bytes and the broad test remain excluded,
  and the pass does not cure the rejected remainder.
- E-302 — 2026-08-06T03:03:15+0200 — Curated exactly three code/test paths.
  The immutable pre-ledger Git-index tree is
  `d96cd5a370153f87f14b7f59a9cfb6c8bcdac05f`; its staged binary-diff SHA-256
  is `1cff7b4b3210389f9d40baea646ec2d54c740dc244cae6d1e283e1a2c48e00f0`.
  Exact staged blob SHA-256 values are
  `bb604f45397ca0a1c8b29677ca1ffa2ad8a8bfcd92326faf8f576777a16f351a`
  for `HelperDaemon.swift`,
  `e0c02c67d7112d4f53d8546e2ab855c50fc16e3161b3952d4e533d54ae900e2a`
  for the pure policy, and
  `adabd1e656fda43a734f083e61c91b9338cec6c5f9e3311ae5f5b25a2287e3c2`
  for the regression. The index was exported independently, each blob matched,
  and `git diff --cached --check` passed.
- E-303 — 2026-08-06T03:03:15+0200 — The exact index snapshot passed all 3
  daemon-fence tests in
  `swift-test-helper-removal-daemon-fence-exact-final.log` (SHA-256
  `420d98dadda540abfc4601a9be094a28f89bef9dba1c8c35c6a0f2a1aa0ccf3c`)
  and all 261 tests in 24 suites in
  `swift-test-twentieth-exact-final.log` (SHA-256
  `ceccffa98fb87809a710960301fa447864d7e1fbf1efde2642986c7d915f7401`).
  Complete output is preserved; no App, helper, or widget product was launched.
- E-304 — 2026-08-06T03:03:15+0200 — From that same exact snapshot, stable
  Xcode 26.5 Swift 6.3.2 built `LidlessCore` and strictly compiled and directly
  linked all 25 App, 4 helper, and 1 widget sources in Debug
  (`direct-all-products-debug-twentieth-exact.log`, SHA-256
  `5d4b82f7c5f9492c150813b40957dd8a0c59e0c1400e899d31ea59529c9c7daf`)
  and optimized Release
  (`direct-all-products-release-twentieth-exact.log`, SHA-256
  `1f196f4e4b337327f476a201a0ab78a9c23b747079b830e3ae1a7ea60bdd2d4e`).
  `CODE_SIGNING_ALLOWED=NO`, Swift 6 complete strict concurrency,
  warnings-as-errors, compiler sandbox disabling, and linker ad-hoc-signature
  disabling were explicit. A separate all-products typecheck passed with the
  same strict settings in
  `static-typecheck-all-products-twentieth-exact.log` (SHA-256
  `37fdb73d01d2269b965104d9a20a3926ddba9797f70e8d3428c70c160ee2241b`).
- E-305 — 2026-08-06T03:03:15+0200 —
  `artifact-config-inspection-twentieth-exact.log` (SHA-256
  `e203d1ea2f988703d0c3ec288de239e0ab5b50f7b203a25a396e4e14f03792f0`)
  preserves file type, arm64 architecture, macOS 15 / SDK 26.5 build versions,
  absence of `LC_CODE_SIGNATURE`, and `codesign`'s unsigned verdict for all six
  loose Debug/Release products; the Debug helper exports the selected policy
  symbols. The same log preserves lint and decoded values for the exact App,
  helper, and widget plist/entitlement sources, project-file syntax, and the
  relevant project bindings. These are unbundled compile artifacts, not
  signed-runtime or release evidence.
- E-306 — 2026-08-06T03:03:15+0200 — Independent daemon, adversarial, and
  test-evidence reviews found no blocker within the narrow same-process,
  serial-queue admission claim. They explicitly left restart and cross-process
  persistence, ServiceManagement ABA/executable freshness, stale pre-cleanup
  status, log-sink recovery, wake-ledger transactionality, cleanup completeness,
  blocking-call timeouts, protocol-v6 freshness, and live XPC/`pmset` behavior
  open. They also classified the production-wiring regression as source-shape
  evidence rather than daemon execution evidence.
- E-307 — 2026-08-06T03:03:15+0200 — Post-build main-checkout preservation
  passed in `main-preservation-twentieth-precommit.log` (SHA-256
  `cc4a148159127d7bee74d75058fe827454a4071e93643b344396524bff1c1bde`):
  canonical paths, exact two-worktree topology, shared Git common directory,
  main `main` branch/starting HEAD, clean index and tracked diff, complete
  three-path `.playwright-mcp` inventory, every type/mode/size/raw SHA-256,
  NUL-status digest
  `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`,
  and empty tracked binary-diff digest matched the rolling authority exactly.
- E-308 — 2026-08-06T03:03:15+0200 — No App/helper/widget process, helper
  install/activation/registration/approval/unregister, live XPC, `pmset`, sleep
  setting, sleep/wake, hardware, authentication, plugin/provider/connector,
  Figma, network publication, release, notarization, merge, push, or
  main-checkout mutation was performed. Project-native Xcode build/analyze was
  not retried after the established nested-sandbox failure and automatic
  LaunchServices side-effect constraint. The checkpoint is prepared under
  subject `safety: fence daemon cleanup handoff`. Exactly the daemon fence
  policy/wiring, focused regression, and this append-only ledger are selected;
  all other removal, smoke, orchestration, and design remainder stays unstaged.
  `State: IN_PROGRESS` is intentionally retained. After this single local
  commit, the supervisor must authenticate the exact remaining tree in a fresh
  rolling manifest before another invocation.
- E-309 — 2026-08-06T03:05:17+0200 — Reviewed the complete four-path staged
  diff. `final-staged-review-twentieth-corrected.log` (SHA-256
  `59d0c9b259a3c915cfa74dd3eb14872c5612ff217d77c8d7f52d3d2a2827a3f1`)
  records the full patch and confirmed the exact curated path set, the required
  top-level `State: IN_PROGRESS`, a 199-addition/zero-deletion ledger append,
  staged tree `4188d15f2201495d84207a4106b000dd795d228b`, full staged binary-diff
  SHA-256 `e7708b317ff9ede9ced6a35670806717fb2ad4e8d09437d88d4c8a7683711edd`,
  unchanged three-file code-diff SHA-256
  `1cff7b4b3210389f9d40baea646ec2d54c740dc244cae6d1e283e1a2c48e00f0`,
  byte equality between every selected code/test index blob and the independently
  tested snapshot, and both complete working-tree and staged-diff whitespace
  checks. The first review harness incorrectly asserted that `State` was the
  ledger's first line instead of its established third line and stopped without
  changing source or index (`final-staged-review-twentieth-pre-final-entry.log`,
  SHA-256 `64261f1b35ccb8ab3feb992f757b42c1ad3b6b6db24cdbbc428e37dd255a2690`);
  it is not counted. Only this final evidence entry is appended afterward.

## Twenty-first recovery audit — authenticated final remainder

- E-310 — 2026-08-06T03:12:03+0200 — Read the canonical handoff, immutable
  starting-state manifest, authenticated rolling remainder manifest and its
  adjacent sidecar, progress log, decision log, architecture, design-reset
  brief, CONTRIBUTING guidance, and this complete 1,514-line append-only
  ledger. The canonical handoff SHA-256
  `95bdacdde663c642c2f97d532c1ec2b931e94a7dfcda47b8031e011ab3944831`
  and immutable-manifest SHA-256
  `d84065171a261e24ae574b98164132472ff1e8bb635647403d814b9fcf58c36a`
  matched their supplied values. The sidecar-recorded rolling-manifest
  SHA-256
  `78e697c6983da56198a0de54436bc795c3f9531c59aa2af348ac7659798a7e62`
  matched the manifest bytes. A repository-wide hidden-file scan found no
  `AGENTS.md`, `CLAUDE.md`, `CODEX.md`, `GEMINI.md`, `.cursorrules`,
  `copilot-instructions.md`, or matching agent instruction file. Before this
  append, the ledger working copy matched its HEAD blob byte-for-byte at
  SHA-256
  `f7930e99cba0064b56414371ab93e81a941908ca5aec266ce3dc8e36874925dc`;
  its required top-level `State: IN_PROGRESS`, branch, and starting HEAD were
  already exact.
- E-311 — 2026-08-06T03:12:03+0200 — Applied only the authenticated rolling
  manifest as recovery authority. The feature canonical path, exact
  two-worktree linked topology, branch, HEAD
  `19a593ebacdaa9c6aac50bf98495672bc360db91`, linked Git admin/common
  directories, clean index, complete seven-path dirty inventory, every
  recorded status/type/mode/size/raw SHA-256, NUL-status digest
  `b776d916f5d2a7b21364484ee4ede9d5194dcc1be1fcb313fd526bc803890183`,
  and tracked binary-diff digest
  `be639c056a93fa174e21b8e5011f3621276e06d344268b274d8f375191a2657b`
  matched exactly before editing. Starting HEAD
  `7f17aaca11bc6228bed48b9265d63b9e576cdea7` remains an ancestor of the
  authenticated checkpoint HEAD. A second independent read-only audit
  reproduced the same fields and bytes.
- E-312 — 2026-08-06T03:12:03+0200 — Independently reverified the rolling
  manifest's main-checkout record without editing it: canonical path and
  linked topology, `main` at
  `7f17aaca11bc6228bed48b9265d63b9e576cdea7`, clean index, complete
  three-path `.playwright-mcp` inventory, every recorded
  status/type/mode/size/raw SHA-256, NUL-status digest
  `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`,
  and empty tracked binary-diff digest
  `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`
  matched exactly. The main checkout remains untouched.
- E-313 — 2026-08-06T03:12:03+0200 — Discarded two preliminary read-only
  recovery presentations before accepting the verdict. A newline-delimited
  status digest differed because the rolling authority uses NUL-delimited
  porcelain bytes. A later zsh inventory loop shadowed the shell's special
  `path` parameter and then compared full status lines rather than their
  two-character status fields. Both probes changed no file and supplied no
  recovery verdict; corrected task-specific-variable checks reproduced every
  field recorded in E-311 and E-312. Recovery passed before this append and
  `State: IN_PROGRESS` remains correct.

## Twenty-first checkpoint — fail-closed helper cleanup completion

Complete remainder review rejected the broad package as one checkpoint. The
new `HelperRemovalSafety` Boolean APIs are unused duplicates of the committed
app-removal admission and action policies, and one erases the intentional
`unregister` versus `alreadyInactive` result. The broad untracked removal suite
tests those dead APIs and mixes duplicate policy, copy, and source-shape
claims. The smoke additions duplicate an existing protocol-version assertion
and test widget Codable preservation rather than removal safety. The progress
and decision edits plus the untracked design brief are stale, founder-gated,
or unrelated. All of those bytes remain preserved and excluded.

The selected root cause is narrower: uninstall previously suppressed both
scheduled-wake cancellation and helper-data deletion errors, then returned
success with status captured before those cleanup attempts. The correction
fails closed on either required cleanup error, treats only an exact-target
`fileNoSuchFile` as already absent, restores the local file-audit sink when the
daemon must remain registered, obtains fresh status after cleanup, and grants
success only after that fresh status still proves normal sleep. Failure text
is deliberately neutral because the fresh status can report an unverified or
non-normal state.

This is offline, source-bounded evidence. The regression reads exact source
ordering; Swift Package Manager does not compile or execute `HelperDaemon` or
`HelperLog`. Strict direct all-product compilation is therefore required in
addition to package tests, and neither form of evidence exercises a daemon,
XPC connection, filesystem fault, `pmset`, ServiceManagement, or hardware.

### Twenty-first-checkpoint finding and verification matrix

| ID | Invariant | Exact checkpoint evidence | Remaining boundary | Ruling |
| --- | --- | --- | --- | --- |
| S-51 | A required scheduled-wake cancellation error cannot be converted into uninstall success | The uninstall branch uses throwing cancellation; its catch captures fresh status, replies `ok: false`, and returns before clearing the in-memory record or attempting data removal | Cancellation timeout is outcome-unknown; persisted wake cleanup and later directory deletion are not transactional | CHECKPOINT VERIFIED OFFLINE — PMSET/TRANSACTION GATES OPEN |
| S-52 | Helper-data cleanup succeeds only after removal or proof that the exact target was already absent | Cleanup performs unconditional removal and ignores only Cocoa `fileNoSuchFile` whose reported path exactly equals the configured work directory; every missing-descendant or other error fails closed | Foundation/filesystem behavior and fault races were not executed; removal is unbounded | CHECKPOINT VERIFIED OFFLINE — FILESYSTEM/FAULT GATES OPEN |
| S-53 | A failed removal attempt preserves diagnostic admission and reports contemporaneous state without asserting safety | Both post-disable failure branches synchronously re-enable the file sink before logging/replying; wake and data errors use fresh status and neutral text | Re-enabling admission does not prove a file write succeeded, and logging can recreate a successfully deleted work directory after final-proof loss | CHECKPOINT VERIFIED OFFLINE — DURABILITY/FAULT GATES OPEN |
| S-54 | Cleanup success uses a post-cleanup normal-sleep proof | Status is read after wake clearing and data removal, guarded by `SleepOverrideSafety.isRestoreProven`, and the exact guarded status is returned on success; failed proof returns false first | The read is point-in-time, not atomic through the app's later unregister/readback sequence | CHECKPOINT VERIFIED OFFLINE — RUNTIME/ATOMICITY GATES OPEN |
| V-33 | Focused RED/GREEN and broad package evidence discriminate the selected source-order defect | Exact-HEAD-plus-test and preserved-tree REDs failed before implementation; hardened review RED failed on neutral text and exact-target classification; five focused tests, 25 related working-tree tests, and all 270 working-tree tests then passed | Working-tree related/full runs include excluded broad remainder; exact-index evidence is still required | PASS FOR WORKING TREE — EXACT INDEX/PRODUCT COMPILE PENDING |

- E-314 — 2026-08-06T03:24:26+0200 — Reviewed the complete authenticated
  seven-path remainder against HEAD before selecting any byte. Three
  independent read-only audits rejected a broad commit for duplicate/dead
  policy APIs, confounded source-shape tests, duplicate smoke coverage, stale
  orchestration claims, unrelated design material, and concrete uninstall
  defects. No reviewer edited a file. Exactly `HelperDaemon.swift`,
  `HelperLog.swift`, focused additions to the committed
  `HelperRemovalDaemonFenceTests.swift`, and this append-only ledger are
  candidates; every other authenticated remainder path stays excluded.
- E-315 — 2026-08-06T03:24:26+0200 — Before the selected tests or
  implementation changed, stable Xcode 26.5 Swift 6.3.2 passed the complete
  preserved dirty package's 268 tests in 25 suites in
  `swift-test-twenty-first-baseline.log` (SHA-256
  `f660e7eb269537ffc360061ec3e160ab759c9a643a0e022d928a8f222c4c47f8`).
  This is only a baseline because it includes excluded dirty/untracked bytes
  and does not compile the daemon product.
- E-316 — 2026-08-06T03:24:26+0200 — The focused regression was first run
  against an exact HEAD snapshot plus only the new test bytes: 3 of 5 tests
  failed because HEAD suppressed wake and data cleanup errors and lacked the
  final proof (`swift-test-helper-cleanup-head-red.log`, SHA-256
  `b1fb88a9d3a93b28f69442b480330d4157a9232afcd2fa619f87308b830bc370`).
  Against the preserved candidate implementation, 2 of 5 failed on file-sink
  recovery and fresh final status
  (`swift-test-helper-cleanup-red.log`, SHA-256
  `132e306647d827b0db9f8962a854238eef47628ed7abca09dce7cceb990732ca`).
  The first focused correction passed all 5 tests in
  `swift-test-helper-cleanup-green.log` (SHA-256
  `b0a73b46751cf6ed00118bce98244dc94554640c60154a383a5a366b79c944a3`).
- E-317 — 2026-08-06T03:24:26+0200 — Adversarial re-review identified that
  two failure messages falsely asserted restored sleep and that blanket Cocoa
  `fileNoSuchFile` handling could misclassify a missing descendant. The
  tightened test produced a 2-issue RED in
  `swift-test-helper-cleanup-review-red.log` (SHA-256
  `e37a8b89d397fc7bf5c10ba0b9ce014bc95d29cb9f7f5422b8ba47977daff798`),
  then neutral text and exact error-path classification passed all 5 focused
  tests in `swift-test-helper-cleanup-review-green.log` (SHA-256
  `7ebbf919b13bb16e7a73ee135c3ec0111ca36c2e3c11f73aaeb09ccf7a3db634`).
  The working tree then passed 25 related tests in 6 suites
  (`swift-test-helper-removal-related-working.log`, SHA-256
  `0dceb60644378ac55e4353ea8fd3e18011e182562db70581d60dc21527579deb`)
  and all 270 tests in 25 suites
  (`swift-test-twenty-first-working-green.log`, SHA-256
  `07d92d50008b02a65218e648c616a783bd4711ed29304530f70b37e5e521244e`).
  Those two broad passes include the excluded untracked suite and are not
  substituted for an exact-index run.

### Twenty-first checkpoint boundary correction and exact completion

The earlier root-cause paragraph and S-53 phrase “A failed removal attempt
preserves diagnostic admission” are too broad and are superseded, not erased,
by this correction: file-sink admission is restored only for a
**daemon-detected post-disable data-cleanup or final-proof failure**. If the
helper returns `ok: true` but the app later fails its independent restore
proof, unregister call, or final registration proof, the helper can remain
registered in the same process with its file sink intentionally disabled.
That app-side post-reply case remains an open diagnostic-recovery gate.

| ID | Invariant | Exact checkpoint evidence | Remaining boundary | Ruling |
| --- | --- | --- | --- | --- |
| S-55 | A daemon-detected post-disable cleanup or final-proof failure restores file-sink admission before the daemon reports failure | The two bounded daemon branches synchronously call `enableFileSink`, log, reply `ok: false`, and return; the disable/enable methods are separately pinned to one synchronous false/true assignment | App-side failure after helper success can leave a still-registered helper with its sink disabled; admission does not prove a write succeeds | CHECKPOINT VERIFIED OFFLINE — APP-HANDOFF/DURABILITY GATES OPEN |
| V-34 | Exact selected code and hardened tests pass focused, related, complete, strict compile, and unsigned Debug/Release checks | Pre-final-ledger index tree `47dfd000ccc90aed9a6fc70f5a7568adfe5fe283` passed 5 focused, 20 related, and all 263 exact tests; unchanged exact product inputs passed Debug/Release core builds, direct App/helper/widget links, and complete-concurrency typechecking with warnings-as-errors | Source-order tests do not execute daemon branches; project-native Xcode build/analyze was not retried under the established nested-sandbox and automatic LaunchServices side-effect constraint | PASS FOR EXACT OFFLINE CODE — EXECUTABLE-INTEGRATION/XCODE GRAPH OPEN |
| V-35 | Loose output and source-configuration inspection stays bounded to observed facts | Six direct arm64 outputs target macOS 15 / SDK 26.5, lack `LC_CODE_SIGNATURE`, fail `codesign` inspection as unsigned, and the Debug helper contains the corrected failure text; source plists, entitlements, project syntax, and relevant bindings linted | Outputs are not bundles and prove no embedded entitlement, identity, installed-helper freshness, XPC trust, registration, notarization, or runtime behavior | PARTIAL — BUNDLE/SIGNING/RUNTIME GATES OPEN |

The remaining safety gates are explicit. Wake cancellation and removal of its
disk ledger are not atomic, so cancellation followed by deletion failure or a
crash can leave a stale record that restart retries. A `pmset` timeout remains
outcome-unknown and no external readback proves wake cancellation. App/client
and daemon fences are process-local; restart, replacement, and
ServiceManagement ABA can reopen risk-increasing work. Optional low-power and
TCP keepalive restoration remains best-effort and partially silent. Protocol
v6 is not binary-freshness attestation and no safe replacement flow is proved.
Filesystem/log operations are unbounded. Final status is point-in-time rather
than atomic through app readback and unregister. No live daemon, XPC,
filesystem fault, `pmset`, ServiceManagement, restart, signing, sleep/wake, or
hardware behavior was exercised.

- E-318 — 2026-08-06T03:37:43+0200 — Curated exactly four staged paths. The
  pre-final-ledger index tree is
  `47dfd000ccc90aed9a6fc70f5a7568adfe5fe283`; its full staged binary-diff
  SHA-256 is
  `4477dfebf4414842f0c3e70978860dc9c8b3607321886991a239d0afef964d0d`,
  and its three-file code/test diff SHA-256 is
  `8e3278ab06674449aea28d3a0d12a03675f0df0145bbffb3873ecdd8576852b4`.
  Exact staged blob SHA-256 values are
  `27c87d1e716bf2054e83060fb9754ac4a2f510002f40a85a2e3cb11e8c65b94e`
  for `HelperDaemon.swift`,
  `99c55c66d52a6a83153760aaae9d3e04a0cbc69931abac2871dfdf578fe78b93`
  for `HelperLog.swift`, and
  `0c657ec12dcc9a05cfafa023bc3331e9c3860cf06e5ac39952e10842f315e01b`
  for the hardened regression. Independent index exports matched all three
  blobs byte-for-byte; `git diff --cached --check` passed.
- E-319 — 2026-08-06T03:37:43+0200 — Final adversarial review first found
  that the source test did not bind `ok: false` to three failure replies, the
  exact absent-target conjunction to one catch, general-catch ordering to
  re-enable, wake return/clear to later deletion, or the true assignment to
  `enableFileSink`. The hardened test now binds all of those relations. A
  temporary exact-index mutation changing all three selected failure replies
  to `ok: true` produced exactly 3 focused issues
  (`swift-test-helper-cleanup-false-success-mutation-red.log`, SHA-256
  `85c4201fe41e3d152ced3972cc45323585739949a2b3bc9d72cc5fb8bfb72024`).
  The corrected working source passed all 5 focused tests in
  `swift-test-helper-cleanup-hardened2-working-green.log` (SHA-256
  `650e2e32f9cafc4781840f2c95c3f410fe9c5ced45e292c299444f012bdf52e1`).
  Independent final test review then reported no remaining blocker within the
  narrow source-order claim.
- E-320 — 2026-08-06T03:37:43+0200 — Stable Xcode 26.5 Swift 6.3.2 passed
  all 5 focused exact-index tests in
  `swift-test-helper-cleanup-exact-final2.log` (SHA-256
  `9384c09cd92c2a22a2b165ddfe98116a24006aa0ffe32cc3fe3e288fd6469b58`),
  all 20 related exact tests in 5 suites in
  `swift-test-helper-removal-related-exact-final.log` (SHA-256
  `63c04426a9bb93cb765e0f254db008d01b01e1f06ef6b3b2ffaebe5a47edbe45`),
  and all 263 exact tests in 24 suites in
  `swift-test-twenty-first-exact-final2.log` (SHA-256
  `a53a180462c5ddf3322db765604f1f12e18716b802d34df02d26a7198f4ad0a5`).
  A preceding exact-focused invocation used a mistyped, unwritable cache path
  and failed before manifest compilation; it supplied no source verdict and
  is preserved but not counted at SHA-256
  `8eade618649dce1cb3c9ca909ee87023451bd53f2f55529eec9fb8364a43c500`.
- E-321 — 2026-08-06T03:37:43+0200 — From the independently exported exact
  index, stable Xcode 26.5 Swift 6.3.2 built `LidlessCore` and strictly
  compiled and directly linked all 25 App, 4 helper, and 1 widget sources in
  Debug (`direct-all-products-debug-twenty-first-exact.log`, SHA-256
  `ec93a85ddb428bd8016a8f96cc816688dbe2ead62e9a0d32eb9cd1ed9de1a29c`)
  and optimized Release
  (`direct-all-products-release-twenty-first-exact.log`, SHA-256
  `eefc65069ff70a9d9c1749682acac549615e512064d73acbe8060c26765e734f`).
  `CODE_SIGNING_ALLOWED=NO`, `CODE_SIGNING_REQUIRED=NO`, Swift 6 complete
  concurrency, warnings-as-errors, compiler sandbox disabling, and linker
  ad-hoc-signature disabling were explicit. A separate strict all-product
  typecheck passed in
  `static-typecheck-all-products-twenty-first-exact.log` (SHA-256
  `81f8e0161254e58dfdfb5834a3496902be74474aac3a387d2590764a4723c63f`).
  The later hardened-test snapshot's complete product/config input digest
  exactly matched the build snapshot at
  `5605b9bbba6b43b306e56ffcd67432be50714bd0563e544ebde420b36ad6d128`,
  so only test/ledger evidence changed afterward.
- E-322 — 2026-08-06T03:37:43+0200 —
  `artifact-config-inspection-twenty-first-exact.log` (SHA-256
  `ebb271cc5bf6c28a41c4ee00dd5fd40cae0ed014f59bb36f1588aa89205a7248`)
  preserves file type, exact architecture, build-version commands, absence of
  signature load commands, and `codesign`'s unsigned verdict for all six loose
  products. It also binds the three corrected failure strings into the Debug
  helper and preserves lint/decoded values for the source App, helper, and
  widget plist/entitlement files, project-file syntax, and relevant project
  bindings. These are loose compile artifacts, not application bundles.
- E-323 — 2026-08-06T03:37:43+0200 — Independent daemon, scope, and
  adversarial-test reviews found no production or evidence blocker within the
  corrected in-process/source-order claim. They retained every gate listed
  above, including the app-side post-success sink state. The duplicate policy
  APIs, broad untracked removal test, smoke edits, progress/decision edits,
  and design brief remain excluded and unstaged.
- E-324 — 2026-08-06T03:37:43+0200 — Post-build main-checkout preservation
  passed in `main-preservation-twenty-first-precommit.log` (SHA-256
  `748dc001b321220e3d6061bf5e30566ad3d724fbd1134b988f59eeea5a057f67`):
  canonical paths, exact two-worktree topology, shared Git common directory,
  main branch/starting HEAD, clean index and tracked diff, complete three-path
  `.playwright-mcp` inventory, every status/type/mode/size/raw SHA-256,
  NUL-status digest
  `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`,
  and empty tracked binary-diff digest matched the rolling authority exactly.
  No App/helper/widget process, helper install/activation/registration/
  approval/unregister, live XPC, `pmset`, sleep-setting mutation, sleep/wake,
  hardware, authentication, plugin/provider/connector, Figma, network
  publication, release, notarization, merge, push, or main-checkout mutation
  was performed. Project-native Xcode build/analyze was not retried after the
  established nested-sandbox failure and automatic LaunchServices side-effect
  constraint. The checkpoint is prepared under subject
  `safety: fail closed on helper cleanup errors`; `State: IN_PROGRESS` is
  intentionally retained. After this single local commit, the supervisor must
  authenticate the exact remaining tree in a fresh rolling manifest before
  another invocation.
- E-325 — 2026-08-06T03:39:59+0200 — Reviewed the complete corrected
  four-path staged diff. `final-staged-review-twenty-first-pre-final-entry.log`
  (SHA-256
  `06364e00023b0851693fcac488f72e4ad9c9f51fabc2654287597876599bc88c`)
  records the full patch and confirms the exact curated path set, sole
  top-level `State: IN_PROGRESS`, a 265-addition/zero-deletion ledger append,
  pre-entry index tree `b14960aa9b6028767db9b4b8f99db43cf2a2f19b`, full
  staged binary-diff SHA-256
  `d6d674d0922e48cbdf07e38a5f34f83380809ee1c16e98a1e7a12a65257460f1`,
  unchanged tested code/test diff SHA-256
  `8e3278ab06674449aea28d3a0d12a03675f0df0145bbffb3873ecdd8576852b4`,
  byte equality between all three selected code/test index blobs and the final
  tested snapshot, and both complete working-tree and staged-diff whitespace
  checks. The final independent scope review passed after the sink-boundary
  correction; the final adversarial test review passed after the source-order
  hardening. Only this terminal evidence entry is appended afterward; no
  code/test byte or accepted verification result changed.

## Twenty-second invocation — authenticated recovery

- E-326 — 2026-08-06T03:47:55+0200 — Read the canonical handoff, immutable
  state manifest, rolling remainder manifest and its adjacent SHA-256
  sidecar, current progress and decision logs, architecture, and design-reset
  brief in full before editing. The handoff and immutable-manifest SHA-256
  values matched the supplied values. The rolling sidecar and independently
  calculated manifest digest both equal
  `4ca4b938458f56e88ce6f9e85ec5b2ca26f9b7b20e5fe046f44dce5986568ca1`.
  A repository scan found no `AGENTS.md`, `CLAUDE.md`, `CODEX.md`, `GEMINI.md`,
  or other Markdown agent-instruction file.
- E-327 — 2026-08-06T03:47:55+0200 — Reproduced every rolling-authority field
  before this append. The canonical feature worktree is the registered linked
  worktree on `codex/lidless-safety-repair-2026-08-04` at
  `315cc9f416d418c07938c5c7dd226a1b3842ddae`; its admin directory is
  `/Users/junaid/Xcode-Projects/Lidless/.git/worktrees/codex-safety-repair-2026-08-04`
  and common directory is `/Users/junaid/Xcode-Projects/Lidless/.git`. Its
  index is clean and unmerged-entry list empty. All six dirty paths matched
  their exact recorded two-character status, regular-file type, mode, byte
  count, and raw SHA-256 with no extra or missing path. Its NUL-delimited
  complete-status digest was
  `5cf63a070dfe49313ecf75b3b2b7c3995af41ba5f22a8c4c39523108c7863b09`
  and tracked binary-diff digest was
  `9246b662e27202b4da57f7adb476aae9ab0133cae5176c50d3a8a115cc34ea6f`.
  Recovery passed exactly; the historical starting-state manifest was not
  misapplied to this post-checkpoint HEAD and `State: IN_PROGRESS` remains
  correct.
- E-328 — 2026-08-06T03:47:55+0200 — Independently reproduced the main
  checkout preservation record without editing it: canonical path
  `/Users/junaid/Xcode-Projects/Lidless`, branch `main`, starting HEAD, clean
  index, empty unmerged list and tracked diff, exactly the three recorded
  untracked `.playwright-mcp` paths, every recorded type/mode/size/raw digest,
  NUL-status digest
  `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`,
  and empty tracked binary-diff digest
  `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.

## Twenty-second checkpoint — exact helper behavior revision

The complete six-path authenticated remainder was reviewed against HEAD before
selecting any change. Its two additional `HelperRemovalSafety` predicates
duplicate already committed app-removal admission and action policies, and one
collapses the intentional `unregister` versus `alreadyInactive` result. The
broad untracked test primarily exercises those duplicate predicates and mixes
unrelated source-shape claims. The smoke additions duplicate an existing
protocol-version check and add unrelated widget-Codable coverage. The progress,
decision, and design-reset edits are stale or outside this safety checkpoint.
All six paths remain byte-for-byte preserved and excluded.

The selected defect is a compatibility-boundary failure. Historical commit
`ff6ece4cefd8d312525e8abead7bc760db80eea1` shipped protocol v6 while its
uninstall handler suppressed required wake-cancellation and data-removal
errors, cleared the wake record after an unproved cancellation, and returned
success with status captured before cleanup. The pre-checkpoint app accepted
any responding protocol-v6 helper as ready. Consequently, an already
registered old v6 helper could be accepted by a newer app and its unsafe
uninstall reply could authorize deregistration. Protocol equality did not
identify the implemented safety behavior.

This checkpoint adds app-required safety revision 1 to `HelperStatus`, makes
construction explicit, and gives the daemon a separate producer-owned
implemented revision. Missing, older, and future revisions fail closed at
readiness, arm, restore, outside-ownership, enabled-registration removal, and
scheduled-wake acceptance. The integer is self-reported compatibility
metadata. It is not cryptographic executable identity, installed-byte
freshness, or an installation receipt.

An already enabled pre-revision v6 helper is now deliberately stranded in a
fail-closed state: it remains reachable for de-risking XPC requests, but its
replies cannot complete app proof or authorize unregister. The current Setup
path calls `register()` rather than a proved unregister-completion-register
replacement transaction, so it cannot replace that helper. UI copy also
overstates self-reported compatibility as verification. These are deployment
blockers; this checkpoint is not upgrade-complete and must remain
`State: IN_PROGRESS`.

### Twenty-second-checkpoint finding and verification matrix

| ID | Invariant | Exact checkpoint evidence | Remaining boundary | Ruling |
| --- | --- | --- | --- | --- |
| S-56 | Protocol equality alone cannot authorize a safety transition | `isCurrentHelper` requires exact protocol v6 and safety revision 1; arm, restore, two-source restore, outside-ownership, failed-arm disposition, recovery-gate completion, and enabled-registration removal regressions reject missing/0/2 and accept 1 | Revision is self-reported and does not identify installed bytes | CHECKPOINT VERIFIED OFFLINE — ATTESTATION GATE OPEN |
| S-57 | A producer cannot accidentally mint the app-required revision by omitting an initializer argument | `HelperStatus.init` requires an explicit optional revision; both production constructors are explicit; the daemon advertises independent literal `implementedSafetyRevision = 1`; only test-target convenience supplies current-revision fixtures | A reviewer must still prove behavior before deliberately bumping the daemon literal | CHECKPOINT VERIFIED OFFLINE — BEHAVIOR REVIEW GATE OPEN |
| S-58 | Old same-protocol wire data fails closed without breaking decoding | Raw nested `HelperReply` JSON with no revision decodes it as `nil`; 0 and 2 remain mismatched; wrong-type data is rejected; a legacy decoder ignores the new key in current encoded status | No live XPC or mixed-installed-version exchange was executed | CHECKPOINT VERIFIED OFFLINE — LIVE MIXED-VERSION GATE OPEN |
| S-59 | Cached readiness cannot let an incompatible helper confirm a scheduled-wake mutation | `scheduleWake` requires both `reply.ok` and exact current reply status; related source-order checks pin the gate before accepted completion | Wake scheduling has no independent external readback and a timeout remains outcome-unknown | CHECKPOINT VERIFIED OFFLINE — PMSET/READBACK GATES OPEN |
| S-60 | An incompatible helper stays de-risking-reachable but cannot arm or complete removal | `.stale` remains reachable while `.isUsable` is false; exact-revision proof rejects its replies | No safe stale-helper replacement transaction exists; recovery/removal completion is intentionally unavailable | PARTIAL FAIL-CLOSED BOUNDARY — REPLACEMENT REQUIRED |
| V-36 | RED/GREEN evidence discriminates the same-version defect and wrapper bypasses | Initial regression produced 17 issues on the unsafe tree; hardened focused tests cover raw nested replies, direct and wrapper proof paths, producer declarations, scoped readiness, and wake reply gating | Source inspection cannot execute ServiceManagement or an installed old helper | PASS FOR OFFLINE POLICY — INTEGRATION GATE OPEN |
| V-37 | The complete preserved tree and exact selected tree pass deterministic tests | Working tree passed 274 tests in 26 suites; independently exported pre-ledger index passed 4 focused, 57 related, and all 267 exact tests in 25 suites | Working-tree-only seven-test suite is excluded authenticated remainder; exact tests do not compile App/helper/widget products | PASS — PRODUCT COMPILE SEPARATELY VERIFIED |
| V-38 | Exact selected product inputs pass strict static checks and unsigned Debug/Release compilation | Stable Xcode 26.5 built Core and strictly typechecked and directly linked 25 App, 4 helper, and 1 widget sources in Debug and optimized Release with Swift 6 complete concurrency, warnings-as-errors, signing disabled, and linker ad-hoc signing disabled | Project-native Xcode build/analyze was not retried under the established nested-sandbox and automatic LaunchServices side-effect constraint | PASS FOR EXACT OFFLINE SOURCES — XCODE GRAPH OPEN |
| V-39 | Artifact and configuration inspection remains bounded to observed facts | Six loose arm64 outputs target macOS 15 / SDK 26.5, contain no `LC_CODE_SIGNATURE`, and fail codesign inspection as unsigned; source plists, entitlements, project syntax/bindings, and shell syntax passed inspection | Loose outputs are not bundles and prove no embedded entitlement, signed XPC trust, registration, notarization, or runtime behavior | PARTIAL — BUNDLE/SIGNING/RUNTIME GATES OPEN |

- E-329 — 2026-08-06T04:14:26+0200 — Before modifying selected source,
  stable Xcode 26.5 Swift 6.3.2 passed the complete preserved package's 270
  tests in 25 suites (`swift-test-preserved-baseline-stable.log`, SHA-256
  `915d770d68235e91848cecf467b3d38252aec1fea3ab66c0518ecf626c961462`).
  A first Xcode-beta attempt failed on its forbidden module-cache path before
  manifest compilation and supplied no source verdict. Three independent
  read-only reviewers rejected the six-path remainder as a checkpoint and
  found the higher-risk same-version compatibility defect; none edited a file.
- E-330 — 2026-08-06T04:14:26+0200 — Historical inspection is preserved in
  `historical-same-version-helper-root-cause.log` (SHA-256
  `b67eedf643bfeeb9468d8ab1c7cfe8997c7ca0588f05b49a0ae5c07d4d00776b`).
  It proves ancestor commit
  `ff6ece4cefd8d312525e8abead7bc760db80eea1` declared protocol v6 without a
  safety revision, records its exact helper-source SHA-256
  `badfc5f6f07572fe4cc1755cfab369380511efae62d2cf6468a36a245fd5bcd9`,
  preserves the unsafe uninstall handler, and shows the pre-checkpoint app's
  version-only readiness branch.
- E-331 — 2026-08-06T04:14:26+0200 — The initial baseline-compatible
  regression produced 17 expected issues because missing/old/future
  same-protocol statuses could prove arm, restore, outside ownership, and
  removal and because production publication/readiness wiring was absent
  (`swift-test-helper-safety-revision-red.log`, SHA-256
  `2b1f22b1400fa991daf97071005d3b28a5c6335b1eabc84eb68f8a045641f01b`).
  Review then found two mutation gaps: an initializer default silently minted
  the current revision, and scheduled wake accepted `reply.ok` alone. The
  initializer is now required, daemon publication is producer-owned, and wake
  acceptance checks the returned revision. The final working focused suite
  passed 4 tests (`swift-test-helper-safety-revision-green3.log`, SHA-256
  `b45185045b3514bbde588e226a6232faca4be207c5afc919a5a2e3339a14f397`).
- E-332 — 2026-08-06T04:14:26+0200 — The first related rerun correctly caught
  two stale assertions that required the old `guard reply.ok else` source
  shape (`swift-test-helper-revision-related-green2.log`, SHA-256
  `eb12761c9ed8692631a885f573f384f6901bbede97992ac5314ca6746ba8d081`).
  After strengthening those existing regressions to require both operation
  success and exact reply revision, 57 related tests in 9 suites passed
  (`swift-test-helper-revision-related-green3.log`, SHA-256
  `21d589ffa5b41f4c97296ea920d454cb358886426b5f2caeb1bf30a76ab8281d`).
  The complete preserved working tree then passed 274 tests in 26 suites
  (`swift-test-helper-revision-full-working-tree.log`, SHA-256
  `d065f69c8a1617fd25dc1063fa4bbe43d286543eadeaaf8b6a4f4da243ff7d64`).
- E-333 — 2026-08-06T04:14:26+0200 — Curated exactly 12 pre-ledger paths.
  The independently exported pre-ledger index tree is
  `dec23ec7cc65efdff2a34dd82133b5e11235fdd6`; its complete binary-diff
  SHA-256 is
  `7483d29f852d182613e49975ade4c10a34c39c260ed2afa9660fd6cb9d3bdd08`.
  `git diff --cached --check` passed. The exact exported product-input digest
  across 57 Core/App/helper/widget source and configuration inputs is
  `c64fd4819f96f06d7fdeb974e5cd4dee067bda3defc1728f43d68899c5fad5c5`.
  No selected product or test byte changed after export; only this append-only
  ledger is added later.
- E-334 — 2026-08-06T04:14:26+0200 — The independently exported index passed
  all 4 focused tests (`swift-test-helper-safety-revision-focused-exact.log`,
  SHA-256
  `e9a37fba4e4634e00946bbcdd777f57b4f6356240157d6972c5c16a2a13618a4`),
  57 related tests in 9 suites
  (`swift-test-helper-revision-related-exact.log`, SHA-256
  `af091d81833e9b80fdbcf672fef61d5f19a7eae55938949523bedfaf145123a5`),
  and all 267 exact tests in 25 suites
  (`swift-test-helper-revision-full-exact.log`, SHA-256
  `50632a4e71c5c4ad066b3c987430c368fe165dc39abd9507d9716efe2e115106`).
  The exact suite excludes the authenticated untracked removal suite by
  construction; the working-tree pass in E-332 covers coexistence with it.
- E-335 — 2026-08-06T04:14:26+0200 — Exact Debug and Release `LidlessCore`
  builds passed (`swift-build-core-debug-exact.log`, SHA-256
  `15585d55ab15e937d6fc8ac27e5c8dd86af06abee6b2fb1bc70fb15d443d5c43`;
  `swift-build-core-release-exact.log`, SHA-256
  `603f997067bb66cfe27a034cb9eb9628df3afce5e29b7d6a6fea54a4892185df`).
  All 25 App, 4 helper, and 1 widget sources passed macOS 15 Swift 6
  complete-concurrency typechecking with warnings-as-errors
  (`swiftc-all-products-typecheck-helper-revision-exact.log`, SHA-256
  `954ebbd7a0a345493ab4e8753c9e7224a6568416c852f5167befc53a8fc34661`).
  With `CODE_SIGNING_ALLOWED=NO`, `CODE_SIGNING_REQUIRED=NO`, compiler sandbox
  disabling, and linker ad-hoc signing disabled, all exact sources compiled
  and linked in Debug
  (`direct-all-products-debug-helper-revision-exact.log`, SHA-256
  `01ea3dc644c8d9ab758d1925f2e11f1a7cbf669ab416f1b2d7a57aca3b2e23fd`)
  and optimized Release
  (`direct-all-products-release-helper-revision-exact.log`, SHA-256
  `570a95a850aef42e3dca6bc8ca80885f63bde862afc15f73379627a269ba7d5d`).
- E-336 — 2026-08-06T04:14:26+0200 —
  `artifact-inspection-helper-revision-exact.log` (SHA-256
  `c6ee483b62128b2eae8b586c3cafd1d9b2eebaf452ad7f99825b2b0cd47a14de`)
  records hashes, modes, arm64 file types, macOS 15 / SDK 26.5 build-version
  commands, absence of `LC_CODE_SIGNATURE`, and expected unsigned codesign
  results for all six loose Debug/Release outputs.
  `config-plist-entitlement-inspection-helper-revision-exact.log` (SHA-256
  `dd2272ac16323bac2e1c0b459e599dcbbefd08ecf5893d0b290861b49cc8000a`)
  preserves lint and decoded values for all App/helper/widget plist and
  entitlement sources, export options, project syntax and bindings, central
  identifiers/revisions, and shell syntax. No product was launched.
- E-337 — 2026-08-06T04:14:26+0200 — A lower-priority wake-ledger persistence
  defect was separately reproduced: uninstall cancels a wake without first
  durably removing its scheduled-wake record, so later cleanup failure or a
  crash can make restart retry stale intent. Initial RED/candidate-GREEN logs
  are preserved at SHA-256
  `a02ad78fd4581dd0aeb69734d98f2ef5691cc567bf34789f42952277a6e74b60`
  and `11ab8152b0f8933ade6929b4f71ec13826d228d73a2d9e9d294c436c0c47ec84`;
  the hardened exact-HEAD RED is
  `f32ac6050936ff8e5d6bed0569f913c70c84a87e1f4ec5b663ef3164f6a4d406`.
  Its candidate code and test edits were fully reverted before this checkpoint
  and are neither staged nor claimed. The defect remains a separate root-cause
  group.
- E-338 — 2026-08-06T04:14:26+0200 — Independent compatibility, production,
  and adversarial-test reviews found no bypass in the final narrow revision
  predicate after the explicit-constructor and wake-reply corrections. They
  unanimously retained the stale-helper replacement deadlock and self-reported
  metadata boundary. Other open root-cause groups are an XPC request that can
  wait forever for no reply, partial/quiet failure restoring optional managed
  low-power and TCP-keepalive settings, wake-ledger persistence, and
  point-in-time/non-atomic filesystem, registry, and ServiceManagement handoff
  evidence. No reviewer edited a file.
- E-339 — 2026-08-06T04:14:26+0200 — Main-checkout preservation passed after
  tests and builds in
  `main-preservation-helper-revision-precommit.log` (SHA-256
  `fb033fe3213cf32347d167cbc435582072a78ff38f914877f73045e7ffbea663`):
  canonical paths, exact two-worktree topology and common directory, main
  branch/starting HEAD, clean index and tracked diff, all three exact
  `.playwright-mcp` records, NUL-status digest
  `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`,
  and empty tracked binary-diff digest matched the rolling authority.
- E-340 — 2026-08-06T04:14:26+0200 — No App/helper/widget process, helper
  install/activation/registration/approval/unregister, live XPC, `pmset`,
  sleep-setting mutation, sleep/wake, hardware, authentication, credential,
  plugin/provider/connector, Figma, network publication, release, notarization,
  merge, push, deploy, or main-checkout mutation was performed. Project-native
  Xcode build/analyze was not retried after the established nested-sandbox
  failure and automatic LaunchServices side-effect constraint. The checkpoint
  is prepared under subject `safety: require exact helper behavior revision`;
  `State: IN_PROGRESS` is intentionally retained. After this one local commit,
  the supervisor must bind the exact remaining six-path tree into a fresh
  rolling manifest before another invocation.
- E-341 — 2026-08-06T04:16:33+0200 — Reviewed the complete 13-path staged
  patch. `final-staged-review-helper-revision-pre-terminal.log` (SHA-256
  `9b8c20dff0d701aea77c051d85e9c981946a327d5721a937ecddb58aa447ea59`)
  records the full diff, sole top-level `State: IN_PROGRESS`, 222-addition
  ledger append, exact curated path set, pre-terminal index tree
  `4123fd1aa09ba56db29bbf9c0752b94f23a349b0`, and full staged binary-diff
  SHA-256
  `531ac75ff9106bae7113641b7346c5653dd41167ca4d37b2e06532137f691478`.
  It independently compares every one of the 12 selected code, test, and
  architecture/contributor-document index blobs byte-for-byte with the tested
  export; all match. Both staged and complete working-tree whitespace checks
  pass, and the only unstaged/untracked paths are the six authenticated
  remainder paths. Only this terminal evidence entry is appended afterward;
  no selected product or test byte and no accepted verification result changed.

## Twenty-third invocation — authenticated recovery

- E-342 — 2026-08-06T04:21:56+0200 — Read the canonical handoff,
  immutable starting-state manifest, rolling remainder manifest and adjacent
  sidecar, progress log, decision log, architecture, design-reset brief, and
  this complete append-only ledger before editing. The handoff and immutable
  manifest matched their supplied SHA-256 values. The sidecar and independently
  calculated rolling-manifest SHA-256 both equal
  `c36079aa07a4f4fb0c99fc55855c74f56cf81033ee709f16fe5b7233ff9a082b`.
  A recursive hidden-file scan found no repository-local `AGENTS.md`,
  `CLAUDE.md`, `CODEX.md`, `.cursorrules`, or equivalent instruction file.
  The required top-level `State: IN_PROGRESS`, branch, and starting HEAD were
  already exact and remain unchanged.
- E-343 — 2026-08-06T04:21:56+0200 — Applied only the authenticated rolling
  manifest as recovery authority. The feature canonical path, exact
  two-worktree linked topology, branch, HEAD
  `ac50a0542fb65aebc5ef4f9734e660fac35e1777`, linked Git admin/common
  directories, clean index, empty unmerged list, complete six-path dirty
  inventory, every recorded status/type/mode/size/raw SHA-256, NUL-status
  digest `5cf63a070dfe49313ecf75b3b2b7c3995af41ba5f22a8c4c39523108c7863b09`,
  and tracked binary-diff digest
  `9246b662e27202b4da57f7adb476aae9ab0133cae5176c50d3a8a115cc34ea6f`
  matched exactly before this append. Starting HEAD
  `7f17aaca11bc6228bed48b9265d63b9e576cdea7` remains an ancestor. The
  historical manifest was not applied to this post-checkpoint state.
- E-344 — 2026-08-06T04:21:56+0200 — Independently reverified the main
  checkout without editing it: canonical path and linked topology, `main` at
  starting HEAD, clean index, empty unmerged list and tracked diff, complete
  three-path `.playwright-mcp` inventory, every recorded
  status/type/mode/size/raw SHA-256, NUL-status digest
  `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`,
  and empty tracked binary-diff digest
  `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`
  matched exactly. Recovery passed before the first edit; the main checkout
  remains untouched.

### Twenty-third finding and verification matrix

| ID | Finding or invariant | Independent evidence and disposition | Verdict |
|---|---|---|---|
| T23-01 | The authenticated six-path remainder is not a coherent checkpoint | Independent code review found two unused, misleading removal wrappers and weaker duplicate tests; independent documentation review found stale/unsupported progress claims and founder-gated design material. All six paths remain byte-for-byte unchanged and excluded from the index. | PRESERVED / EXCLUDED |
| T23-02 | `HelperClient.call` could wait forever when XPC delivered neither its error handler nor reply | The old source had only reply/error branches around a checked continuation. A compile-time RED required the absent finite completion policy. The repair adds a 25 s deadline and lock-protected reply/transport/timeout gate. | FIXED OFFLINE |
| T23-03 | Timeout and XPC loss callbacks could race, reuse an interrupted connection, or let an old callback clear a newer connection | Interruption, invalidation, and timeout retirement now converge on one MainActor path that unconditionally invalidates the exact lost connection, then identity-guards cached clearing and proof-loss notification. Focused source ordering and 300-way concurrent gate tests pass. | FIXED OFFLINE |
| T23-04 | A local timeout cannot cancel an already delivered helper mutation or prove its outcome | Error text and architecture explicitly preserve outcome uncertainty; callers retain their committed generation/removal fences and proof-loss recovery. No remote cancellation or outcome claim is made. | OPEN BY DESIGN / FAIL CLOSED |
| T23-05 | Exact selected bytes must pass deterministic and strict compile evidence without the preserved remainder | Exported index tree `b73777bc37a5276b62d5ace0e86acaa2d1a1ee89` passed 4 focused, 43 related, and all 271 exact tests, Debug/Release Core builds, strict all-product typechecking, and unsigned Debug/Release direct links. | PASS OFFLINE |
| T23-06 | Runtime callback order, helper restoration, signing trust, sleep/wake, and hardware behavior remain outside offline proof | No product was launched and no live XPC, ServiceManagement, power, signing, or hardware action was performed. Direct outputs are intentionally unsigned loose executables. | HARDWARE / SIGNED-RUNTIME GATES OPEN |

### Twenty-third append-only evidence log

- E-345 — 2026-08-06T04:42:41+0200 — Reviewed the complete preserved diff
  against HEAD before accepting any byte. The stable Xcode 26.5 Swift 6.3.2
  baseline passed all 274 then-present working-tree tests in 26 suites
  (`swift-test-preserved-baseline.log`, SHA-256
  `11f48648207615ba600e1efc5cd587cfcbb2c83cfb401f8572efd0de29d29897`).
  Independent code and documentation audits rejected every authenticated
  remainder hunk as a checkpoint: the removal additions are unused or lossy
  duplicates, their aggregate tests are weaker than committed dedicated
  suites, the smoke additions are duplicate/shallow, and the progress/design
  documents contain stale, unsupported, or founder-gated material. A separate
  root-cause comparison selected the app-only unbounded XPC await as the
  narrowest high-value group. Reviewers made no source or index edit.
- E-346 — 2026-08-06T04:42:41+0200 — Established a hardened compile-time RED
  before the finite policy existed. The focused regression required the absent
  `HelperXPCRequestSafety` type and failed compilation
  (`swift-test-xpc-timeout-hardened-red.log`, SHA-256
  `10fa967cf7746e10569be41376fd902d7abbde9bc3f11d169ac42371a2b9aa38`).
  The inspected old client scheduled no deadline: only its XPC error handler
  and reply could claim `ResumeOnce`, so silence left the continuation
  suspended without a local bound. An earlier smaller RED is preserved but
  superseded by this hardened regression.
- E-347 — 2026-08-06T04:42:41+0200 — Added a process-local three-outcome
  completion gate and 25 s policy, scheduled the deadline before proxy lookup
  or remote dispatch, and converted timeout into an explicit outcome-unknown
  error. Adversarial review then found NSXPC's callback order is unspecified
  and interruption can reconnect: both handlers and timeout retirement now
  unconditionally invalidate their exact captured connection before an
  identity guard, clear only the current cache, and immediately revoke current
  app proof exactly once. Preliminary GREEN attempts with stale or overly
  indentation-sensitive source-test boundaries were rejected and preserved
  (`swift-test-xpc-timeout-green.log`, SHA-256
  `dac0693e3a4fafdddceb7e974dd55590f6723caaccf187df39ff6983867b9018`;
  stable hardening log SHA-256
  `96619b236f7aac383f1fbd8e4bd6df84738eea4d32392ed76434d188e8889a9a`).
  Neither supplies the accepted verdict.
- E-348 — 2026-08-06T04:42:41+0200 — Final working-tree verification passed
  all 4 focused tests (`swift-test-xpc-timeout-green-stable-final2.log`,
  SHA-256
  `125a67c0e4151d436efaec3831fa6e5bdcb1975c136811084536559de17e3b63`),
  43 related tests across arm-proof loss, wake reconciliation, launch
  reconciliation, removal fencing, and non-sleep restore
  (`swift-test-xpc-timeout-related-working.log`, SHA-256
  `57109895c62c45466364c84bd02b9d7ac69e889f628f90e185d616da0837219f`),
  and all 278 tests in 27 suites including the authenticated remainder
  (`swift-test-full-working-xpc-final.log`, SHA-256
  `431f531a4dda564c7f6cda50363813815bf808fa48c8fdf75bbcc7f18021f7c1`).
- E-349 — 2026-08-06T04:42:41+0200 — Curated exactly five paths: architecture,
  `HelperClient`, the new Core completion policy, its focused regression, and
  this ledger. Before the final ledger append, `git diff --cached --check`
  passed; index tree `b73777bc37a5276b62d5ace0e86acaa2d1a1ee89` had staged binary-diff SHA-256
  `2bb7789157e5cd5195caee32a165d4f18159b22b93192e495329a28c8c5f7ea0`.
  Its independently exported 106-path source/test/config input manifest has
  SHA-256
  `4f811e2a44fbe9653c4e17b95e0ec8c4fc68d0b8498d59e6526194de585463aa`.
  Only append-only ledger bytes change after this tested export; final review
  must compare every selected non-ledger blob with this tree.
- E-350 — 2026-08-06T04:42:41+0200 — The independently exported index passed
  4 focused tests (`swift-test-xpc-timeout-focused-exact.log`, SHA-256
  `786308c4397a946103f52ba18b3558f11ab2b4933f86f0cc7059d597db7519fa`),
  43 related tests in 6 suites
  (`swift-test-xpc-timeout-related-exact.log`, SHA-256
  `115ede466754fcb15f6c7b2a2e5bb13937f5c28b69d4d5a6c5d3aa2cd7691198`),
  and all 271 exact tests in 26 suites
  (`swift-test-xpc-timeout-full-exact.log`, SHA-256
  `e38ae3942cdce9b45b57db291a1962c08c2bc4a8e3fd9bb1e6b2b69b2ee028d5`).
  The exact suite excludes the authenticated seven-test remainder suite by
  construction; E-348 proves coexistence in the complete working tree.
- E-351 — 2026-08-06T04:42:41+0200 — Exact Debug and Release `LidlessCore`
  builds passed with signing disabled (`swift-build-core-debug-xpc-timeout-exact.log`,
  SHA-256
  `4e26878561de37b925a9cc3f2ed4c2da04d597bff79ae257978cb3214856fb50`;
  Release SHA-256
  `4aed7a58094ba0246e6b2cefe06a737b7483cfd74f67e3d06ad7458f11ffafa7`).
  All 25 App, 4 helper, and 1 widget sources passed macOS 15 Swift 6 complete
  strict-concurrency typechecking with warnings-as-errors
  (`swiftc-all-products-typecheck-xpc-timeout-exact.log`, SHA-256
  `38a72eb68c6fa9a0e1c8477e10cd426c48dd05f1b28cfdde22749b96d3d2bf9e`).
  With `CODE_SIGNING_ALLOWED=NO`, `CODE_SIGNING_REQUIRED=NO`, compiler sandbox
  disabling, and linker ad-hoc signing disabled, every exact product source
  set compiled and linked in Debug
  (`direct-all-products-debug-xpc-timeout-exact.log`, SHA-256
  `15e81d1d4373d653b1020e9699ac3ac32479c2c86fb648a380197c18dc6b8d9d`)
  and optimized Release (SHA-256
  `63c7f29d85809b305aea59778dd09e22c27f4010223b46009dc60d68a7ef72de`).
- E-352 — 2026-08-06T04:42:41+0200 —
  `artifact-inspection-xpc-timeout-exact.log` (SHA-256
  `268e5392fb761320072359368a40e4417be819f01b53e92b661015c89db571e9`)
  records modes, sizes, hashes, thin arm64 file types, macOS 15 / SDK 26.5
  build-version commands, absence of `LC_CODE_SIGNATURE`, and expected
  unsigned codesign verdicts for all six loose Debug/Release outputs.
  `config-plist-entitlement-inspection-xpc-timeout-exact.log` (SHA-256
  `e493e78cae6ac71994c60c6f1d86cf408d7513e4e9df077583b94578377110ce`)
  preserves lint and decoded App/helper/widget plist and entitlement sources,
  export options, generated-project syntax, identifiers, timeout constants,
  project bindings, and release-script syntax. These are not built bundles or
  signed-runtime trust evidence.
- E-353 — 2026-08-06T04:42:41+0200 — Final independent adversarial review
  returned PASS with no concrete blocker. It verified captured-connection
  invalidation before identity testing, stale/new connection isolation,
  exactly-once current proof-loss notification under MainActor serialization,
  timer-before-dispatch, all gate/resume pairings, catch/retire/rethrow order,
  10 + 25 < 45 timing, and the bounded architecture wording. It separately
  passed strict App typechecking. The reviewer made no source or index edit;
  real NSXPC callback ordering and helper outcome remain unproved.
- E-354 — 2026-08-06T04:42:41+0200 — Reverified the feature remainder and main
  checkout after tests/builds in
  `main-and-remainder-preservation-xpc-timeout-precommit.log` (SHA-256
  `eb6ed77489357cf6053a7c0a7584779190be2347c86c3b84e2a9598641d36693`).
  The exact two-worktree topology, feature branch/precommit HEAD/common Git
  directory, empty unmerged list, all six remainder modes/sizes/raw hashes,
  and remainder tracked binary-diff SHA-256
  `9246b662e27202b4da57f7adb476aae9ab0133cae5176c50d3a8a115cc34ea6f`
  match the rolling authority. The main remains `main` at starting HEAD with a
  clean index/tracked diff, exact three-path `.playwright-mcp` inventory,
  status SHA-256
  `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`,
  and empty tracked binary-diff SHA-256.
- E-355 — 2026-08-06T04:42:41+0200 — No App/helper/widget process, helper
  install/activation/registration/approval/unregister, live XPC, `pmset`,
  sleep-setting mutation, sleep/wake, hardware, authentication, credential,
  plugin/provider/connector, Figma, network publication, release,
  notarization, merge, push, deploy, or main-checkout mutation was performed.
  Project-native Xcode build/analyze was not retried after the established
  nested-sandbox failure and automatic LaunchServices side-effect constraint;
  strict compiler analysis and direct unsigned builds are the bounded static
  evidence. Remote cancellation/outcome proof, signed XPC trust, real
  watchdog/connection restoration, stale-helper replacement, wake-ledger
  persistence, optional managed-setting restoration, registry atomicity, and
  hardware behavior remain open gates.
- E-356 — 2026-08-06T04:42:41+0200 — The coherent checkpoint is prepared under
  subject `safety: bound helper XPC requests`. `State: IN_PROGRESS` is
  intentionally retained because the authenticated six-path remainder and
  other root-cause/hardware gates remain. After exactly one local commit, the
  supervisor must bind the exact remaining tree into a fresh rolling manifest
  before another invocation.
- E-357 — 2026-08-06T04:44:05+0200 — Reviewed the complete five-path staged
  patch. `final-staged-review-xpc-timeout.log` (SHA-256
  `c58a64dfbbfa14e20bcc9c25065bdf5fc25976fd83b141193fead0de3e8fb377`)
  records the full staged diff, sole top-level `State: IN_PROGRESS`, exact
  selected and remainder path sets, pre-terminal index tree
  `5f0f69145c1081d2cccd1a3899308b0a2ed6add4`, and pre-terminal staged
  binary-diff SHA-256
  `6bc98b2009cd7600f457966f6b130cf453d8b710fa7fd6ccbe50cab44ddad39a`.
  Every selected non-ledger index blob matches the independently tested tree
  byte-for-byte. Both staged and complete working-tree whitespace checks pass,
  and the only unstaged/untracked paths are the six authenticated remainder
  paths. Only this terminal evidence entry is appended afterward; no selected
  product or test byte and no accepted verification result changed.

## Twenty-fourth invocation — authenticated recovery

- E-358 — 2026-08-06T04:49:44+0200 — Read the canonical handoff, immutable
  starting-state manifest, rolling remainder manifest and its adjacent
  sidecar, current progress and decision logs, architecture, design-reset
  brief, and this complete append-only ledger before editing. The handoff and
  immutable manifest matched their supplied SHA-256 values. The sidecar and
  independently calculated rolling-manifest SHA-256 both equal
  `bc5ef7e97430b7c6d9d087eeea6e85925ccdc357a16f2a818c0cccf644dbcd24`.
  A recursive hidden-file scan found no repository-local `AGENTS.md`,
  `CLAUDE.md`, `CODEX.md`, `GEMINI.md`, `.cursorrules`,
  `copilot-instructions.md`, or matching instruction file. Before this append,
  the ledger SHA-256 was
  `ba8fff59efd4253be46933afe45fbb1849aee29d853c776a08bf20197fc6c02a`;
  its required top-level `State: IN_PROGRESS`, branch, and starting HEAD were
  already exact.
- E-359 — 2026-08-06T04:49:44+0200 — Applied only the authenticated rolling
  manifest as recovery authority. The feature canonical path, exact
  two-worktree linked topology, branch, HEAD
  `3221b3ffa4a3f4aa6f8e7f26da876d2c03b50542`, linked Git admin/common
  directories, clean index, empty unmerged list, complete six-path dirty
  inventory, and every recorded status/type/mode/size/raw SHA-256 matched
  exactly with no extra or missing path. The NUL-delimited complete-status
  digest was
  `5cf63a070dfe49313ecf75b3b2b7c3995af41ba5f22a8c4c39523108c7863b09`
  and the tracked binary-diff digest was
  `9246b662e27202b4da57f7adb476aae9ab0133cae5176c50d3a8a115cc34ea6f`.
  Starting HEAD `7f17aaca11bc6228bed48b9265d63b9e576cdea7` remains an ancestor. The
  historical manifest was not applied to this post-checkpoint state; recovery
  passed before this first edit.
- E-360 — 2026-08-06T04:49:44+0200 — Independently reverified the main
  checkout without editing it: canonical path and linked topology, `main` at
  starting HEAD, clean index, empty unmerged list and tracked diff, complete
  three-path `.playwright-mcp` inventory, and every recorded
  status/type/mode/size/raw SHA-256 matched exactly. Its NUL-status digest was
  `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`
  and its tracked binary-diff digest was
  `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.
  The main checkout remains untouched.
- E-361 — 2026-08-06T04:58:07+0200 — A separate read-only recovery audit
  independently reproduced the rolling-manifest sidecar, feature and main
  canonical paths/topology/branches/HEADs, clean indexes, empty unmerged
  inventories, complete dirty path metadata and bytes, both NUL-status
  digests, and both tracked binary-diff digests with no mismatch. The reviewer
  made no file or index edit.
- E-362 — 2026-08-06T04:58:07+0200 — Preserved a complete current-tree
  baseline in
  `build/verification-2026-08-06-twenty-fourth/swift-test-preserved-baseline.log`
  (714 lines; SHA-256
  `6515604dc78bca3ba69434209d5f37e22758cf99992e6d654663965b7260923a`).
  Under Xcode 26.5 / Swift 6.3.2 with an isolated scratch/cache and no product
  launch, `swift test --package-path Packages/LidlessCore --disable-sandbox`
  passed all 278 tests in 27 suites. This includes the six authenticated
  remainder paths and therefore establishes behavior only; it does not accept
  those paths as implementation authority.
- E-363 — 2026-08-06T04:58:07+0200 — Two independent read-only code reviews
  rejected the authenticated six-path remainder as a checkpoint: its new
  helper-removal Boolean wrappers are unused duplicates that erase richer
  admission/action semantics; its tests largely exercise those dead APIs or
  duplicate committed coverage; and its progress/design text is stale or
  outside this safety invocation. The selected bounded root cause instead is
  optional managed-setting restoration: `performRestore` currently deletes
  the recovery sentinel after ignoring Low Power Mode / `tcpkeepalive`
  failures, while `PMSet.restore` suppresses a partial failure and arming uses
  `-a` even when only a subset of per-source priors was captured. Strict
  per-source planning, all-command failure propagation, fresh custom readback,
  exact restoration proof, and a helper safety-revision bump are one coherent
  offline checkpoint. Wake-ledger atomicity and safe stale-helper replacement
  remain separate open gates.
- E-364 — 2026-08-06T04:58:07+0200 — Added the focused managed-setting
  policy/source-order regression before production changes. The expected RED
  failed at compile time because `ManagedSettingRestorationSafety` did not
  exist; the complete 865-line output is preserved at
  `build/verification-2026-08-06-twenty-fourth/swift-test-managed-settings-red.log`
  (SHA-256
  `141538d113f79333c94a485b9d6ba61e8d1757d21c3ec4107a390c80a82677c6`).
  The regression specifies supported per-source snapshots, rejection of
  invalid/unrestorable sentinels, deterministic grouped activation/restore
  plans, exact fresh readback proof, no-readback success only when there are
  no managed priors, and proof-before-sentinel-removal source ordering.

### Twenty-fourth finding and verification matrix

| ID | Finding or invariant | Independent evidence and disposition | Verdict |
|---|---|---|---|
| T24-01 | The authenticated six-path remainder is not a coherent safety checkpoint | Two read-only reviews found unused/lossy removal wrappers, duplicative tests, stale progress text, and out-of-scope founder-gated design material. Every remainder status, mode, size, and raw hash remains exact and unstaged. | PRESERVED / EXCLUDED |
| T24-02 | Optional `pmset` activation previously used `-a` after capturing only whichever per-source priors happened to parse | Schema-v2 policy now captures numeric Battery/AC/UPS priors only, builds deterministic grouped `-b`/`-c`/`-u` plans, and touches no unrecorded scope. Any per-scope command failure propagates. | FIXED OFFLINE |
| T24-03 | Restore previously ignored partial LPM/`tcpkeepalive` failure and deleted the recovery sentinel without proving those values | Restore now proves normal sleep, validates and applies every scoped prior, obtains a fresh `pmset -g custom` readback, requires exact values, and only then removes the sentinel. Every failure parks the record and schedules retry. | FIXED OFFLINE |
| T24-04 | Legacy optional or corrupt sentinel evidence cannot prove which scopes old `-a` activation mutated | Schema v2 is required for optional restoration. Plain schema v1 can restore sleep only; v1 with optional state, future versions, and the explicit version-0 corrupt fallback retain recovery evidence instead of claiming completion. | FAIL CLOSED |
| T24-05 | New behavior must not be accepted from an older installed helper, and bounded-wait wording must not imply a real-time guarantee | App-required and helper-produced safety revisions are both 2. Tests reject missing, 0, 1, and 3. Source and architecture distinguish finite child-wait budgets from unbounded process launch, filesystem, IOKit, and earlier queue work. | FIXED OFFLINE / RUNTIME GATE OPEN |
| T24-06 | Exact selected bytes must pass independently of the preserved remainder | Exported index tree `1dba5d53509e42c545c4e6d039324096a490316a` passed 7 focused, 21 related, and all 279 exact tests, both Core configurations, strict all-product typechecking, and unsigned Debug/Release direct links. | PASS OFFLINE |
| T24-07 | Offline tests and loose unsigned executables cannot establish real power-setting restoration, XPC trust, launchd behavior, or hardware safety | No product or helper was launched and no live service, XPC, `pmset`, sleep, signing, or hardware action occurred. The inspected outputs have no code-signature load command and no entitlements. | SIGNED-RUNTIME / HARDWARE GATES OPEN |

### Twenty-fourth append-only evidence log (continued)

- E-365 — 2026-08-06T05:21:44+0200 — Implemented the bounded managed-setting
  root-cause group. `ManagedSettingRestorationSafety` accepts only the current
  schema, supported keys, supported power scopes, nonempty numeric prior maps,
  and internally consistent LPM key/prior pairs. It deterministically groups
  activation or restoration settings into at most three scope commands.
  `PMSet.apply` is fail-fast with no swallowed partial failure. Fresh arms
  persist all possibly touched priors before optional application; restore
  proves sleep, applies every managed prior, obtains a fresh custom snapshot,
  proves every exact value, and removes the sentinel only afterward. All
  failure paths converge on `parkRestore`, retain recovery ownership, and
  schedule retry. Sentinel schema and the independently produced/required
  helper safety revision advance to 2.
- E-366 — 2026-08-06T05:21:44+0200 — The first complete working-tree GREEN
  attempt exposed one stale lexical test that counted six literal
  `scheduleRestoreRetry()` call sites after retry parking was centralized; all
  production behavior had passed, but the complete run correctly remained
  rejected (`swift-test-full-managed-settings.log`, 734 lines, SHA-256
  `9adddb1bb68f3d678c3951a59d66644f203835aa937c1ea599602ed6fb3f4424`).
  The test now asserts the semantic invariant inside `parkRestore`: it stores
  `restorePending = record` before calling `scheduleRestoreRetry()`. The final
  literal command `swift test --package-path Packages/LidlessCore
  --disable-sandbox` passed all 286 tests in 28 suites, including the seven
  excluded remainder tests
  (`swift-test-full-working-managed-settings-terminal.log`, 733 lines,
  SHA-256
  `7d90a2cbd5608111cc2f953edac22a77431665aedfd884dc98c4feb2f8053195`).
- E-367 — 2026-08-06T05:21:44+0200 — Independent adversarial review found and
  closed three checkpoint hazards: a schema-v1 optional sentinel could not
  inherit v2 scoped semantics; a synthetic corrupt fallback must be explicit
  version 0 rather than accidentally defaulting to the current schema; and
  child wait budgets must not be described as whole-command or queue
  real-time bounds. A production-wiring regression pins version 0 before the
  corrupt recovery call, and source/architecture wording now states the
  remaining unbounded work. The final reviewer verdict found no remaining
  concrete production-semantic defect and made no source or index edit.
- E-368 — 2026-08-06T05:21:44+0200 — Curated exactly 11 paths: architecture,
  this ledger, helper daemon and `PMSet`, sentinel/revision Core sources, the
  new pure policy, three adjusted safety suites, and its new focused suite.
  The six authenticated remainder paths are not staged. Before these
  continued ledger entries, `git diff --cached --check` passed; exported index
  tree `1dba5d53509e42c545c4e6d039324096a490316a` had staged binary-diff SHA-256
  `74f09fb871c193e991f5c7a2bd73315e0d8c1bf41d094935bff234c155308751`.
  Its 130-file raw input manifest has SHA-256
  `e1ffacf0f9771fff63c313f45782799cf24d1861dbe2dfcf4093d6c8ef305202`.
  Only append-only ledger bytes change after this tested export; terminal
  review must prove every selected non-ledger blob still matches that tree.
- E-369 — 2026-08-06T05:21:44+0200 — The exact exported tree passed all 7
  managed-setting focused tests
  (`swift-test-managed-settings-focused-exact-terminal.log`, SHA-256
  `dba1a0dbb6a16fedd392cef5a3078ef5f4018850324dfcb6a9d838682ccfb32c`),
  21 related tests across managed restoration, helper revision, supervision
  timing, and termination
  (`swift-test-managed-settings-related-exact-terminal.log`, SHA-256
  `68ac71b5722652f51762821913f770d21110549cb5f16b93196d6e17ecdae67a`),
  and all 279 exact tests in 27 suites
  (`swift-test-managed-settings-full-exact-terminal.log`, SHA-256
  `22d5ccff0bed3955ff820429625a814c3a2ca57a13f706b4f69694615737eee6`).
  The exact suite excludes the authenticated seven-test remainder suite by
  construction; E-366 proves coexistence in the complete working tree.
- E-370 — 2026-08-06T05:21:44+0200 — Under Xcode 26.5 / Swift 6.3.2, exact
  Debug and Release `LidlessCore` builds passed with signing disabled
  (`swift-build-core-debug-managed-settings-exact-terminal.log`, SHA-256
  `6202705e9a8856108834699b3065c873773d02f3567f28af16e7a99b05155e40`;
  Release SHA-256
  `a215a4781e9b5e9aad8390c8b3ae562b9f16c1a0bb3eaa4db1ff7beb1a8b6bcd`).
  All 25 App, 4 helper, and 1 widget sources passed macOS 15 Swift 6 complete
  strict-concurrency typechecking with warnings-as-errors
  (`swiftc-all-products-typecheck-managed-settings-exact-terminal.log`,
  SHA-256
  `07c19f344db52ba496f8d91ed4561bf924f2e5e845323f44dfb86243e64a6c96`).
  With `CODE_SIGNING_ALLOWED=NO`, `CODE_SIGNING_REQUIRED=NO`, compiler sandbox
  disabling, and linker ad-hoc signing disabled, every exact product source
  set and all 28 Core objects linked in Debug
  (`direct-all-products-debug-managed-settings-exact-terminal.log`, SHA-256
  `388fef882533cdbc4496c3093e95c578a85a0f8e19969f6d65f6a274522e961c`)
  and optimized Release (SHA-256
  `37e7ad30d3776a2aa2b5021f74a924af98747ff783fc6831bac0911c667ca044`).
  The exact toolchain record has SHA-256
  `655f4ec210446d6e1a204891e89ef7f2f3c3d41d981d806297c31509a7f1b28b`.
- E-371 — 2026-08-06T05:21:44+0200 —
  `artifact-inspection-managed-settings-exact-terminal.log` (108 lines,
  SHA-256
  `d2fea4a3e02899d9200ca3ce7e77b27a1bd9de65fae5cbb84be28f1cc8821933`)
  records modes, sizes, hashes, thin arm64 file types, macOS 15 / SDK 26.5
  build-version commands, absence of `LC_CODE_SIGNATURE`, and expected
  unsigned codesign verdicts for all six loose Debug/Release outputs.
  `config-plist-entitlement-inspection-managed-settings-exact-terminal.log`
  (220 lines, SHA-256
  `746ba5852844e266989a8dbfcb76d9f8cf8bbbceaaa8f56dc66cfee321fd09dc`)
  preserves lint and decoded App/helper/widget plist and entitlement sources,
  project bindings, exact schema/revision constants, scoped policy wiring,
  and the local `pmset(1)` description of `-b`/`-c`/`-u` versus `-a`. These
  are loose executables and source configurations, not built bundles, signed
  identity, embedded-entitlement, XPC, or runtime trust evidence.
- E-372 — 2026-08-06T05:21:44+0200 — Reverified the feature remainder and main
  checkout after all tests/builds in
  `main-and-remainder-preservation-managed-settings-precommit.log` (46 lines,
  SHA-256
  `dbe8eaabf5c75e0ed6c102db11f3c3cf50bc0926e016cf4ad28d4d3c6c0608e2`).
  The exact two-worktree topology, feature branch/precommit HEAD/common Git
  directory, empty unmerged list, all six remainder statuses/modes/sizes/raw
  hashes, NUL-status SHA-256
  `5cf63a070dfe49313ecf75b3b2b7c3995af41ba5f22a8c4c39523108c7863b09`,
  and remainder tracked binary-diff SHA-256
  `9246b662e27202b4da57f7adb476aae9ab0133cae5176c50d3a8a115cc34ea6f`
  match the rolling authority. The main remains `main` at starting HEAD with a
  clean index/tracked diff, exact three-path `.playwright-mcp` inventory,
  status SHA-256
  `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`,
  and empty tracked binary-diff SHA-256.
- E-373 — 2026-08-06T05:21:44+0200 — Both staged and tracked-unstaged
  `git diff --check` passed; separate `--no-index --check` checks found no
  whitespace error in either untracked remainder file. No App/helper/widget
  process, helper install/activation/registration/approval/unregister, live
  XPC, mutating `pmset`, sleep-setting change, sleep/wake, hardware,
  authentication, credential, plugin/provider/connector, Figma, network
  publication, release, notarization, merge, push, deploy, or main-checkout
  mutation was performed. Project-native Xcode build/analyze was not retried
  after the established nested-sandbox failure and automatic LaunchServices
  side-effect constraint; strict compiler analysis and direct unsigned builds
  are the bounded static evidence. Real per-source mutation/readback, old-v1
  optional recovery, signed XPC trust, SMAppService lifecycle, process-launch
  timing, crash/restart, sleep/wake, closed-lid behavior, stale-helper safe
  replacement, wake-ledger persistence, registry atomicity, notarization, and
  release readiness remain open gates.
- E-374 — 2026-08-06T05:21:44+0200 — The coherent checkpoint is prepared under
  subject `safety: prove managed pmset restoration`. `State: IN_PROGRESS` is
  intentionally retained because the authenticated six-path remainder and
  separate safety/runtime/hardware gates remain. After exactly one local
  commit, the supervisor must bind the exact remaining tree into a fresh
  rolling manifest before another invocation.
- E-375 — 2026-08-06T05:24:07+0200 — Reviewed the complete 11-path staged
  patch. `final-staged-review-managed-settings.log` (1,471 lines, SHA-256
  `efddf014fcbcdcefe98c36b0759754b1989629123573f78f70a065c05260e96c`)
  records the full staged binary patch, sole top-level `State: IN_PROGRESS`,
  exact selected/remainder path sets, pre-terminal index tree
  `abdd2086661e76c9c5265444a4c9c7487608061e`, and pre-terminal staged
  binary-diff SHA-256
  `2ac04ca67373e85e9d209849820e1788cd2b9dcbd9bc58808611b679254f11a6`.
  Every selected non-ledger index blob matches tested tree
  `1dba5d53509e42c545c4e6d039324096a490316a` byte-for-byte. Both staged and
  complete tracked working-tree whitespace checks pass, and the only
  unstaged/untracked paths are the six authenticated remainder paths. Only
  this terminal evidence entry is appended afterward; no selected product or
  test byte and no accepted verification result changed.
- E-376 — 2026-08-06T05:27:17+0200 — Began the twenty-fifth recovery from the
  authenticated rolling remainder manifest, whose adjacent sidecar exactly
  matches manifest SHA-256
  `c7cbe860130078a4e07024d3eec195819b4af00af4bacecebbe0814ce2a681ea`.
  The canonical handoff and immutable historical manifest independently match
  their supplied SHA-256 values. The rolling manifest is the sole state
  authority because feature HEAD has advanced beyond starting HEAD. Before
  this first edit, the ledger SHA-256 was
  `1d1679510805ed8ffa785b337af7a24bb2f8017b3688f628a6b49456770543f2`;
  its required top-level `State: IN_PROGRESS`, branch, and starting HEAD were
  already exact. The handoff, both manifests, sidecar, progress log, decision
  log, architecture, and design-reset brief were read in full. A tracked and
  untracked repository-file scan found no `AGENTS.md`, `CLAUDE.md`, `CODEX.md`,
  or `INSTRUCTIONS.md`.
- E-377 — 2026-08-06T05:27:17+0200 — The pre-edit recovery audit reproduced
  the exact feature canonical path, two-worktree linked topology, branch, HEAD
  `a841913bf7d6f5779bac92e30b5d32ef7c3b0f9d`, linked Git admin/common
  directories, clean index, and complete six-path dirty inventory. Every
  recorded path status, regular-file type, mode, byte count, and raw SHA-256
  matched with no extra or missing path. The NUL-delimited status SHA-256 was
  `5cf63a070dfe49313ecf75b3b2b7c3995af41ba5f22a8c4c39523108c7863b09`
  and the tracked binary-diff SHA-256 was
  `9246b662e27202b4da57f7adb476aae9ab0133cae5176c50d3a8a115cc34ea6f`.
  The main checkout was inspected read-only at canonical path
  `/Users/junaid/Xcode-Projects/Lidless`: branch `main`, starting HEAD, clean
  index and tracked diff, exact three-path `.playwright-mcp` inventory, status
  SHA-256
  `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`,
  and empty tracked binary-diff SHA-256 all match the rolling authority. No
  mismatch was normalized or waived, and the main checkout remains untouched.

## Twenty-fifth checkpoint finding / verification matrix

| ID | Invariant / finding | Evidence | Verdict |
|---|---|---|---|
| T25-01 | An incompatible helper must not receive an unversioned cleanup mutation merely because its reply is rejected later | Cleanup is now a safety-revision-3 two-phase protocol. The client accepts preparation only from an exact protocol/revision responder and never invokes the legacy selector; missing, older, future, malformed, negative, and tokenless preparations cannot reach commit. | PASS OFFLINE — MIXED-VERSION RUNTIME GATE OPEN |
| T25-02 | The process that reports compatibility must be the process allowed to begin cleanup | Preparation returns a random process-lifetime UUID authorization. The receiving daemon validates it before lifecycle advancement, the removal fence, restore, wake cancellation, or data deletion; a commit delivered to a restarted/replacement process fails first. Pure token tests and source-order tests cover the offline boundary. | PASS OFFLINE — LIVE RECONNECT / RESTART GATE OPEN |
| T25-03 | Failed preparation must not leave cached `.ready` eligibility | The client sets `.unknown` before suspension, records transport failure as `.notResponding`, exact revision mismatch as `.stale`, and refusal or registration change as `.unknown`; the unresolved-removal fence is committed immediately before commit dispatch. | PASS BY STRICT COMPILE + SOURCE CONTRACT — UI / RUNTIME GATE OPEN |
| T25-04 | Older apps must not trigger the new helper's unsafe unbound cleanup selector | Safety-revision-3 retains the protocol-v6 legacy selector solely as a structured `ok: false` response. Dedicated source assertions exclude lifecycle, fence, restore, wake, and data mutations from both preparation and the legacy handler. | PASS OFFLINE — SIGNED OLD-APP / NEW-HELPER XPC GATE OPEN |
| T25-05 | Exact selected bytes must pass independently of the preserved remainder | Exported index tree `6df0141cc73814394ad6bdaee69bd3699cbfa12a` passed 18 related tests, all 283 exact tests, both Core configurations, strict all-product typechecking, and direct unsigned Debug/Release links. | PASS OFFLINE |
| T25-06 | The token must not be overstated as installed-executable or registration identity | Architecture explicitly states that a lingering responder is not bound to the SMAppService registration later unregistered; enabled-to-enabled registration/executable ABA remains open. The token is process-lifetime and replayable in that trusted process, not an attestation or one-shot receipt. | OPEN GATE — CLAIM BOUNDED |
| T25-07 | This checkpoint does not cure wake-ledger or full uninstall transaction defects | Schedule replacement/persistence/orphan reconciliation, exact external wake readback, safe stale-helper replacement, unregister timing, and real pmset/data cleanup remain outside this checkpoint. | SEPARATE SAFETY / RUNTIME GATES OPEN |

### Twenty-fifth append-only evidence log (continued)

- E-378 — 2026-08-06T05:56:33+0200 — Reproduced the complete preserved package
  before accepting a claim. The literal required command first failed before
  manifest evaluation because the default beta toolchain attempted
  sandbox-forbidden user-cache writes (`swift-test-preserved-baseline.log`, 6
  lines, SHA-256
  `172259cc7c25cb91e500fbd0d9bb8b145292d2729e690d4705e0f980a63c146e`).
  Stable Xcode 26.5 / Swift 6.3.2 with scratch/module caches routed to writable
  locations and SwiftPM's nested sandbox disabled passed all 286 then-present
  working-tree tests in 28 suites
  (`swift-test-preserved-baseline-stable.log`, 733 lines, SHA-256
  `a7a030b74ef16006044f19258ec84dace79ee41c0ab6a514a74a99e3ec06d6d6`).
  Complete diff review and three independent read-only audits rejected the six
  remainder files as one package and selected only the stale-helper cleanup
  dispatch defect. The six remainder files were not edited.
- E-379 — 2026-08-06T05:56:33+0200 — Established RED before the selected
  production repair. The first regression proved that enabled-helper cleanup
  lacked any exact-current preflight
  (`swift-test-stale-cleanup-preflight-red.log`, SHA-256
  `0c23b5a754ddbd094a501c5e8208877fcc20bc922ecc2d4f0209d6b856db9d1a`).
  A simple status-before-cleanup implementation reached focused GREEN
  (`swift-test-stale-cleanup-preflight-green2.log`, SHA-256
  `9779370c45fb0dafb8fbb490635d29e79c84fe8607b3cdee38d6bee51e91b389`)
  and a 287-test working-tree pass, but adversarial review rejected it: XPC
  could reconnect between the two requests and dispatch cleanup to another
  helper process. Those superseded results remain preserved and are not used
  as final safety evidence. The hardened token RED then failed exactly at the
  missing process-bound preparation
  (`swift-test-cleanup-token-red.log`, 85 lines, SHA-256
  `f50596aa7e629bd0ecf7427143aed58b5ba91788b03b1cae2f98ad659230a5f8`).
- E-380 — 2026-08-06T05:56:33+0200 — Implemented the bounded root-cause repair.
  Protocol v6 gains additive `prepareUninstall` and `commitUninstall` methods
  over JSON `Data`; helper safety revision advances independently to 3.
  Preparation returns current status plus a process-lifetime UUID, and commit
  rejects malformed or foreign authorization before every cleanup-relevant
  mutation. The new client invalidates cached readiness before preparation,
  requires exact self-reported compatibility, rechecks coarse registration,
  fences locally before commit, and has no fallback to legacy cleanup. The
  revision-3 legacy selector replies false without cleanup mutation. This is a
  process-receiver binding, not executable attestation or registration receipt.
- E-381 — 2026-08-06T05:56:33+0200 — Independent adversarial reviews exposed
  and closed the initial reconnect ABA, cached-ready regression, false
  `.notResponding` presentation for a responding refusal, nondeterministic
  negative UUID test, stale revision/test-count documentation, literal
  read-only overclaim, missing legacy/preparation negative coverage, and an
  overclaim about enabled-to-enabled replacement. Final reviewers accepted the
  narrow offline checkpoint: a commit delivered to a different process fails
  before cleanup. They explicitly retained registration/executable ABA,
  signed mixed-version XPC, unsupported-selector behavior, same-process replay,
  wake-ledger orphaning, and real cleanup/unregister as open gates. Reviewers
  changed no file or index.
- E-382 — 2026-08-06T05:56:33+0200 — Curated exactly ten non-ledger paths:
  architecture, client, daemon, two Core protocol/revision sources, three
  existing safety suites, the client proof suite, and the new pure handshake
  suite. The six authenticated remainder paths are not staged. Before these
  ledger entries, staged and unstaged tracked `git diff --check` passed. The
  pre-ledger staged binary-diff SHA-256 is
  `2561b61f608a56cd84d6bd68e3debfe2dcfa79db2b2a6066e943cdf4ebde19f5`,
  and exported exact index tree is
  `6df0141cc73814394ad6bdaee69bd3699cbfa12a`. Only append-only ledger bytes
  change after that tested export; terminal review must prove every selected
  non-ledger index blob still matches it.
- E-383 — 2026-08-06T05:56:33+0200 — The final complete working tree passed
  all 290 tests in 29 suites, including the seven tests supplied only by the
  excluded remainder (`swift-test-full-working-cleanup-token-final.log`, 678
  lines, SHA-256
  `155ebb7d4701f335b7ca68e591832180a4e746bd09998dbddcb5d74b975c3443`).
  The exact exported index passed 18 related cleanup/daemon/revision/delayed
  sleep tests in 5 suites
  (`swift-test-related-exact-cleanup-token-final.log`, 128 lines, SHA-256
  `18104bbc44889c784d2ff9d07b42f33db8bc9b6c003ebb215dd30e6e380e218f`)
  and all 283 exact tests in 28 suites
  (`swift-test-full-exact-cleanup-token-final.log`, 663 lines, SHA-256
  `77a9cbcc5b412a7ee175d8b04c54dd608684ebf04cd341df90bed158d92d3601`).
  The pure/source tests did not run App, helper, widget, XPC, launchd, pmset, or
  hardware behavior.
- E-384 — 2026-08-06T05:56:33+0200 — Under the recorded Xcode 26.5 / Swift
  6.3.2 toolchain (`toolchain-record-cleanup-token-final.log`, 8 lines,
  SHA-256
  `1b933d3c67d90d8838e55b720d3f34d4b7b7710ece3753caecc0af196c99df9c`),
  exact Debug and Release `LidlessCore` builds passed with
  `CODE_SIGNING_ALLOWED=NO`
  (`swift-build-core-debug-exact-cleanup-token-final.log`, SHA-256
  `d46b23cfe178c08dbb8691868c4823f997b2e648007b9557f5f7a6a5eb0ab713`;
  Release SHA-256
  `34227a7c6258e36d336bdf358fae70c10ebb3ae51c043abc76b23fea58962c9d`).
  All 25 App, 4 helper, and 1 widget exact sources passed macOS 15 Swift 6
  complete strict-concurrency typechecking with warnings-as-errors
  (`swiftc-all-products-typecheck-exact-cleanup-token-final.log`, SHA-256
  `bc641d58256acbe4775d68ceac16f8521165758a548a0a25d3c80082745f3af5`).
  With signing disabled and linker ad-hoc signing suppressed, all three exact
  source sets plus all 28 Core objects linked in Debug
  (`direct-all-products-debug-exact-cleanup-token-final.log`, SHA-256
  `f07b960df914ce26bf023c35cbd8a0f256482a85e72bde1d221078534eed392c`)
  and optimized Release (SHA-256
  `cafa172ec91dffeae716b6db74105bfdb6f08822ae5a0ba8862896a4f6247837`).
  No product was launched.
- E-385 — 2026-08-06T05:56:33+0200 —
  `artifact-config-inspection-exact-cleanup-token-final.log` (396 lines,
  SHA-256
  `95dfc1dff5bc78e8e114ec586c7e3f151e2767285d0f722f1321f6f990cba55b`)
  records modes, sizes, hashes, thin arm64 file types, macOS 15 build-version
  commands, dependencies, absence of `LC_CODE_SIGNATURE`, and expected
  unsigned codesign verdicts for all six loose Debug/Release outputs. It also
  preserves lint/decoded App/helper/widget plist and entitlement sources,
  source/generated-project identity bindings, exact protocol/revision
  constants, and both fail-closed helper strings in the Debug helper. These are
  loose unsigned executables and source configurations, not Xcode-built
  bundles, embedded entitlements, signed identity, installed-helper freshness,
  XPC trust, notarization, or runtime evidence.
- E-386 — 2026-08-06T05:56:33+0200 — Reverified the feature remainder and main
  checkout after all tests/builds in
  `main-and-remainder-preservation-cleanup-token-precommit.log` (45 lines,
  SHA-256
  `55c2e4e0220b58a37aef904b7da16199242c33b9e88ee9ec47ead059727812f0`).
  The exact topology, feature branch/precommit HEAD/common directory, empty
  unmerged list, every remainder status/mode/size/raw hash, remainder NUL-status
  SHA-256
  `5cf63a070dfe49313ecf75b3b2b7c3995af41ba5f22a8c4c39523108c7863b09`,
  and tracked binary-diff SHA-256
  `9246b662e27202b4da57f7adb476aae9ab0133cae5176c50d3a8a115cc34ea6f`
  match the rolling authority. Main remains `main` at starting HEAD with clean
  index/tracked diff and the exact three `.playwright-mcp` paths; its status
  SHA-256 remains
  `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`.
- E-387 — 2026-08-06T05:56:33+0200 — No App/helper/widget process, helper
  install/activation/registration/approval/unregister, live XPC, mutating
  `pmset`, sleep-setting change, sleep/wake, hardware, authentication,
  credential, plugin/provider/connector, Figma, network publication, release,
  notarization, merge, push, deploy, or main-checkout mutation was performed.
  Project-native Xcode build/analyze was not retried after the established
  nested-sandbox failure and automatic LaunchServices side-effect constraint;
  strict compiler analysis and direct unsigned builds are the bounded static
  evidence. Safe revision-2 replacement, registration/executable identity ABA,
  signed mixed-version XPC, process restart and replay integration,
  wake-ledger persistence/orphan reconciliation, real pmset/data cleanup,
  unregister behavior, sleep/wake, closed-lid hardware, notarization, and
  release readiness remain open. The coherent checkpoint is prepared under
  subject `safety: bind helper cleanup to responder process`; top-level
  `State: IN_PROGRESS` is intentionally retained. After exactly one local
  commit, the supervisor must bind the exact remaining tree into a fresh
  rolling manifest before another invocation.
- E-388 — 2026-08-06T05:58:59+0200 — Completed the terminal staged review in
  `final-staged-review-cleanup-token.log` (898 lines, 50,332 bytes, SHA-256
  `57ed8f159f62243ccd600cea61d1dfc05d375ba064038e8fbed339f3d2a6e914`).
  The review preserves the complete staged binary diff, confirms the exact 11
  selected paths, proves every non-ledger selected index blob byte-for-byte
  equals the tested exact-index export, passes staged and unstaged
  `git diff --check`, finds no unmerged entry, and leaves only the authenticated
  four tracked plus two untracked remainder paths outside the checkpoint. The
  pre-terminal-ledger index tree was
  `54ac6ae7fe0dc0d270471b33d80aa1143c0aa170`; its staged binary-diff SHA-256
  was `db2805c7ab32163db61b442e4f0db377f495aecae7d24c5a5e19128f589ee484`.
  This E-388 append is the sole subsequent selected-byte change before the
  final index check and commit.

## Twenty-sixth recovery audit — helper-removal remainder

- E-389 — 2026-08-06T06:03:37+0200 — Began the twenty-sixth recovery from the
  checkpoint-aware rolling remainder manifest, whose adjacent sidecar exactly
  matches manifest SHA-256
  `535e281d004f26cfd2ffae198a48a2ecfb6f8e663ed7ce38f15f270fcce62e80`.
  The canonical handoff and immutable historical manifest independently match
  their supplied SHA-256 values. The rolling manifest is the sole authority
  because feature HEAD has advanced beyond starting HEAD. Before this first
  edit, this ledger was 379,269 bytes with SHA-256
  `315f2a2e11b5f02cf4223e090cae8a490d5e5f58d3b471a465a16bc24cd3da52`;
  its required top-level `State: IN_PROGRESS`, branch, and starting HEAD were
  exact. The handoff, both manifests, sidecar, progress log, decision log,
  architecture, and design-reset brief were read in full. A tracked and
  untracked hidden-file scan found no repository-local `AGENTS.md`,
  `CLAUDE.md`, or equivalent instruction file.
- E-390 — 2026-08-06T06:03:37+0200 — The pre-edit recovery audit reproduced
  the exact feature canonical path, two-worktree linked topology, branch, HEAD
  `d29b6d3ccd47f740e7c56a571519d8cf806c8c8c`, linked Git admin/common
  directories, clean index, and complete six-path dirty inventory. Every
  recorded path status, regular-file type, mode, byte count, and raw SHA-256
  matched with no extra or missing path. The NUL-delimited status SHA-256 was
  `5cf63a070dfe49313ecf75b3b2b7c3995af41ba5f22a8c4c39523108c7863b09`
  and the tracked binary-diff SHA-256 was
  `9246b662e27202b4da57f7adb476aae9ab0133cae5176c50d3a8a115cc34ea6f`.
  The main checkout was inspected read-only at canonical path
  `/Users/junaid/Xcode-Projects/Lidless`: branch `main`, starting HEAD, clean
  index and tracked diff, exact three-path `.playwright-mcp` inventory, status
  SHA-256
  `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`,
  and empty tracked binary-diff SHA-256 all matched the rolling authority. One
  preliminary read-only comparison script failed before comparison because it
  iterated manifest values as keys; it changed nothing. The corrected
  independent comparison returned `ROLLING_RECOVERY_COMPARISON=EXACT_MATCH`.
  No mismatch was normalized or waived, and the main checkout remains
  untouched.

### Twenty-sixth finding and verification matrix

| Surface / invariant | Verdict | Independently reproduced evidence and boundary |
|---|---|---|
| Rolling checkpoint recovery and main-checkout preservation | PASS | Sidecar, topology, branch, pre-checkpoint HEAD, clean starting index, all six remainder records, both digests, and every main-checkout field matched exactly before the first edit. |
| Inherited six-file helper-removal remainder as one coherent package | REJECTED / PRESERVED | `canBeginAppRemoval` and `canRemoveRegistration` are unused Boolean duplicates that erase stronger existing admission/status semantics; the new broad test file duplicates weaker subsets of committed suites; the smoke and orchestration/design edits do not form the same root-cause repair. None is staged or normalized. |
| Uninstall after a known scheduled wake | PASS — source/order only | A successful external cancellation is followed by strict exact-record absence before in-memory intent is cleared or helper data is deleted; either cancellation or record-removal error returns `ok: false` before deregistration can be authorized. No live `pmset` or injected filesystem execution occurred. |
| Uninstall when memory has no scheduled wake but a ledger may remain | PASS — source/order only | The strict record-removal call is lexically outside the optional in-memory branch and therefore runs unconditionally. Exact-target `fileNoSuchFile` alone is accepted; every other error propagates to the fail-closed reply. |
| Compatibility with helpers lacking this behavior | PASS — metadata boundary only | App requirement and daemon producer declaration both advance from safety revision 3 to exact revision 4; missing, old (including 3), and future revisions fail every proof wrapper. This is self-reported compatibility metadata, not executable identity or replacement proof. |
| Regression evidence | PASS | Three increasingly specific wake-ledger/order RED observations and the revision-4 RED preceded the settled implementation; focused exact-index GREEN is 16 tests in 4 suites and complete exact-index GREEN is 284 tests in 28 suites. |
| Debug/Release compilation and artifact inspection | PASS — unsigned static evidence | Exact-index Core builds, strict Swift 6 all-product type-checks, and loose App/helper/widget links passed in both configurations with signing disabled; all six outputs lack `LC_CODE_SIGNATURE` and are rejected by `codesign` as unsigned. |
| External cancellation plus ledger unlink as one durable transaction | OPEN | The operations are not atomic. Crash/power loss between them, unlink durability, cancellation timeout/outcome ambiguity, retry idempotence, and external wake readback remain unproved. |
| Corrupt/mismatched ledger, process restart, helper replacement, ServiceManagement ABA/unregister | OPEN | A corrupt or memory/disk-mismatched record can still correspond to an orphan external wake; process-local fences, revision-3 replacement, signed mixed-version XPC, same-category registration replacement, inactive-orphan cleanup, and live unregister require separate work or runtime evidence. |

- E-391 — 2026-08-06T06:23:44+0200 — Reviewed the complete inherited
  six-file remainder against checkpoint HEAD and traced every claimed helper
  removal invariant through the existing stronger policy types and call sites.
  The package was not accepted wholesale. `HelperRemovalSafety.canBeginAppRemoval`
  duplicates `HelperRemovalAppSafety.canProceedRemoval` while omitting the real
  start gates; `canRemoveRegistration` collapses the safety-significant
  `.unregister` versus `.alreadyInactive` decision into a Boolean; neither new
  wrapper has a production call site. The untracked broad test suite duplicates
  weaker subsets of committed removal, handshake, token, wake, restart, and
  registration suites, and the smoke/progress/decision/design edits do not
  close this root cause. All six paths remain byte-identical to the rolling
  authority and outside the index.
- E-392 — 2026-08-06T06:23:44+0200 — The literal required
  `swift test --package-path Packages/LidlessCore` was attempted first and its
  complete environment-only failure is preserved in
  `swift-test-literal-preserved-baseline.log` (6 lines, 2,347 bytes, SHA-256
  `6379b944642ff274eb2f8327aca50bb901f69759cb3c50e947aef56a06682c53`,
  exit 1): the default beta toolchain tried to write a sandbox-denied user
  clang cache. The same preserved tree passed under the stable Xcode toolchain
  with redirected task caches and SwiftPM sandboxing disabled: 290 tests in 29
  suites, recorded completely in `swift-test-preserved-baseline-stable.log`
  (744 lines, 57,906 bytes, SHA-256
  `6c13fd2cbf192c888113ae138c4cb9d029a9579c934c0cd4560ee396f425eb69`).
  This established only a reproducible baseline, not acceptance of the dirty
  package.
- E-393 — 2026-08-06T06:23:44+0200 — Independently confirmed that
  `handleUninstall` canceled a known external wake and cleared memory but did
  not strictly eliminate `scheduled-wake.json` before fallible helper-data
  deletion. A later failure or restart could therefore reload stale intent.
  RED was observed before the root fix: the initial missing strict cleanup in
  `swift-test-wake-ledger-red.log` (1,243 lines, SHA-256
  `cda960d68f4734ecfd5dede45301642dddbddfb1eaf60da7c8e5bf0122b0427a`,
  exit 1); the memory-nil/stale-ledger hole in
  `swift-test-wake-ledger-candidate-red.log` (191 lines, SHA-256
  `0c89a805e70d956315decea16907a5b7e0e2cfbce8dfd12ddac3762b1f4757fd`,
  exit 1); and the clear-before-ledger ordering in
  `swift-test-wake-order-red.log` (199 lines, SHA-256
  `a07a7eb36d57dfb135e5b1903c5aaad2895a39480dac2d40491cdaf0fcede85b`,
  exit 1). Advancing the test expectation to revision 4 first produced 28
  incompatibility issues against the still-revision-3 sources in
  `swift-test-helper-revision-4-red.log` (190 lines, SHA-256
  `d123449708ce0af45dba8c67fff11398f0eefdff72d5eeb7b91f1e10c354806a`,
  exit 1).
- E-394 — 2026-08-06T06:23:44+0200 — Implemented the bounded root fix:
  optional exact wake cancellation; unconditional throwing removal of the
  exact wake ledger; acceptance only of exact-target absence; a fresh
  `ok: false` status and early return for every other removal error; and
  in-memory clearing only after ledger absence. The app requirement and daemon
  producer declaration now independently advertise safety revision 4, and
  architecture text records both the boundary and non-atomic limitations. The
  regression is explicitly source-structural; it proves ordering and failure
  wiring but does not execute `pmset`, inject a filesystem fault, or restart a
  daemon. Focused revision/wake GREEN is preserved in
  `swift-test-wake-revision-final-green.log` (97 lines, SHA-256
  `14924ca00845dba2b755b4d2ac1bcf9cb3b41772ec67ce94de6bf5535a70245b`).
  A broader first run correctly exposed one stale one-failure-count assertion
  (`swift-test-removal-revision-related-final.log`, exit 1); after scoping that
  assertion to the cancellation branch, the 16 tests in 4 related suites pass
  in `swift-test-removal-revision-related-final-green.log` (123 lines, SHA-256
  `bdc419453251b66ae4a03fd0ba89596e83ce5fcfe335bc9a33f93b3c2a5f7324`).
- E-395 — 2026-08-06T06:23:44+0200 — The settled complete working tree
  passes 291 tests in 29 suites in `swift-test-full-working-settled.log` (746
  lines, 58,092 bytes, SHA-256
  `44963f7c7678d736c1480b6a64a0244c0aa9b016ad83eb51f6e0853572083382`).
  To exclude the inherited untracked and smoke tests from checkpoint evidence,
  exactly seven selected paths were staged and exported from index tree
  `d3e38503d0a95f0392829957c4044e797e70cc4d`; every non-ledger selected blob
  matched the export byte-for-byte. That exact export passes 284 tests in 28
  suites in `swift-test-exact-index.log` (729 lines, 56,793 bytes, SHA-256
  `0a43e15a92d83b62e8d41d7564744ec361f84c2d1efe9e691eb6c645f423f837`)
  and the focused 16 tests in 4 suites in
  `swift-test-exact-index-focused.log` (58 lines, SHA-256
  `08ee4d7e68c2a21332ece289a0205a60c69a8554e33dbee2ca10585e5b81ddd7`).
- E-396 — 2026-08-06T06:23:44+0200 — Exact-index LidlessCore Debug and
  Release builds passed with `CODE_SIGNING_ALLOWED=NO` and
  `CODE_SIGNING_REQUIRED=NO`; complete output is in
  `swift-build-core-debug-exact.log` (37 lines, SHA-256
  `e2a1a1f34d5c59cf578b5a3d93834fdad6394dd9c4de1858782517d61b25353e`)
  and `swift-build-core-release-exact.log` (9 lines, SHA-256
  `5bffcbdcceb69e3fe79f1b0b7192b905369f3266e19ccb3af74b3041f0c7aaf0`).
  Strict Swift 6, macOS 15, complete-concurrency, warnings-as-errors static
  type-checking passed over all 25 App, 4 helper, and 1 widget sources in
  `swiftc-all-products-typecheck-exact.log` (23 lines, SHA-256
  `ee37c36ee63e82baaa0bb152e89b12a2eabb892a0566a60c98219dbe3f573dcd`).
  The same sources and 28 exact Core objects linked into loose unsigned App,
  helper, and widget executables in both configurations without launching them;
  commands are preserved in `direct-all-products-debug-exact.log` (27 lines,
  SHA-256 `7d0053921e0251c9c2567fc01dd2e788ab8d158ec6d7635b515f44b0b227a856`)
  and `direct-all-products-release-exact.log` (27 lines, SHA-256
  `6d9f448a5079323f4b9a8cb2b8f31f59f517e3b841f3c3d3374b0830c2393f1d`).
- E-397 — 2026-08-06T06:23:44+0200 — Artifact/configuration inspection is
  preserved in `artifact-config-inspection-exact.log` (375 lines, 30,372
  bytes, SHA-256
  `90c5822b803a0e676bdc57eeec44c9a7b3bd93f9558b6c1c973a220e9c328ebf`).
  All six loose outputs are arm64 Mach-O executables targeting macOS 15, have
  no `LC_CODE_SIGNATURE`, and produce the expected nonzero unsigned `codesign`
  display/entitlement verdict. App/helper/widget plist and entitlement sources
  lint and decode; source/generated project bindings, revision-4 declarations,
  the strict cleanup call, and both fail-closed helper strings were inspected.
  These outputs are not bundles, signed identities, installed-helper receipts,
  XPC trust, notarization, or runtime evidence. Working, staged, and both
  untracked whitespace checks plus an empty unmerged list pass in
  `diff-checks-exact.log` (5 lines, SHA-256
  `dc7853a38a38812a05fcd0a20da10e7beee1e2bcec2e70f101466fbbbd37c589`).
- E-398 — 2026-08-06T06:23:44+0200 — The corrected terminal precommit
  preservation audit is `main-and-remainder-preservation-precommit-exact.log`
  (22 lines, 3,986 bytes, SHA-256
  `97da8e9949b915eaa4072e94652aca3ee5f537e18d1430506f7ad9208caf9f30`):
  feature topology/branch/precommit HEAD/common directory, empty unmerged list,
  exact seven staged paths, every six-file remainder status/mode/size/hash and
  both remainder digests match; main remains `main` at starting HEAD with clean
  index/tracked diff, exact three `.playwright-mcp` records, and both main
  digests unchanged. A preliminary checker omitted `--untracked-files=all` and
  failed while parsing the collapsed main directory after all prior fields had
  matched (`main-and-remainder-preservation-precommit.log`, 21 lines, SHA-256
  `463dabd0a59f906e2c8ba1fd984a4018c4ea08bb4dbdfcb7b8a87684d42397d5`);
  it changed nothing. No App/helper/widget product was launched, and no helper,
  ServiceManagement, XPC, `pmset`, sleep, hardware, credential, plugin,
  provider, connector, Figma, network, release, merge, push, deploy, or main
  checkout mutation was performed. Project-native Xcode build/analyze was not
  retried because its established nested-sandbox failure path can trigger
  automatic LaunchServices registration; direct compiler analysis is the
  bounded substitute. Top-level `State: IN_PROGRESS` is intentionally retained
  for the authenticated six-file remainder and explicit live/atomicity gates.
  This invocation will create exactly one local checkpoint with subject
  `safety: require wake ledger absence before helper removal`; the supervisor
  must bind the exact post-commit remainder into a fresh rolling manifest
  before another invocation.
- E-399 — 2026-08-06T06:23:44+0200 — Reviewed the complete staged binary
  diff in `final-staged-review-wake-ledger.log` (525 lines, 32,317 bytes,
  SHA-256
  `2da0c0e46763f560739e7491e036194111c87739c04b413fe0691481d891d646`).
  It confirms the exact seven selected paths, preserves their full diff,
  verifies that every non-ledger index blob remains byte-for-byte identical to
  the tested exact-index export, and passes staged/unstaged whitespace and
  unmerged checks. The pre-terminal-ledger index tree was
  `8739c073727441ca1dfe95bfa89ad7ae43747ac1`; its staged binary-diff SHA-256
  was `06b77c55f580b27e3bdf5ff56e604af066a1aaeefcb5a0b1177a2d3feb28cf7a`.
  This E-399 append is the sole subsequent selected-byte change before the
  final index check and one local commit.
- E-400 — 2026-08-06T06:30:18+0200 — Resumed only after the checkpoint-aware
  recovery gate passed exactly and before any edit. The canonical handoff and
  immutable starting manifest retained their required SHA-256 values; the
  rolling manifest's adjacent sidecar verified it at SHA-256
  `d5451aa122a6bb0d39c9b8bb482faf901e45ff8165ba7c6dbfd41c9c419ea9e9`.
  The feature worktree resolved to the recorded canonical path, linked-worktree
  admin directory, common Git directory, branch, and HEAD
  `dc6dea161292f46814046f0a061d882665d82b0d`; its index and unmerged list were
  empty. All six dirty paths exactly matched status/type/mode/size/raw hash,
  with no extra or missing path; its NUL-delimited complete-status SHA-256 was
  `5cf63a070dfe49313ecf75b3b2b7c3995af41ba5f22a8c4c39523108c7863b09`
  and tracked binary-diff SHA-256 was
  `9246b662e27202b4da57f7adb476aae9ab0133cae5176c50d3a8a115cc34ea6f`.
  The main checkout remained `main` at starting HEAD with an empty index and
  tracked diff; all three recorded `.playwright-mcp` files matched exactly,
  its NUL-delimited status SHA-256 was
  `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`,
  and its tracked binary-diff SHA-256 was the empty-input
  `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.
  The handoff, both manifests, rolling sidecar, progress, decisions,
  architecture, design-reset brief, and repository `CONTRIBUTING.md` were read
  completely; no repository `AGENTS.md`, `CLAUDE.md`, or other governing
  instruction file was found. `State: IN_PROGRESS` is retained while the
  authenticated six-file remainder is independently re-audited.

## Typed helper-removal policy checkpoint matrix — 2026-08-06

| ID | Invariant or boundary | Exact offline evidence | Ruling |
|---|---|---|---|
| R26-01 | Registration authorization must preserve the typed `.unregister` versus `.alreadyInactive` decision | The production client switches `HelperRemovalSafety.removalAction`; the focused regression rejects a Boolean convenience that would erase the action, and the exact three-test policy suite passes | CHECKPOINT VERIFIED OFFLINE |
| R26-02 | App removal admission must remain in the two-stage app policy rather than acquire a misleading registration-policy alias | Production calls `HelperRemovalAppSafety.canStartRemoval` and then `canProceedRemoval`; the regression rejects `canBeginAppRemoval` on the registration policy and confirms both app-policy entry points remain present | CHECKPOINT VERIFIED OFFLINE |
| R26-03 | The inherited aggregate tests and smoke additions cannot substitute for stronger focused suites | The 262-line aggregate suite and two smoke tests duplicated weaker subsets of eight committed suites; they were excluded, the two tracked files match checkpoint HEAD, and the final exact suite is 285 tests in 28 suites | REJECTED REMAINDER; FOCUSED GUARD SELECTED |
| R26-04 | Offline source/build evidence does not establish ServiceManagement, XPC, signing, or helper-runtime behavior | No product was launched; the six direct outputs are loose unsigned executables, not bundles; project-native Xcode build/analyze was avoided because prior runs invoke LaunchServices registration | LIVE / SIGNED-RUNTIME GATES OPEN |
| V26-01 | Selected policy bytes pass RED/GREEN, related, complete, strict static, and Debug/Release compilation checks | RED produced exactly two issues; GREEN passed 3 focused tests, 32 related tests in 8 suites, and 285 complete tests in 28 suites; Core and all three product source sets compile in Debug and optimized Release; strict Swift 6 typechecking passes | PASS FOR EXACT OFFLINE CHECKPOINT |

- E-401 — 2026-08-06T06:37:52+0200 — Independently reviewed every authenticated
  remainder byte and traced both added APIs through production. Neither
  `canBeginAppRemoval` nor `canRemoveRegistration` had a production caller.
  The former duplicated `HelperRemovalAppSafety.canProceedRemoval` under a
  misleading begin-stage name while omitting the separate simulation,
  removal, termination, and lifecycle-operation start gates. The latter
  reduced `removalAction(...)` to a Boolean, returned true for an inactive
  registration, and erased the distinction that tells production not to call
  `SMAppService.unregister()` for `.alreadyInactive`. Three independent
  read-only audits reached the same result. The inherited broad test suite was
  a weaker aggregate of the existing app, registration, completion, client,
  handshake, daemon, and revision suites; its two smoke additions duplicated
  stronger protocol/revision and widget-proof tests. The progress, decisions,
  and design-brief changes are unrelated design work; some progress claims are
  stale or broader than current evidence, and prohibited Figma claims were not
  reverified. Those three files remain byte-identical to the rolling authority
  and are excluded from this checkpoint.
- E-402 — 2026-08-06T06:37:52+0200 — Added one focused source-contract
  regression to the existing registration-authorization suite before changing
  the authenticated wrapper-bearing source. RED failed exactly the two new
  negative expectations in `swift-test-typed-removal-red.log` (249 lines,
  12,044 bytes, SHA-256
  `9427ab7340c682a4a5a59596145a79fe70820b36c5a2e6f774fccde2f6f88ad1`).
  The root fix removed both uncommitted policy wrappers, excluded the untracked
  aggregate suite, and removed the two redundant smoke tests. The policy source
  and smoke file then matched checkpoint HEAD byte-for-byte; no App, helper,
  widget, or other product source changed. Focused GREEN passed 3 tests in one
  suite in `swift-test-typed-removal-green.log` (90 lines, 5,895 bytes,
  SHA-256
  `331ae2c2432ba0e1b9d3e7668f13d4241c2f35286846e7af207509c6e7e4ee52`).
  Eight related suites passed 32 tests in
  `swift-test-removal-related-green.log` (98 lines, 7,816 bytes, SHA-256
  `2afc599324de5c9925d699000e03001ca92f17d46df47ceb1ac5b14674694dfe`).
- E-403 — 2026-08-06T06:37:52+0200 — The literal required command
  `swift test --package-path Packages/LidlessCore` was attempted on the final
  tree and its complete environment-only failure is preserved in
  `swift-test-literal-final.log` (6 lines, 2,347 bytes, SHA-256
  `accfc1c8fe1103fea4285f3fdb183cad707f2eca41b9599182d660d27e51ae2f`):
  the selected beta toolchain tried to write a sandbox-denied user clang cache.
  Pinned stable Xcode with task-local caches and the SwiftPM sandbox disabled
  passed all 285 tests in 28 suites; complete output is
  `swift-test-full-final.log` (731 lines, 56,979 bytes, SHA-256
  `f389c0e2a114fd51d2f5d813c886d8d81396b8c1f6aafab82fb78c2ef2e5004b`).
  For comparison only, the authenticated wrapper-bearing tree passed 291 tests
  in 29 suites in `swift-test-stable-baseline.log` (746 lines, 58,089 bytes,
  SHA-256
  `381ec575ab19643d8bfc19ca16434e7183df52c58e64514d8ad37203010ecdd9`),
  demonstrating auto-discovery rather than validating those inherited tests.
- E-404 — 2026-08-06T06:37:52+0200 — With
  `CODE_SIGNING_ALLOWED=NO` and `CODE_SIGNING_REQUIRED=NO`, stable Swift built
  LidlessCore in Debug and Release; complete logs are
  `swift-build-core-debug.log` (37 lines, SHA-256
  `843fa0d289cee91d286311a75cbfd2162e49fc57f82eec09b1cc3d44a8090950`)
  and `swift-build-core-release.log` (9 lines, SHA-256
  `909ac506f2f673ab534764f178e670001840eb82e0000d441476571419fc8477`).
  All 25 App, 4 helper, and 1 widget sources compiled and linked against the 28
  Core objects in both configurations with `-no_adhoc_codesign`; complete
  command/output logs are `direct-all-products-debug.log` (47 lines, SHA-256
  `dbc8d7949f2172c4be3d5bed3b07f294576a5697c62faff8a3e41088bff9416a`)
  and `direct-all-products-release.log` (47 lines, SHA-256
  `b496a679b7614b6acba492cc1607a2b6c36996c58b5cb91669201cb3850ee36d`).
  Swift 6 complete-concurrency typechecking with warnings-as-errors passed all
  three source sets in `static-typecheck-all-products.log` (21 lines, SHA-256
  `1c56f9c5a65395abc6dac0d36b58068b8f7ef4bce1a5c324dd0fa8befe2465cb`).
  `artifact-config-inspection.log` (457 lines, SHA-256
  `bfbca6c9787d9cce452b4a31580e96332da305fcf89900c9db478fb7a80b8f80`)
  records six arm64 Mach-O executables with macOS 15 minimum, no
  `LC_CODE_SIGNATURE`, and expected code-sign inspection failure, plus syntax
  and decoded contents for all six source plist/entitlement files and matching
  project identifier/team/deployment bindings. These loose outputs are not app
  bundles, carry no bound identity or entitlements, and prove no signed XPC,
  SMAppService, install, notarization, sleep-setting, or hardware behavior.
  Project-native Xcode build/analyze was not run because preserved prior logs
  prove that path invokes automatic LaunchServices registration. No product or
  helper was launched, installed, activated, registered, approved, or invoked.
- E-405 — 2026-08-06T06:40:42+0200 — Exported the complete selected index tree
  `284e53327d343bf3d09b8e2185a23fb7a1825c98` to an isolated temporary
  directory and independently verified both exported file hashes against their
  index blobs. From that exact export, the focused registration-policy run
  passed 3 tests in one suite; complete output is
  `swift-test-exact-index-focused.log` (90 lines, 5,818 bytes, SHA-256
  `e80bdd49091026c6c97dba6a51774044c6ecefdd82258106a847c7f2aa52198a`).
  The complete exact-index run passed 285 tests in 28 suites; complete output
  is `swift-test-exact-index-full.log` (667 lines, 53,010 bytes, SHA-256
  `1e12ed5f626635f743c5f85bfc9166c5fd2f6071cff14aa7a50453cae2ae611d`).
  The precommit preservation audit confirms branch
  `codex/lidless-safety-repair-2026-08-04`, HEAD
  `dc6dea161292f46814046f0a061d882665d82b0d`, the recorded linked-worktree
  topology/common directory, an empty unmerged list, and exactly two selected
  paths: this ledger and the 15-line focused regression. The sole unstaged
  remainder is the three unrelated design files: `decisions.md` (4,591 bytes,
  SHA-256 `cdf6a032f24dc9421f5bbf3e1b696dca7fd37da8bc4d28cf978a302cea03ccd1`),
  `progress.md` (5,774 bytes, SHA-256
  `375b445d73847e60c11f321efe97b2ac636c11f4b962118c14b02d22caacf2d0`),
  and the untracked design-reset brief (7,188 bytes, SHA-256
  `4835b0dc2fa44257d2e4aca6429e5bd5ad1cf93989686c709311d91b9659e7f7`);
  all retain mode `0644` and exactly match the rolling authority. The main
  checkout remains `main` at starting HEAD with clean index/tracked diff and
  its exact three recorded untracked artifacts; complete NUL-status SHA-256 is
  `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`
  and tracked binary-diff SHA-256 is
  `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.
- E-406 — 2026-08-06T06:41:09+0200 — Reviewed the complete staged binary diff.
  It contains only this append-only ledger and the focused 15-line regression,
  with no product-source, configuration, design, binary, rename, mode, or
  deletion change. Staged and unstaged whitespace checks pass and the unmerged
  list is empty. The pre-terminal-ledger index tree was
  `0ee13777f0c03412ef323951b575598d80052bd6`; its staged binary-diff
  SHA-256 was
  `b5f2691a2b3cd1d81522044f66897ac44333a2a9c9c5095b49e51164f8f51e7d`.
  This E-406 append is the sole subsequent selected-byte change before the
  final index check and exactly one local commit with subject
  `safety: preserve typed helper removal decisions`. `State: IN_PROGRESS` is
  intentionally retained because the supervisor must bind the exact remaining
  three-file design tree into a fresh rolling manifest before any later
  invocation; all signed/runtime/hardware gates remain open.

## Complete XPC failure-retirement checkpoint matrix — 2026-08-06

| ID | Invariant or boundary | Exact offline evidence | Ruling |
|---|---|---|---|
| X27-01 | Every XPC setup, proxy-transport, and timeout failure must retire the exact connection that carried the outcome-unknown request | The generic request worker has one catch-all after the exactly-once continuation; it calls identity-safe `retireConnection(requestConnection)` before rethrowing the original error. The first focused RED failed on the former timeout-only catch, and the final six-test suite passes. | CHECKPOINT VERIFIED OFFLINE |
| X27-02 | Malformed reply bytes must not escape after the captured connection has left scope | `status`, cleanup preparation, and all `HelperReply` operations decode inside the same generic request worker. Decode failure throws inside its catch-all, so the captured connection is retired before the error escapes. The second focused RED failed on the missing in-scope decoder, and the final source contract plus strict App compilation pass. | CHECKPOINT VERIFIED OFFLINE |
| X27-03 | Late proxy, reply, and timeout callbacks must still complete a continuation exactly once | The existing lock-backed `CompletionGate` remains unchanged; the focused suite covers each terminal winner plus 300 concurrent contenders. | CHECKPOINT VERIFIED OFFLINE |
| X27-04 | Local retirement must not clear a newer connection that replaced the failed request's connection | `handleConnectionLoss` always invalidates the captured object, but clears cached state and publishes proof loss only when identity still matches. Existing ordering tests remain green. | CHECKPOINT VERIFIED OFFLINE |
| O27-01 | The root recovery sentinel must be proven owner-only before arming | `writeSentinel` still suppresses the chmod result, does not validate final ownership/mode/ACL, and existing work-directory permissions are not revalidated. This is a separate helper-storage root cause and was not combined with the XPC checkpoint. | OPEN — NEXT ROOT-CAUSE GROUP |
| O27-02 | Scheduled-wake replacement, persistence, cancellation, and later reconciliation must not strand an untracked RTC wake | Helper persistence and prior-wake cancellation remain best-effort; App reconciliation can retain sticky uncertainty without an authoritative external wake readback. This known separate root cause remains unresolved. | OPEN — SEPARATE ROOT-CAUSE GROUP / LIVE GATE |
| O27-03 | Crash-session evidence must not be discarded before durable history and restore proof | `SessionStore` can suppress history-write and journal-delete errors, and finalizes the orphaned record before launch reconciliation proves helper plus registry restoration. This is a separate evidence-integrity root cause. | OPEN — SEPARATE ROOT-CAUSE GROUP |
| O27-04 | Every distribution uninstall path must preserve the reviewed cleanup/deregistration protocol | The inherited Homebrew cask still requests raw `launchctl` removal and its caveat overpromises restoration, while README and architecture retain uninstall/runtime gates. The cask is byte-identical to starting HEAD and was not changed in this checkpoint. | OPEN — RELEASE POLICY CONTRADICTION |
| V27-01 | Selected XPC bytes must pass RED/GREEN, focused, complete, strict static, and unsigned Debug/Release checks | Two focused REDs reproduced the uncovered branches; final focused passed 6 tests, complete passed 287 tests in 28 suites, both Core configurations built, all three product source sets passed strict Swift 6 typechecking, and all six direct products linked unsigned. | PASS FOR THIS OFFLINE CHECKPOINT |

- E-407 — 2026-08-06T06:57:29+0200 — Before any edit, independently passed
  the checkpoint-aware recovery gate. The canonical handoff and immutable
  manifest matched required SHA-256 values
  `95bdacdde663c642c2f97d532c1ec2b931e94a7dfcda47b8031e011ab3944831`
  and `d84065171a261e24ae574b98164132472ff1e8bb635647403d814b9fcf58c36a`.
  The rolling manifest's adjacent sidecar verified it at SHA-256
  `9afbf0476f155d70defac2651fcf8f3075664599b21242e9dc6f4705d045325c`.
  The feature worktree resolved to its recorded canonical path, linked
  worktree admin directory, common Git directory, branch, and HEAD
  `766b775f512e1207a012eb3fd44ecfb56bc2ea6f`; the index and unmerged list
  were empty. Its exact three-file remainder matched every recorded
  status/type/mode/size/raw hash, with NUL-status SHA-256
  `3a4984484500650d6b8866b3dfd45bc02ad0ff2888084f86deda5506c36e03dc`
  and tracked binary-diff SHA-256
  `5bfed6a6f1b1f3578736cce1d9ae66138f0f9e0614ffc8e93d0aa80c4d6e3b82`.
  The main checkout remained `main` at starting HEAD with clean index and
  tracked diff; its three recorded untracked artifacts matched exactly,
  NUL-status SHA-256 was
  `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`,
  and tracked-diff SHA-256 was the empty-input
  `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.
  The handoff, both manifests, sidecar, progress, decisions, architecture,
  design-reset brief, this complete ledger, and `CONTRIBUTING.md` were read in
  full; no repository `AGENTS.md`, `CLAUDE.md`, or equivalent governing file
  was present.
- E-408 — 2026-08-06T06:57:29+0200 — Treated the committed package and all
  prior verdicts as untrusted. Reviewed the complete starting-HEAD-to-current
  73-file package diff, commit chain, dirty remainder, App/helper/Core safety
  paths, release/configuration surfaces, and existing tests. A pinned stable
  Xcode baseline passed all 285 pre-edit tests in 28 suites in
  `swift-test-full.log` (731 lines, 56,963 bytes, SHA-256
  `c14388aef374442973544d84777eb0f9d1b1af2130223a9dbf81089f6f182646`).
  Three independent read-only audits confirmed that the committed
  `HelperClient.call` retired only timeout failures: proxy errors and bad-proxy
  setup failures escaped with the captured connection cached, and all three
  response types decoded after that connection left scope. Apple's local SDK
  header states that a reply-bearing proxy invokes either its error handler or
  reply handler exactly once and separately states that interruption callback
  ordering is not guaranteed. A failed arm or heartbeat could therefore reuse
  the failed channel and delay helper-side connection-loss restoration until a
  later callback or the finite watchdog.
- E-409 — 2026-08-06T06:57:29+0200 — Added the transport/setup regression
  before changing production. Against committed behavior it failed exactly
  because no catch-all followed the continuation in
  `xpc-request-failure-retirement-red.log` (126 lines, 7,673 bytes, SHA-256
  `474bcabdbb7fc30b2cf3d8a82f8229124af7e6d29280c20d0d7f1412e641bbbf`).
  After exposing the remaining decoder gap, added its focused regression
  before the decode refactor; it failed exactly because the generic in-scope
  decoder was absent in `xpc-malformed-reply-retirement-red.log` (66 lines,
  3,766 bytes, SHA-256
  `4069dc1e3c59997995dd0d04ab0ebb0cd9d1a20473cf9ed9e4d0e01d94850c3c`).
  The root fix made the request worker generic over a decodable, sendable
  response, moved all status/preparation/reply decoding inside its protected
  scope, and replaced timeout-only retirement with one identity-safe catch-all
  that preserves the original error. No daemon, Core production policy,
  configuration, UI, or design file changed.
- E-410 — 2026-08-06T06:57:29+0200 — Final focused GREEN passed 6 tests in
  one suite in `swift-test-xpc-request-safety-focused-final.log` (32 lines,
  2,381 bytes, SHA-256
  `133c45ec9e683abca209e74d0dc99d96859212c7b8e2b42030cf10741ffbd5ba`).
  Final complete stable-toolchain verification passed 287 tests in 28 suites
  in `swift-test-full-final.log` (735 lines, 57,317 bytes, SHA-256
  `a7ae119e4dec71cef27675a19373a380f8229e2fe68d9d13a1681ab552bc144c`).
  The literal required command `swift test --package-path
  Packages/LidlessCore` was also attempted and its complete environment-only
  failure is preserved in `swift-test-literal.log` (6 lines, 2,347 bytes,
  SHA-256
  `9f9db952e56d1319182b9f2ed01fad1a348ead9dfba00c22cb2f22c908c36d6c`):
  the selected beta toolchain attempted a sandbox-denied user Clang-cache
  write. The accepted commands pinned stable Xcode, task-local caches, and
  disabled only SwiftPM/compiler nested sandboxing.
- E-411 — 2026-08-06T06:57:29+0200 — With
  `CODE_SIGNING_ALLOWED=NO` and `CODE_SIGNING_REQUIRED=NO`, stable Swift built
  LidlessCore in Debug and Release. Complete logs are
  `swift-build-core-debug.log` (37 lines, 2,189 bytes, SHA-256
  `4e962a8c69b38d0bfaceea02c4fbb074fbc780682404bbf0b1f05421b6c7deec`)
  and `swift-build-core-release.log` (9 lines, 666 bytes, SHA-256
  `1544ca41caed4cb7a04076a4b30f2896a8b26bf64df3318a564f80224fe99203`).
  All 25 App, 4 helper, and 1 widget sources passed Swift 6 complete strict
  concurrency with warnings as errors in
  `static-typecheck-all-products-final.log` (27 lines, 5,981 bytes, SHA-256
  `4deb276c9a0c9930e302e41ac689288ded5b057a92bc05a9fb9a98192fcbc38a`).
  All three source sets linked against the 28 Core objects in Debug and
  optimized Release with linker ad-hoc signing disabled; the complete log is
  `direct-all-products-debug-release-final.log` (106 lines, 68,945 bytes,
  SHA-256
  `5a609569ee0222f7c1e8281764d936abd615a776ed8f62079560d2991799ce9c`).
  All six outputs are arm64 Mach-O executables with macOS 15 minimum, no
  `LC_CODE_SIGNATURE`, and expected code-sign inspection failure. None was
  launched.
- E-412 — 2026-08-06T06:57:29+0200 — Bash syntax, ShellCheck at warning-or-
  higher severity, YAML loading, all six source plist/entitlement files, and
  the generated project plist syntax passed. Decoded values and project
  bindings for identifiers, team, entitlements, deployment target, helper
  placement, Mach service, associated app, and Developer ID export method are
  preserved in `artifact-config-inspection-final-corrected.log` (342 lines,
  25,868 bytes, SHA-256
  `c991bb6aa80a96c6343e4969f7d32793c6aee0763aa28946d0dc15643e5a8c2b`).
  A first harness stopped before those checks because unthresholded ShellCheck
  returned its four inherited informational SC2015 notices; it is preserved
  and excluded as `artifact-config-inspection-final.log` (26 lines, 1,230
  bytes, SHA-256
  `5279c028fdaceb1aed0a942c133e28aeab6c2aa8fd8afdd5a63ad75cb26c11a1`).
  Project-native Xcode build/analyze was not rerun because preserved evidence
  shows that path invokes automatic LaunchServices registration. These loose
  unsigned executables are compile evidence only, not bundle identity,
  entitlement, signed XPC, SMAppService, or runtime proof.
- E-413 — 2026-08-06T06:57:29+0200 — Independent audits also identified
  separate unresolved root causes that prevent a terminal package verdict:
  suppressed sentinel permission enforcement; non-transactional scheduled-
  wake replacement/persistence plus sticky reconciliation uncertainty;
  crash-session journal deletion before durable history and launch restore
  proof; and the unchanged Homebrew cask's raw `launchctl` removal path. These
  findings are recorded in O27-01 through O27-04 and intentionally remain out
  of this one-root-cause checkpoint. Signed positive-path bundle verification,
  real XPC identity, ServiceManagement registration/removal/ABA behavior,
  live `pmset`, sleep/wake, crash/reboot, closed-lid hardware behavior,
  notarization, and release readiness remain open. No App/helper product,
  privileged service, system setting, provider, or network action occurred.
- E-414 — 2026-08-06T06:57:29+0200 — Pre-ledger preservation audit passed in
  `preservation-audit-preledger.log` (64 lines, 4,255 bytes, SHA-256
  `3e5555d164920f702a3ce1496705ad6176d672534d1563d05b14d6b7684624e4`).
  Branch, HEAD, linked-worktree topology, common directory, and empty index
  remained correct. The three unrelated design files retained exact rolling-
  manifest mode/size/hash bytes. The main checkout remained `main` at starting
  HEAD with clean index/tracked diff and its exact three recorded untracked
  artifacts; its NUL-status and tracked-diff digests remained
  `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`
  and `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.
  `State: IN_PROGRESS` is retained because only the XPC failure-retirement
  group is eligible for this invocation's single checkpoint.
- E-415 — 2026-08-06T06:59:21+0200 — Exported the complete selected index
  tree `1f5edf9c9da0faff42c1f939ed24bf9b23c3379b` to an isolated temporary
  directory, excluding the unstaged three-file design remainder. From those
  exact staged bytes, the focused request-safety suite passed 6 tests in
  `swift-test-exact-index-focused.log` (96 lines, 6,346 bytes, SHA-256
  `c6294b6a6b37a2785bcbb144d323b596215067a63718f8c7aef0a2ccbc822f63`),
  and the complete suite passed 287 tests in 28 suites in
  `swift-test-exact-index-full.log` (671 lines, 53,358 bytes, SHA-256
  `bccac2544f349f71d51308f83f4f83a6f711beb81c99bd767969a82bce3eecc4`).
  Export metadata is preserved in `exact-index-export-metadata.log` (2 lines,
  102 bytes, SHA-256
  `141b7ba4b3d358c5903fad72c056918af54e1ec16c54aee7e59eee4efef47243`).
- E-416 — 2026-08-06T06:59:21+0200 — Reviewed the complete staged diff. It
  contains only `HelperClient.swift`, its request-safety regression, and this
  append-only ledger; there is no configuration, daemon, UI/design, binary,
  rename, mode, or deletion change. Staged and unstaged whitespace checks
  pass, the unmerged list is empty, and the sole unstaged remainder is the
  exact three-file rolling-manifest design tree. Before E-415 and this E-416
  terminal append, the index tree was
  `1f5edf9c9da0faff42c1f939ed24bf9b23c3379b` and the complete staged binary-
  diff SHA-256 was
  `fb4625a368ab5ca7e8c58a0cb4e42ac4227ce03e0d1179ce695e5ce9db07ced4`.
  These two ledger entries are the sole later selected-byte change before the
  final index check and exactly one local commit with subject
  `safety: retire failed XPC request connections`. `State: IN_PROGRESS`
  remains intentional for the separately recorded open root causes and the
  supervisor's next rolling-remainder binding.
- E-417 — 2026-08-06T07:04:12+0200 — Before any product edit, read the
  canonical handoff, immutable starting-state manifest, authenticated rolling
  remainder manifest and sidecar, progress log, decision log, architecture,
  and design-reset brief in full. The supplied canonical and immutable hashes
  matched exactly, and the sidecar verified the rolling manifest at SHA-256
  `2306c3209c83ef609c0586bb1c136653ccdc071f22b189f36b8503f3285ca6f5`.
  No repository `AGENTS.md`, `CLAUDE.md`, `CODEX.md`, or instruction-named
  Markdown file was found outside ignored build output.
- E-418 — 2026-08-06T07:04:12+0200 — Applied only the checkpoint-aware rolling
  manifest. The feature worktree canonical path, linked topology, branch, HEAD
  `b723094e5ad8b28317ede6163668623cd7bc7e62`, Git admin/common directories,
  clean index, exact three-path dirty inventory, every recorded
  status/type/mode/size/raw SHA-256, NUL-status digest
  `3a4984484500650d6b8866b3dfd45bc02ad0ff2888084f86deda5506c36e03dc`,
  and tracked binary-diff digest
  `5bfed6a6f1b1f3578736cce1d9ae66138f0f9e0614ffc8e93d0aa80c4d6e3b82`
  matched exactly. The main checkout independently remained `main` at starting
  HEAD with clean index/tracked diff, its exact three recorded untracked files,
  NUL-status digest
  `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`,
  and empty tracked-diff digest
  `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.
- E-419 — 2026-08-06T07:04:12+0200 — The first post-gate patch mistakenly
  treated this already tracked ledger as absent and replaced only its
  working-tree copy. Git status exposed the mistake before package work
  continued. The 3,186-line committed ledger was restored exactly from HEAD;
  its working-tree blob then matched HEAD blob
  `561a884998831a16275e989542c0a1b9bba1adcb`. No product source, index,
  commit, main-checkout byte, runtime, helper, or system setting was affected.
- E-420 — 2026-08-06T07:18:01+0200 — Reproduced the committed pre-edit test
  baseline. The literal required `swift test --package-path
  Packages/LidlessCore` failed only because the selected beta toolchain tried
  to write the sandbox-denied user Clang cache; its complete output is
  `sentinel-storage/swift-test-literal-baseline.log` (6 lines, 2,347 bytes,
  SHA-256
  `e79e6251524990d9acbe6f2f4a928ae8705ce96cd74995e50dfc6940ae530223`).
  Pinning stable Xcode, task-local caches, and disabling nested SwiftPM/compiler
  sandboxing passed all 287 tests in 28 suites before product edits. Complete
  output is `sentinel-storage/swift-test-stable-baseline.log` (735 lines,
  57,322 bytes, SHA-256
  `86e49007c57b631e107d2d2922aeabdb17aded5a3c75bdb03b3724517ab56931`).
- E-421 — 2026-08-06T07:18:01+0200 — Re-audited the complete committed package
  and selected only O27-01 for this invocation. The helper swallowed work-
  directory creation and sentinel chmod errors, trusted path-decoded sentinel
  bytes before proving owner/type/mode/link/ACL metadata, used no exclusive or
  no-follow descriptor binding, and established no file or directory
  durability barrier before arming. Independent read-only audits also found a
  separate higher-priority next group: missing/unknown battery telemetry is
  currently allowed to arm and disables the floor indefinitely. Thermal
  freshness, scheduled-wake transactionality, session-journal durability,
  Homebrew cleanup, stale-helper replacement, and evidence-bounded UI copy
  remain separate open groups and are not combined here.
- E-422 — 2026-08-06T07:18:01+0200 — Added the descriptor-bound sentinel source
  regression before changing helper production code. Against committed
  behavior, its focused RED failed because the secure-directory/storage seam
  and required metadata/durability operations did not exist. Complete output
  is `sentinel-storage/sentinel-storage-source-red.log` (87 lines, 5,801
  bytes, SHA-256
  `3d9be75df4f5fbdfc427bec9d087f5452313d3a273991a6f7f930a9ecf24559a`).
- E-423 — 2026-08-06T07:18:01+0200 — Implemented the focused storage repair:
  exact root:wheel no-ACL directory proof precedes recovery; sentinel creation
  is descriptor-relative, exclusive, nonblocking/no-follow, root:wheel 0600,
  single-link regular-file and no-ACL checked; complete writes and creation/
  removal directory entries are synced; recovery decodes only trusted
  descriptor bytes; and every possibly published failed write is reconciled
  immediately, with corrupt/untrusted state forcing ordinary sleep and
  remaining pending. Exact helper safety behavior revision advanced from 4 to
  5. Focused policy/source/revision GREEN passed 8 tests in 3 suites in
  `sentinel-storage/sentinel-storage-focused-green-2.log` (44 lines, 3,118
  bytes, SHA-256
  `17bd537ab29aed57d40a3b846e063b513a7c38a2d8f33ec911814aaef56c4714`).
  The complete helper source simultaneously passed macOS 15 Swift 6 complete
  strict-concurrency typechecking with warnings as errors; the successful
  diagnostic log is empty (SHA-256 of empty input
  `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`).

## Recovery-sentinel storage checkpoint matrix — 2026-08-06

| ID | Finding or invariant | Independent evidence and disposition | Verdict |
|---|---|---|---|
| S28-01 | The sentinel namespace must not be replaceable by a non-root actor after a child-only metadata check | The helper opens and exact-checks `/var/db` as root:wheel 0755/no-ACL, then uses `mkdirat`/`openat` for the single-component `lidless` child. It exact-checks the child and reapplies child then parent `F_FULLFSYNC` barriers on every acceptance, including `EEXIST` recovery. | FIXED OFFLINE / LIVE FILESYSTEM GATE |
| S28-02 | Recovery must never decode path-followed or metadata-untrusted sentinel bytes | Read uses descriptor-relative `openat` with `O_NONBLOCK`/`O_NOFOLLOW`, exact root:wheel 0600 regular-file/single-link/no-ACL proof, bounded EINTR-aware descriptor reads, and decode only after proof. Creation is separately exclusive/no-follow and complete-write checked. | FIXED OFFLINE / FAULT-INJECTION GATE |
| S28-03 | A successful arm must follow ordered file and namespace persistence requests, and a possibly published failure must be reconciled | File bytes, final metadata, `F_FULLFSYNC`, checked file close, directory `F_FULLFSYNC`, and checked directory close precede enable. Non-EINTR sync and every checked-close error propagate. Both persistence callers immediately inspect/recover any possibly published marker; removal barriers run even after `ENOENT`. | FIXED OFFLINE / PHYSICAL-DURABILITY GATE |
| S28-04 | App/helper compatibility and launchd path configuration must bind the exact behavior | Independently produced/required safety revision is 5; stale/future revisions fail proof. Shared single-component path constants compute the sentinel, and a parsed-plist regression requires exact `KeepAlive.PathState == [HelperPaths.sentinel: true]`. Configuration wording states requested behavior, not live launchd proof. | FIXED OFFLINE / STALE-HELPER GATE |
| O28-01 | Other root-owned child paths remain path-following and can invalidate whole-directory safety claims | Independent source review confirmed `HelperLog` can follow a preexisting symlink/hardlink/special `helper.log` as root; `scheduled-wake.json` uses a separate path-based persistence surface. They cannot manufacture a proven sentinel arm but are a distinct privileged-child-storage root cause. | OPEN — SEPARATE ROOT-CAUSE GROUP |
| O28-02 | Missing or unknown battery telemetry still permits an arm with no enforceable floor | Independent audit traced the fail-open state through `BatteryMonitor`, `CutoffEngine`, and existing tests. It is unrelated to sentinel persistence and remains the higher-priority next behavioral checkpoint. | OPEN — NEXT ROOT-CAUSE GROUP |
| R28-01 | The authenticated design remainder is not implementation authority | The two tracked design logs and untracked design brief remain byte-exact to the rolling manifest and are excluded from this checkpoint. | PRESERVED / EXCLUDED |
| G28-01 | Offline source, policy, compile, and loose unsigned-link evidence cannot prove live helper/XPC/launchd, syscall fault handling, target-filesystem latency/support, OS-crash/power-loss durability, or hardware behavior | No Lidless product/helper was launched; no live service, XPC, `pmset`, sleep, signing, or hardware action occurred. Xcode 16/Swift 6.0 is unavailable on this host; language mode 6 under Swift 6.3.2 targeting macOS 15 is compile evidence only. | LIVE / SIGNED-RUNTIME / PHYSICAL GATES OPEN |
| V28-01 | Exact selected checkpoint bytes require focused/full tests, strict compilation, unsigned Debug/Release links, artifact/config inspection, staged review, and preservation checks | Working-tree GREEN is recorded below; exact-index evidence and final tree/commit identity are recorded in later append-only entries. | PENDING EXACT-INDEX VERIFICATION |

- E-424 — 2026-08-06T07:39:08+0200 — Correction to E-423: sentinel
  *creation* is descriptor-relative, exclusive, and no-follow; only recovery
  reading needs and uses `O_NONBLOCK`. E-423's early focused GREEN and empty
  typecheck log predate adversarial parent-namespace, full-persistence, checked-
  close, path-binding, and regression-strength repairs and are superseded for
  checkpoint acceptance. The historical entry is preserved append-only.
- E-425 — 2026-08-06T07:39:08+0200 — Added a review-triggered RED before the
  parent durability repair. Against the then-current child-only implementation,
  the focused source regression failed because an `EEXIST` restart skipped
  parent namespace synchronization. Complete output is
  `sentinel-storage/parent-namespace-red-2.log` (106 lines, 4,956 bytes,
  SHA-256
  `6f29036dae5ffe83e749d7830e01c85611e7289405c8002338bc84591f8d3d85`).
  Review also found that ordinary `fsync` could not support the written
  persistence claim, mutation-bearing close errors were suppressed, `/var/db`
  rename authority was unproved, and the helper duplicated the launchd marker
  basename. Those findings were resolved before the terminal GREEN.
- E-426 — 2026-08-06T07:39:08+0200 — Final narrow implementation binds the
  exact root:wheel 0755/no-ACL parent and child through descriptors; pins
  single-component path names; exact-checks sentinel kind/owner/group/0600/
  link-count/ACL; bounds and retries descriptor reads/writes on `EINTR`; uses
  retrying `F_FULLFSYNC` on file, child, and parent namespaces; checks every
  success-path mutation-bearing close; and reconciles both possibly published
  write failures before either caller continues. Revision 5 gates this behavior.
  Documentation explicitly permits pre-mutation marker cleanup and bounds
  PathState, storage-invalid memory-only fallback, device flush, crash, and
  launchd claims.
- E-427 — 2026-08-06T07:39:08+0200 — On settled working-tree production bytes,
  25 focused tests in 5 suites passed in
  `sentinel-storage/sentinel-storage-focused-terminal-working.log` (85 lines,
  6,331 bytes, SHA-256
  `d5de0a0245af8e24a8353766a029249fd5b97dcde1d65eb458a06e671ebcfa0e`).
  The complete stable-Xcode SwiftPM suite passed 291 tests in 29 suites in
  `sentinel-storage/swift-test-full-terminal-working.log` (680 lines, 54,126
  bytes, SHA-256
  `31dfb3e93f265a9cd1cd7a1022eb1271dc7a0bd8e66ba0f47d65d755ac3f01be`).
  A command/toolchain/target/exit-bearing strict helper typecheck passed under
  Apple Swift 6.3.2, Swift language mode 6, macOS 15 target, complete
  concurrency, and warnings as errors in
  `sentinel-storage/helper-strict-typecheck-current-metadata.log` (8 lines,
  1,076 bytes, SHA-256
  `ee01bf97098f7db2a283b5b76e32d1649ad89c3d3f4448231b63176fb04144b1`).
  A read-only Darwin probe recorded exact metadata/no-ACL semantics and
  successful directory-descriptor `F_FULLFSYNC` for this worktree and
  `/var/db` on this APFS host in `sentinel-storage/darwin-storage-probe-current.log`
  (8 lines, 1,776 bytes, SHA-256
  `71e8c28ef59223874ef45ab751e86462b8c84db708f0ca369408f424a6e8ece3`).
  The probe is compatibility evidence, not target-filesystem, latency,
  fault-injection, OS-crash, power-loss, or physical-device proof.
- E-428 — 2026-08-06T07:48:27+0200 — Exported the exact selected index as tree
  `e6e96391a5c0c4e6f45622c8740c1484d3af6a2b`; its reviewed staged binary diff
  has SHA-256
  `057f80b8d4f26df8a5158cc20940972e88b9615e26e54f60522f7c0a19b4f55a`
  and is preserved as `sentinel-storage/final-staged-patch-preledger.log`
  (1,585 lines, 80,249 bytes, the same SHA-256). Against that exact export,
  all 25 focused tests in 5 suites passed in
  `sentinel-storage/final-exact-index-focused.log` (142 lines, 10,021 bytes,
  SHA-256
  `c0ddf11bcbdc2637446d711c08526107c44714485ca5939edde5dc12b840e97b`),
  and the complete SwiftPM suite passed all 291 tests in 29 suites in
  `sentinel-storage/final-exact-index-full.log` (681 lines, 54,147 bytes,
  SHA-256
  `032ac19d30b69ea9a2ef31cc25be8884d3a12a574c08f5310554040f376f0e54`).
  This supersedes V28-01's pending exact-index status for the selected product,
  test, configuration, and documentation bytes.
- E-429 — 2026-08-06T07:48:27+0200 — Exact-index LidlessCore Debug and Release
  builds passed in `sentinel-storage/final-exact-index-core-debug.log`
  (41 lines, 2,429 bytes, SHA-256
  `c5b07ea7dc83119713de0474a84297931c765e94d128281c92ec741178d0c8e7`)
  and `sentinel-storage/final-exact-index-core-release.log` (13 lines, 908
  bytes, SHA-256
  `56dfc8cd2186171ba0f85272bf95cd316a427a10725472efbc04a2f79e0a9e64`).
  Direct strict Debug and optimized Release compile/link of all three products
  passed with signing and linker ad-hoc signing disabled in
  `sentinel-storage/final-exact-index-products-debug.log` (4 lines, 281 bytes,
  SHA-256
  `a09e7172dcf7b9a90ce6269003265b0c21dd9f1692640a7f7837f709a98bb30e`)
  and `sentinel-storage/final-exact-index-products-release.log` (4 lines, 283
  bytes, SHA-256
  `135596555bc6a8a99e0e41e947733a1f2c0733e728963fefa64d96eee949d3b4`).
  All-product strict static typechecking also passed in
  `sentinel-storage/final-exact-index-all-products-typecheck.log` (4 lines,
  256 bytes, SHA-256
  `905427f5005c6640262867c1a5f32f70d43bae2d3b7de5fa37742ec4f4e5d8cc`).
  The toolchain was `/Applications/Xcode.app` Apple Swift 6.3.2, Swift language
  mode 6, arm64 macOS 15 target, SDK 26.5, complete concurrency, and warnings
  as errors. This is compile/link evidence, not the unavailable Xcode 16 / Swift
  6.0 compatibility gate.
- E-430 — 2026-08-06T07:48:27+0200 — Exact-index artifact and configuration
  inspection passed in
  `sentinel-storage/final-exact-index-artifact-config-inspection.log` (106
  lines, 7,116 bytes, SHA-256
  `942e33f83a0294698bc2f495e2895e670e30d40198586905783fbaf881f2b218`).
  All inspected plist, entitlement, and project files linted; the parsed helper
  plist binds `KeepAlive.PathState` exactly to
  `/var/db/lidless/override-active: true`; and the six loose Debug/Release
  App/helper/widget outputs were arm64 Mach-O, minimum macOS 15, SDK 26.5,
  without `LC_CODE_SIGNATURE`, and reported unsigned by `codesign`. Loose
  outputs do not establish bundle identity, entitlement embedding, signed XPC
  trust, ServiceManagement, launchd, or runtime behavior. Project-native
  `xcodebuild`/analyze was not rerun because preserved prior evidence shows
  that path invokes automatic LaunchServices registration, which this task
  prohibits; strict direct compiler analysis is the bounded offline substitute.
- E-431 — 2026-08-06T07:48:27+0200 — Three independent read-only adversarial
  reviews found no remaining production-semantic blocker in the narrowly
  selected `override-active` checkpoint after wording corrections and terminal
  exact-index verification. Their pass is conditional on explicit live
  filesystem, syscall-fault, physical durability, launchd/crash, signed XPC,
  stale-helper, sleep/wake, and hardware gates. They separately confirmed that
  root `HelperLog` can still follow a preexisting symlink, hardlink, or special
  `helper.log`, and that `scheduled-wake.json` shares the broader privileged
  child-storage review; neither can manufacture a metadata-proven sentinel arm,
  so that distinct root cause remains open. Missing/unknown battery telemetry
  permitting an arm without an enforceable floor remains the higher-priority
  next behavioral checkpoint.
- E-432 — 2026-08-06T07:48:27+0200 — Reverified preservation immediately before
  checkpoint preparation. The main checkout remained canonical path
  `/Users/junaid/Xcode-Projects/Lidless`, branch `main`, HEAD
  `7f17aaca11bc6228bed48b9265d63b9e576cdea7`, with clean index/tracked diff,
  the exact three authenticated `.playwright-mcp` files and bytes, status digest
  `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`,
  and empty tracked-diff digest
  `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.
  The feature design remainder remains excluded and byte-exact: decisions
  `cdf6a032f24dc9421f5bbf3e1b696dca7fd37da8bc4d28cf978a302cea03ccd1`,
  progress
  `375b445d73847e60c11f321efe97b2ac636c11f4b962118c14b02d22caacf2d0`,
  and brief
  `4835b0dc2fa44257d2e4aca6429e5bd5ad1cf93989686c709311d91b9659e7f7`.
  No product/helper was launched; no helper install, activation, registration,
  approval, live XPC, `pmset`, sleep-setting, sleep/wake, hardware, plugin,
  connector, Figma, network, merge, push, or main-checkout mutation occurred.
  Exactly the 12 reviewed sentinel code/test/configuration/documentation paths
  plus this append-only ledger are prepared under subject
  `safety: harden recovery sentinel storage`. `State: IN_PROGRESS` is retained;
  after this one local commit the supervisor must bind the exact remainder into
  a fresh rolling manifest before another invocation.

- E-433 — 2026-08-06T07:54:46+0200 — Authenticated and used the checkpoint-aware rolling remainder manifest, whose adjacent sidecar verifies SHA-256 `f890dd24b4510ba30b2eaaa27fbf64c18e30d7cc5b9009fd73f6754817312e5a`. The feature checkout reproduced canonical path `/Users/junaid/Xcode-Projects/Lidless-worktrees/codex-safety-repair-2026-08-04`, linked-worktree/common-directory topology, branch `codex/lidless-safety-repair-2026-08-04`, clean index, and HEAD `39bec0053d0dabca0d5128a093964a3c05d03e3d`. Its exact three-path remainder reproduced every status/type/mode/size/hash record, status digest `3a4984484500650d6b8866b3dfd45bc02ad0ff2888084f86deda5506c36e03dc`, and tracked binary-diff digest `5bfed6a6f1b1f3578736cce1d9ae66138f0f9e0614ffc8e93d0aa80c4d6e3b82`. The main checkout independently remained canonical path `/Users/junaid/Xcode-Projects/Lidless`, branch `main`, clean index, HEAD `7f17aaca11bc6228bed48b9265d63b9e576cdea7`, with exactly its three recorded untracked `.playwright-mcp` files and bytes, status digest `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`, and empty tracked binary-diff digest `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`. This valid rolling audit supersedes any historical-manifest false stop while preserving that earlier evidence. No mismatch or normalization occurred; this invocation resumed at `State: IN_PROGRESS`.

## Battery-telemetry fail-closed checkpoint matrix — 2026-08-06

| ID | Finding or invariant | Independent evidence and disposition | Verdict |
|---|---|---|---|
| S29-01 | An enabled battery floor must never admit or continue a session without usable battery evidence | `BatterySnapshot.hasUsableSafetyEvidence`, `CutoffEngine.assessArm`, and active evaluation now refuse/fire for missing, malformed, contradictory, or out-of-range evidence. An explicit floor opt-out does not invent a telemetry cutoff. | FIXED OFFLINE / LIVE TELEMETRY GATE |
| S29-02 | Power-source enumeration absence is not by itself proof that no internal battery exists | Raw IOPS entries are completely classified through a pure normalizer. Empty/UPS-only enumeration stays unknown unless a readable `IOPMrootDomain` also lacks `AppleClamshellState`; the installed stable SDK explicitly defines that missing property as no clamshell hardware. Unreadable/malformed topology remains unavailable. | FIXED OFFLINE / HARDWARE-TOPOLOGY GATE |
| S29-03 | Battery evidence must be fresh at the arm commit boundary and after a proven helper mutation | Manual, preset, and schedule flows synchronously refresh before dispatch; manual/preset assessments must still equal the confirmed assessment. A second refresh follows a proven helper reply; a nonaccepted result starts verified restoration, and a scheduled occurrence is suppressed only after that proven mutation to prevent arm/restore flapping. | FIXED OFFLINE / XPC-RACE GATE |
| S29-04 | The battery-only “To 20%” endpoint must remain attainable throughout admission | Core policy rejects the preset on a proven no-battery topology at begin, pending refresh, pre-dispatch, and post-reply boundaries. A pending card is withdrawn before rebuild when topology transitions to no battery; other presets/manual/schedule remain attainable. | FIXED OFFLINE / UI-RUNTIME GATE |
| S29-05 | UI/history must distinguish unavailable evidence from proven no-battery state without promising a fictitious floor | Unavailable evidence disables confirmation and shows a telemetry refusal; proven no-battery uses explicit power/no-battery copy and symbols, omits the inactive floor from summaries/charts, and disables the 20% preset. History names telemetry-loss termination. | FIXED OFFLINE / VISUAL GATE |
| S29-06 | New telemetry termination data must remain readable by this version without breaking legacy records | Exact and nested Codable round trips cover the new `CutoffReason`; a legacy off-time payload still decodes. An older app cannot be proven to decode the new enum case. | CURRENT-VERSION PASS / DOWNGRADE GATE OPEN |
| R29-01 | The authenticated design remainder is not implementation authority | `decisions.md`, `progress.md`, and the design-reset brief remain byte-exact to the rolling manifest and are excluded from the checkpoint index. | PRESERVED / EXCLUDED |
| O29-01 | Other independently identified safety groups are not coupled to battery telemetry | Scheduled-wake persistence/replacement, cask uninstall, thermal freshness, crash/session journaling, helper log/storage, stale-helper replacement, and re-arm option handling remain separate root causes. | OPEN — SEPARATE CHECKPOINTS |
| G29-01 | Offline source/tests/unsigned links cannot prove live IOPS/IORegistry behavior, XPC timing, helper restoration, sleep/wake, closed-lid hardware, signing, notarization, or release readiness | No product/helper was launched and no service, sleep setting, hardware, signing, network, or publication action occurred. | LIVE / SIGNED-RUNTIME / HARDWARE GATES OPEN |
| V29-01 | Exact selected bytes require focused/full tests, strict all-product compilation, unsigned Debug/Release links, artifact/config inspection, staged review, and preservation checks | Exact pre-ledger index results and artifacts are recorded in E-437 through E-440; final ledger/index and preservation checks are recorded before the local commit. | PASS OFFLINE / FINAL INDEX REVIEW PENDING |

- E-434 — 2026-08-06T08:41:53+0200 — Independently re-audited the complete
  preserved package and selected only rolling-matrix finding O28-02. The old
  monitor treated an absent internal-battery entry as desktop/AC, accepted
  novel/malformed states by defaulting them to battery, performed unchecked
  percentage arithmetic, and let missing evidence arm or continue with an
  enabled floor. App admission also relied on cached telemetry across await/XPC
  boundaries. Scheduled-wake persistence, cask uninstall, thermal freshness,
  crash/session journaling, helper log/storage, stale-helper replacement, and
  re-arm options remain separate root-cause groups and were not combined.
- E-435 — 2026-08-06T08:41:53+0200 — Added focused regressions before the
  production repair. The first RED exposed 12 issues across 6 tests in
  `battery-telemetry/focused-red.log` (412 lines, 22,235 bytes, SHA-256
  `ee060dc837bdd1f977db3f0b8767c6d2afc3b6f7243c0c0a1c6427e5363db4ce`).
  Adversarial parser/source/admission/post-reply cases exposed 14 issues across
  8 tests in `battery-telemetry/adversarial-red.log` (2,532 lines, 103,619
  bytes, SHA-256
  `35ff103ed47246daf4dcb9e4262ed6ce17b9f161e91263d728a83ace2bd9eeca`).
  Boot/topology, contradictory charging, arithmetic-extreme, priority, symbol,
  and wiring cases exposed 14 issues across 16 tests in
  `battery-telemetry/boot-topology-red.log` (1,598 lines, 69,577 bytes,
  SHA-256
  `76b9b485efd921c1c7422dd358638dc9fb7bb86c68e767ac685609af726e8cbd`).
  A later independent review found that a pending “To 20%” card could become
  contradictory after a no-battery transition; its focused source-ordering RED
  failed before production change in
  `battery-telemetry/pending-preset-transition-red.log` (78 lines, 5,365 bytes,
  SHA-256
  `c01889bce626ec6593398e23e4985237b67675c1fed971a15321b27f99e08d0c`),
  then passed after the core admission/cancellation repair in
  `battery-telemetry/pending-preset-transition-green.log` (60 lines, 4,391
  bytes, SHA-256
  `e98ab297bba2a0cdad86831618ee2c1c71db903ff92b1196049c342d84edf7d9`).
- E-436 — 2026-08-06T08:41:53+0200 — Implemented the narrow repair: typed
  source classification and normalization reject unknown entries, duplicate
  internal sources, invalid capacities, contradictory battery/charging state,
  and extreme time estimates; explicit no-battery state requires both complete
  enumeration and readable no-clamshell topology. The cutoff engine refuses an
  enabled-floor arm and terminates an established enabled-floor session on
  unusable evidence. App admission refreshes before dispatch and after a proven
  reply, with equality fencing for manual/preset intent, allows-arm policy for
  schedule intent, endpoint attainability, verified restoration on post-proof
  rejection, and post-mutation occurrence suppression. Projection arithmetic
  converts before multiplying to avoid `Int` overflow. UI/history/documentation
  now distinguish unavailable evidence, a valid battery, and proven no battery.
- E-437 — 2026-08-06T08:41:53+0200 — Staged exactly 19 selected
  code/test/documentation paths and exported the pre-ledger exact index as tree
  `b4461d9544313e2fae84fcaa8663f7cc7f281946`; its cached binary-diff SHA-256
  was `bc41911ebe95548143168d32f6550b82bebf26641933b32d7f788e4f9b75bc8e`.
  Against that export, all 17 focused battery tests passed in
  `battery-telemetry/exact-focused-tests.log` (124 lines, 9,083 bytes, SHA-256
  `22ab58f185826b6de7099e2ea45718c017bf38fb0cdb6f8545f2e424bc5302d1`),
  and the complete SwiftPM suite passed all 308 tests in 30 suites in
  `battery-telemetry/exact-full-tests.log` (787 lines, 61,964 bytes, SHA-256
  `1be9fe5943d73f57986a2dccaf00367d6fe98027b1acc72bcf43a3b035a353d6`).
  Exact-index Debug and Release core builds passed in
  `battery-telemetry/exact-debug-core-build.log` (42 lines, 3,028 bytes,
  SHA-256
  `1762bbea35595354b05fb2e01a72c0fadd458bf4a8708232922302b3f504fd4d`)
  and `battery-telemetry/exact-release-core-build.log` (12 lines, 1,408 bytes,
  SHA-256
  `110020bf49133196b1b3ef6a8b488a2164511a070f38eaca26715a36c601319b`).
- E-438 — 2026-08-06T08:41:53+0200 — Every exact-index App/helper source
  passed Swift 6 complete strict-concurrency typechecking with warnings as
  errors; both also linked directly in unsigned Debug and optimized Release.
  The initial one-file widget invocations omitted `-parse-as-library` and
  failed only on Swift's `@main` script-mode rule; those superseded commands,
  together with the successful App/helper commands, remain in
  `battery-telemetry/exact-typecheck.log` (27 lines, 3,035 bytes, SHA-256
  `76a134c9ced42ffeafa9a3cb1894c31489e1dd9a1e1dfe7a2d931e5a9c76c38e`)
  and `battery-telemetry/exact-link.log` (61 lines, 8,830 bytes, SHA-256
  `57cd8c9e8b551906899181211a6dd2f43ec94b507b644543f54f75342a1a3a11`).
  Corrected widget strict typecheck and Debug/Release links all passed with the
  required library-parse flag in
  `battery-telemetry/exact-widget-corrected.log` (14 lines, 3,386 bytes,
  SHA-256
  `5ad65b5a9689cb5b5352a74b6e708f637ff3f254c8e7d68a8fe16717e9b55eca`).
  All commands used stable `/Applications/Xcode.app`, Apple Swift 6.3.2,
  language mode 6, complete concurrency, warnings as errors, arm64 macOS 15,
  SDK 26.5, `CODE_SIGNING_ALLOWED=NO`, and linker ad-hoc signing disabled.
  This is compile/link evidence, not runtime or Xcode 16 / Swift 6.0 proof.
- E-439 — 2026-08-06T08:41:53+0200 — Exact artifact inspection is preserved in
  `battery-telemetry/exact-artifact-inspection.log` (282 lines, 26,687 bytes,
  SHA-256
  `247c6f48b567ac2f1a371f0256724014dae46c834bc321f0e35020582cafd814`).
  All six loose App/helper/widget Debug/Release outputs are arm64 Mach-O with
  minimum macOS 15 and SDK 26.5; each `codesign` check reported “code object is
  not signed at all.” The app output contains the linked normalizer/admission
  symbols. Exact source Info plists, entitlements, helper launchd plist,
  ExportOptions, and project file all passed `plutil -lint`; decoded values and
  project bindings were inspected in
  `battery-telemetry/exact-config-inspection.log` (155 lines, 9,948 bytes,
  SHA-256
  `a35fc440bd68d6a7a4a180892c6035f793e5b96c8a935d9b8b5514e4bdb70f7b`).
  The same log records the stable SDK contract: `AppleClamshellState` absent
  means no clamshell on the hardware. Loose outputs are not bundles and do not
  prove embedded identity/entitlements, signed XPC trust, ServiceManagement,
  launchd, IOPS/registry runtime, or hardware behavior. Project-native
  `xcodebuild`/analyze was not retried because preserved prior evidence shows
  that graph invokes automatic LaunchServices registration, prohibited here;
  strict direct compiler analysis is the bounded offline substitute.
- E-440 — 2026-08-06T08:41:53+0200 — Three independent read-only reviews of
  core/topology, App/monitor/UI, and documentation found no remaining concrete
  battery-checkpoint blocker after adversarial fixes and wording corrections.
  Two reviewers separately audited the exact cached diff: all 19 paths are
  coherent battery policy/normalization/admission/presentation/tests/docs,
  modes are 100644, cached diff checks pass, and the three authenticated design
  paths have no cached delta. Their acceptance remains conditional on explicit
  live telemetry/topology, XPC/restoration, sleep/wake, closed-lid hardware,
  downgrade, signed runtime, notarization, and release gates.
- E-441 — 2026-08-06T08:43:12+0200 — Reverified preservation immediately
  before final ledger staging. The main checkout remains canonical path
  `/Users/junaid/Xcode-Projects/Lidless`, branch `main`, HEAD
  `7f17aaca11bc6228bed48b9265d63b9e576cdea7`, with clean index/tracked diff,
  the exact three authenticated `.playwright-mcp` files and bytes, NUL-status
  digest `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`,
  and empty tracked-diff digest
  `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.
  The feature design remainder remains excluded and byte-exact: decisions
  `cdf6a032f24dc9421f5bbf3e1b696dca7fd37da8bc4d28cf978a302cea03ccd1`,
  progress
  `375b445d73847e60c11f321efe97b2ac636c11f4b962118c14b02d22caacf2d0`,
  and brief
  `4835b0dc2fa44257d2e4aca6429e5bd5ad1cf93989686c709311d91b9659e7f7`;
  their NUL-status and tracked binary-diff digests remain the rolling values
  `3a4984484500650d6b8866b3dfd45bc02ad0ff2888084f86deda5506c36e03dc`
  and `5bfed6a6f1b1f3578736cce1d9ae66138f0f9e0614ffc8e93d0aa80c4d6e3b82`.
  No product/helper was launched; no helper install, activation, registration,
  approval, live XPC, `pmset`, sleep setting, sleep/wake, hardware, plugin,
  connector, Figma, network, merge, push, or main-checkout mutation occurred.
  V29-01's pending final-index review is superseded once this append-only ledger
  is restaged and the exact 19-path cached diff/checks pass. The intended local
  checkpoint subject is `safety: fail closed on unavailable battery telemetry`.
  `State: IN_PROGRESS` is retained because separate safety groups and live
  gates remain; after this single local commit the supervisor must bind the
  exact remainder into a fresh rolling manifest before another invocation.

- E-442 — 2026-08-06T08:49:09+0200 — Authenticated and used the
  checkpoint-aware rolling remainder manifest. Its adjacent sidecar names the
  manifest and matches its SHA-256
  `a03e263de660ac95e74e5f89eb0c06d29f3bbfb015c1368348367e5c4c533187`.
  The feature checkout reproduced canonical path
  `/Users/junaid/Xcode-Projects/Lidless-worktrees/codex-safety-repair-2026-08-04`,
  linked-worktree/common-directory topology, branch
  `codex/lidless-safety-repair-2026-08-04`, clean index, and HEAD
  `f105ede34e9c20a025b2d2dfb826286cf4bcfe1d`. Its exact three-path remainder
  reproduced every status, regular-file type, mode, byte count, and raw hash;
  the NUL-status digest was
  `3a4984484500650d6b8866b3dfd45bc02ad0ff2888084f86deda5506c36e03dc`
  and the tracked binary-diff digest was
  `5bfed6a6f1b1f3578736cce1d9ae66138f0f9e0614ffc8e93d0aa80c4d6e3b82`.
  The main checkout independently reproduced canonical path
  `/Users/junaid/Xcode-Projects/Lidless`, branch `main`, clean index, HEAD
  `7f17aaca11bc6228bed48b9265d63b9e576cdea7`, exactly its three recorded
  untracked `.playwright-mcp` files and bytes, NUL-status digest
  `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`,
  and empty tracked binary-diff digest
  `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.
  This valid rolling audit supersedes any historical-manifest false stop while
  preserving the earlier evidence. No mismatch was normalized; work resumes
  at `State: IN_PROGRESS`.

## Thermal-evidence fail-closed checkpoint matrix — 2026-08-06

| ID | Safety invariant | Independently reproduced evidence and bounded result | Verdict |
|---|---|---|---|
| S30-01 | An enabled thermal guard must not admit or continue a session when its configured `pmset` thresholds cannot be proved | `ThermalEvidenceSafety` accepts only structurally meaningful samples dated from now through 180 seconds old. Missing, malformed, future-dated, or older evidence refuses admission and fires the new immediate restoration reason; disabling the guard does not invent a thermal failure. | FIXED OFFLINE / LIVE-TELEMETRY GATE |
| S30-02 | The app must not knowingly arm while either accepted `pmset` evidence or independent `ProcessInfo` pressure is already hot | Core admission refuses warning, speed-limit, serious, and critical pressure. App admission polls after helper proof, copies both signals, rechecks eligibility, and reassesses without another suspension before dispatch; a nonaccepted post-helper result enters verified restoration before a session is created. | FIXED OFFLINE / XPC-RACE AND RUNTIME GATES |
| S30-03 | A convenient nominal field must not mask a recognized malformed, overflowing, or contradictory thermal field | `PMSetParser` first validates every recognized warning/speed/scheduler/CPU-count line and collapses the whole sample to unavailable on malformed numeric syntax, overflow, or conflicting repeated values. Exact parser and validator regressions cover all four field families. | FIXED OFFLINE / REAL-OUTPUT CORPUS GATE |
| S30-04 | A boundary poll must not relabel or accept a request that started before the arm boundary | `pollNow(notBefore:)` serializes commands, awaits older work, reuses it only when its conservative request-start timestamp satisfies the boundary, otherwise loops into a new request, and stamps parsed evidence at request start. It samples `ProcessInfo` at both request start and completion and publishes command failure as unavailable. | FIXED BY SOURCE/CORE TESTS / ASYNC RUNTIME GATE |
| S30-05 | Two thermal sources must share a minimum strike pace without one starving the other | `ThermalStrikeTracker` uses one 45-second global gate, requires distinct violating `pmset` identities, independently advances sustained serious/critical `ProcessInfo` pressure, defers rather than consumes a distinct sample arriving inside the gate, and resets on recovery or guard disable. | FIXED OFFLINE / LIVE-TIMING GATE |
| S30-06 | Presentation and persisted history must expose unavailable evidence without implying protection is active | Pending confirmation refuses unavailable/hot states with actionable copy and suppresses the misleading safety-summary checkmark; live status/history name unavailable thermal evidence, and the new cutoff reason round-trips through current-version `Codable`. No rendering or app launch was authorized. | CURRENT-VERSION PASS / VISUAL AND DOWNGRADE GATES OPEN |
| V30-01 | Selected checkpoint bytes require exact-index focused/full tests, strict all-product checks, unsigned Debug/Release links, artifact/config inspection, staged review, and preservation checks | Discriminating working-tree RED/GREEN and a complete 320-test pass are recorded below. Exact-index results remain pending until the selected paths are staged and exported independently of the authenticated design remainder. | PENDING EXACT-INDEX VERIFICATION |

The checkpoint is limited to thermal evidence availability, admission, polling,
parsing, debounce, restoration routing, and truthful presentation. The
separately audited scheduled-wake replacement/persistence transaction and
session ownership/re-arm journal findings remain open for later checkpoints.
The three authenticated design-remainder paths are not part of this checkpoint.

### Thermal checkpoint append-only evidence log (continued)

- E-443 — 2026-08-06T09:23:47+0200 — Before production edits, the literal
  required `swift test --package-path Packages/LidlessCore` reached the
  installed Xcode-beta toolchain but failed because it selected unwritable
  `/Users/junaid/.cache/clang/ModuleCache`; the complete six-line diagnostic is
  `verification-2026-08-06-thirtieth/swift-test-literal-baseline.log` (2,347
  bytes, SHA-256
  `5025cff502cd16888fea556b738efd6d6c035c9baf7a7a298bd6e414d17356c9`).
  The same baseline run through the established stable Xcode 26.5 toolchain
  with workspace-local SwiftPM/module caches passed all 308 tests in 30 suites;
  `swift-test-stable-baseline.log` is 784 lines / 61,256 bytes, SHA-256
  `7df6221302260ead0f11304fd5dae429c07c64457111fc80c7ad0f480c98a642`.
- E-444 — 2026-08-06T09:23:47+0200 — Complete-diff tracing confirmed one
  coherent thermal root-cause group: the preserved package treated absent,
  empty, stale, or future `pmset` data as nominal; arm admission could proceed
  on known-hot evidence; a periodic poll could be accepted across the arm
  boundary; recognized malformed fields could be masked by a nominal note; and
  the two thermal sources did not have one source-aware global strike gate.
  Scheduled-wake replacement/persistence and session ownership/re-arm state
  were independently classified as separate root-cause groups and intentionally
  excluded from this invocation.
- E-445 — 2026-08-06T09:23:47+0200 — The first focused regression against the
  unsafe implementation ran six thermal tests and failed with 14 issues across
  unavailable evidence, monitor failure publication, and App boundary wiring.
  `thermal-telemetry-focused-red.log` is 7,265 lines / 289,098 bytes, SHA-256
  `caa252e8dc3b185253e025f15ab2b528993610845be0e300b3d24fa47305eb40`.
  A hardened 11-test follow-up reproduced five remaining issues for knowingly
  hot admission, boundary coalescing, and strike progression;
  `thermal-expanded-focused-red.log` is 293 lines / 14,252 bytes, SHA-256
  `df41b70900152768b4d3413a1ca76c1cfb7e69923168019576b523ea4c6c6979`.
- E-446 — 2026-08-06T09:23:47+0200 — A final adversarial 12-test RED reproduced
  nine issues: three boundary-poll source assertions, one App boundary
  assertion, and five malformed/contradictory parser outputs that were still
  accepted. `thermal-boundary-parser-focused-red.log` is 2,772 lines / 112,606
  bytes, SHA-256
  `052d6437d24823b84687a51821c27cd951c3819e1fa615404192779cb5d5ae32`.
  An intermediate complete run (`thermal-working-full-1.log`, 899 lines /
  72,082 bytes, SHA-256
  `0cdbc29bda11bab0c8c280d6ea6ca4e774738bcf870772d46a851e4578a2c59f`)
  failed 19 assertions; independent triage traced all 19 to old tests whose
  fixed thermal fixture was now stale at later evaluation times or whose
  priority/source-string expectation omitted the new case. The fixtures were
  made fresh at each evaluation without weakening production freshness.
- E-447 — 2026-08-06T09:23:47+0200 — The bounded implementation adds a pure
  freshness/structure validator and strike tracker, fail-closed admission and
  evaluation cases, whole-sample recognized-field parser validation,
  request-boundary-aware serialized polling, pre-dispatch and post-proof App
  reassessment, restoration/history routing, and truthful functional UI copy.
  README and architecture wording limits the claims to requested offline
  behavior. The design-quality doctrine was applied only to the changed
  functional states; the explicit no-launch/no-redesign scope leaves visual
  rendering and interaction inspection open.
- E-448 — 2026-08-06T09:23:47+0200 — The hardened working-tree GREEN passed all
  12 thermal tests (`thermal-boundary-parser-focused-green.log`, 113 lines /
  7,650 bytes, SHA-256
  `4adb43c91f3816c3dcce41629febdc477e35bfbccba6253e9a48550444ec4822`)
  and all 32 parser tests (`pmset-parser-focused-green.log`, 179 lines / 14,324
  bytes, SHA-256
  `71fe73723324ce7f514667a2dd982b6c526b70aa75da8e1d3c51649a66e881e1`).
  Related compatibility runs passed 51 cutoff tests and 17 battery-safety tests
  in `cutoff-focused-final2.log` (191 lines / 13,452 bytes, SHA-256
  `6a38c50453f1a11f3e2df02f562cd2f4967a229d54151936106ac3b2ab54837d`)
  and `battery-compatibility-focused-final2.log` (123 lines / 8,459 bytes,
  SHA-256
  `1e81dbd75b245f86e76dffb8895040f01adfff51a60348ada87430e55ecd9d88`).
  The latest complete working tree passed all 320 tests in 31 suites;
  `thermal-working-full-final.log` is 812 lines / 63,512 bytes, SHA-256
  `e7290a9ba9cab7462fd08217b7181b6153436a8eab4bcbb72022681f98f1ee81`.
- E-449 — 2026-08-06T09:23:47+0200 — Two command-harness mistakes are retained
  as non-evidence: display-name filters selected zero tests, and the first
  product typecheck reused zsh's read-only `modules` parameter. Corrected
  type-name filters produced the accepted focused runs above; a corrected
  working-tree typecheck then covered 25 App, four helper, and one widget source
  files. Because parser and boundary work advanced afterward, only the upcoming
  exact-index typecheck is authoritative for the checkpoint.
- E-450 — 2026-08-06T09:23:47+0200 — Three independent read-only audits covered
  the selected thermal policy/App/UI/docs, scheduled-wake boundary, and session
  ownership boundary. The final adversarial thermal re-review found no remaining
  Blocker/High issue after request-start stamping, older-poll rejection,
  whole-sample parser invalidation, hot-arm refusal, post-proof reassessment,
  global strike pacing, and deferred distinct-sample handling; `git diff
  --check` also passed. Runtime concurrency, real `pmset` output, signed XPC,
  restoration, sleep/wake, hardware, and visual behavior remain explicitly
  unproved.

### Thermal checkpoint exact-index completion

| ID | Verification | Exact result | Verdict |
|---|---|---|---|
| V30-02 | Exact selected policy and compatibility suites plus complete package suite | Pre-final-ledger index tree `ea9ac365d57be93dc7a84a363f84a9c8f5413912` passed 12 thermal, 32 parser, 51 cutoff, 17 battery-safety, and all 320 package tests in 31 suites under stable Xcode 26.5. The literal required invocation separately reproduced only the default Xcode-beta unwritable-cache failure. | PASS FOR EXACT SELECTED CODE |
| V30-03 | Exact Debug/Release compile and strict static checks | Core built in Debug and optimized Release with signing disabled. All 25 App, four helper, and one widget sources passed Swift 6 complete-concurrency typechecking with warnings-as-errors; all three products linked in Debug and optimized Release with ad-hoc linker signing disabled. | PASS FOR EXACT OFFLINE SOURCES / XCODE GRAPH OPEN |
| V30-04 | Actual loose artifacts, linked thermal symbols, and source configuration | Six outputs are thin arm64 macOS 15 / SDK 26.5 executables with no `LC_CODE_SIGNATURE` and each reports not signed. The Debug App contains the validator, strike tracker, and boundary-poll symbols. Six exact source plist/entitlement files and the project file linted; decoded source values and project bindings were inspected. | PARTIAL — NOT BUNDLES; SIGNING/XPC/RUNTIME GATES OPEN |
| V30-05 | Staged selection, independent review, and preservation | Sixteen intended 100644 paths are staged; cached checks passed and the non-ledger binary diff is fixed below. Independent review found no Blocker/High issue. The three authenticated design paths are excluded and byte-exact; the main checkout exactly reproduces its rolling-manifest state. | PASS BEFORE LOCAL CHECKPOINT |

- E-451 — 2026-08-06T09:31:10+0200 — Exported the staged index, independently
  of unstaged working bytes, as tree
  `ea9ac365d57be93dc7a84a363f84a9c8f5413912`. The exact literal
  `swift test --package-path …/Packages/LidlessCore` failed only at the default
  Xcode-beta cache path (`exact-index-literal-swift-test.log`, six lines / 2,414
  bytes, SHA-256
  `42d614d2184cb9d3981aa515b5422b09815bd8a4d9a5133758ad62bf795136c5`).
  The stable, workspace-cached exact run passed all 320 tests in 31 suites;
  `exact-index-full-swift-test.log` is 812 lines / 63,496 bytes, SHA-256
  `ea0eafbdcccf09e4595a540cb52f8bdfc12ddbbd471650d0dfae3eb741e4b27b`.
- E-452 — 2026-08-06T09:31:10+0200 — Exact focused suites passed: thermal 12/1
  (`exact-index-thermal-focused.log`, 113 lines / 7,634 bytes, SHA-256
  `912f19a104bcdb31b2c163772147757f7e3fdb3b70d151891ac1d1d5be80b9be`),
  parser 32/1 (`exact-index-pmset-parser-focused.log`, 179 lines / 14,317
  bytes, SHA-256
  `1733fe562096ba6da914a4f625827becae206d2eba3a6b6b58d2e4e79d5ab4cc`),
  cutoff 51/1 (`exact-index-cutoff-focused.log`, 191 lines / 13,444 bytes,
  SHA-256
  `87f3506e5ca3122bb963ffd62579b0984f44a1c90c469282f5b163a9e10b3252`),
  and battery compatibility 17/1
  (`exact-index-battery-compatibility-focused.log`, 123 lines / 8,465 bytes,
  SHA-256
  `9389f28d0d83371b51569bf2f4b32b1c9d10c0232c070224caaa194d805b652d`).
- E-453 — 2026-08-06T09:31:10+0200 — Exact Core Debug and optimized Release
  builds passed with `CODE_SIGNING_ALLOWED=NO`; their logs are 40 lines / 2,368
  bytes / SHA-256
  `e90d6879506af406f5f2b7fc8845dbc163e9e9777310f096915d18cdb524334f`
  and nine lines / 682 bytes / SHA-256
  `e9cfb930c70916ff2e32984570e5e0a9dd345569a12d68a31d78ded1705f794a`.
  Exact Swift 6 complete-concurrency typechecking with warnings-as-errors passed
  25 App, four helper, and one widget source files
  (`exact-index-all-products-typecheck.log`, four lines / 112 bytes, SHA-256
  `671c1b6b19345fba7395b3602ea039ec152e947de2c5bc3ae1effc6f31d36f71`).
  Direct Debug and optimized Release linking of all three products passed with
  both signing controls disabled; the complete command logs are six lines /
  27,996 bytes / SHA-256
  `59dcd85e5ac442aa73f2614d46e4091f85d6fc696f2a656bdfd3c331da4c2b50`
  and six lines / 28,460 bytes / SHA-256
  `66b878e4ff781275b03eab8a9f794256368d79a0bcb767bb0709f9185be7a5a3`.
- E-454 — 2026-08-06T09:31:10+0200 — Exact artifact inspection is preserved in
  `exact-index-artifact-inspection.log` (244 lines / 22,913 bytes, SHA-256
  `c4c99e8855acd445417b6f1b2e438a4f4785a373061a582cd437d45c3d8f55a9`).
  All six loose outputs are arm64 Mach-O executables with minimum macOS 15.0
  and SDK 26.5, have no `LC_CODE_SIGNATURE`, and return `codesign` exit 1 with
  “code object is not signed at all.” Corrected symbol inspection proves the
  Debug App linked `ThermalEvidenceSafety.accepted`,
  `ThermalStrikeTracker.observe`, and `PMSetThermalMonitor.pollNow(notBefore:)`;
  `exact-index-symbol-inspection-final.log` is 94 lines / 12,379 bytes, SHA-256
  `489090c17f5d09d76a0b78c1c73043c82540684fe82e4f401e1b15a8728966d7`.
  The preceding symbol command asked for a synthesized enum-case symbol that
  is not emitted by name and is retained as non-evidence.
- E-455 — 2026-08-06T09:31:10+0200 — Six exact source plist/entitlement files
  and `project.pbxproj` passed `plutil -lint`; their decoded values and selected
  project bindings are preserved in
  `exact-index-configuration-inspection.log` (153 lines / 8,869 bytes, SHA-256
  `292779edab4206b03bcf26229403d721b8cbf375840160530da48808eecf8ae9`).
  Project-native `xcodebuild`/analyze was not retried because preserved evidence
  shows that graph triggers automatic LaunchServices registration, expressly
  prohibited here. Direct strict compiler analysis is the bounded substitute.
  Loose outputs are not bundles and prove no embedded configuration,
  entitlement, signing identity, XPC trust, ServiceManagement behavior,
  launchd behavior, runtime behavior, notarization, or release readiness.
- E-456 — 2026-08-06T09:31:10+0200 — Independent cached-diff review covered all
  16 selected 100644 paths, found no Blocker/High issue, confirmed `git diff
  --cached --check`, and confirmed no authenticated design path was staged.
  Before this final ledger-only append, the reviewed full cached binary-diff
  digest was
  `656ea6357d88e171ef46e44bfe7d02ccd86c093b4160debe0c1d41bf98b7099b`;
  the staged non-ledger binary-diff digest is
  `4125a119307e70340aa7edef504eeee179fc446a72bf02254ffc7075307a60d9`.
  The remaining lower-risk caveat is explicit: poll concurrency is structurally
  pinned and compiled, not executed through an injected async runner.
- E-457 — 2026-08-06T09:31:10+0200 — Pre-commit preservation reverified the
  feature canonical/linked topology, common directory, branch, and unchanged
  HEAD `f105ede34e9c20a025b2d2dfb826286cf4bcfe1d`. All three design-remainder
  paths remain unstaged and reproduce their rolling status, mode, byte count,
  raw hash, NUL-status digest
  `3a4984484500650d6b8866b3dfd45bc02ad0ff2888084f86deda5506c36e03dc`,
  and tracked binary-diff digest
  `5bfed6a6f1b1f3578736cce1d9ae66138f0f9e0614ffc8e93d0aa80c4d6e3b82`.
  The main checkout remains canonical path `/Users/junaid/Xcode-Projects/Lidless`,
  branch `main`, HEAD `7f17aaca11bc6228bed48b9265d63b9e576cdea7`, clean
  index/tracked diff, and exactly its three recorded `.playwright-mcp` files and
  bytes; its rolling digests remain
  `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`
  and `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.
  The complete preservation log is 33 lines / 2,170 bytes, SHA-256
  `39ca4048c35d430cd3cfca63d24a1d42ec8f1f4af3f18b91f1d4875277cfcf9a`.
- E-458 — 2026-08-06T09:31:10+0200 — This append-only ledger is the only staged
  content changed after exact source export. `State: IN_PROGRESS` is retained:
  this thermal group is coherent for one local checkpoint, while separately
  scoped safety groups and every live/hardware gate above remain open. The
  intended local subject is `safety: fail closed on unsafe thermal evidence`.
  No product/helper was launched; no install, activation, registration,
  approval, live XPC, `pmset`, sleep-setting mutation, sleep/wake, hardware,
  plugin, connector, Figma, network, merge, push, or main-checkout mutation was
  performed. After this single commit, the supervisor must authenticate a new
  rolling remainder before any later invocation.

## Thirty-first invocation — authenticated recovery

| ID | Recovery or review surface | Independently reproduced evidence | Verdict |
|---|---|---|---|
| R31-01 | Checkpoint-aware recovery authority | The adjacent rolling-manifest sidecar names the manifest and verifies SHA-256 `5c74d08d1b9ed376d90496f63b92d239750bcb5b95d47cab5b1cd6365619f820`. The historical manifest was read but was not used as a post-checkpoint authority. | PASS |
| R31-02 | Feature worktree identity and exact remainder | Canonical path, registered linked-worktree topology, common Git directory `/Users/junaid/Xcode-Projects/Lidless/.git`, branch `codex/lidless-safety-repair-2026-08-04`, HEAD `f03e50c63798ac6897fcc5850357bb31545f8cc5`, and clean index all match. The exact three regular-file entries reproduce status, mode `0644`, byte count, and raw SHA-256; the NUL-status digest is `3a4984484500650d6b8866b3dfd45bc02ad0ff2888084f86deda5506c36e03dc` and the tracked binary-diff digest is `5bfed6a6f1b1f3578736cce1d9ae66138f0f9e0614ffc8e93d0aa80c4d6e3b82`. | PASS |
| R31-03 | Main-checkout preservation | Canonical main path, topology, branch `main`, HEAD `7f17aaca11bc6228bed48b9265d63b9e576cdea7`, and clean index/tracked diff match. Exactly the three recorded `.playwright-mcp` regular files reproduce status/mode/size/hash; the NUL-status digest is `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18` and the tracked binary-diff digest is the empty SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`. | PASS |
| R31-04 | Mandatory source and instruction recovery | The canonical handoff and original manifest reproduce their required SHA-256 values and were read in full with the rolling manifest, sidecar, progress log, decision log, architecture, and design-reset brief. No repository-local `AGENTS.md`, `CLAUDE.md`, or equivalent instruction file exists. | PASS |
| R31-05 | Authenticated design-history remainder | `Docs/orchestration/decisions.md`, `Docs/orchestration/progress.md`, and the untracked design-reset brief remain preserved evidence rather than safety implementation authority. They are excluded from product-source selection unless an independently justified documentation checkpoint requires them. | PRESERVED / EXCLUDED |
| A31-01 | Next coherent safety root cause | The complete committed package and the previously named scheduled-wake, session/re-arm, stale-helper, privileged-storage, and removal/release surfaces are being independently re-audited. A previous verdict is not accepted without current code/test reproduction. | IN PROGRESS |
| V31-01 | Exact checkpoint verification | Focused RED/GREEN, complete SwiftPM output, unsigned Debug/Release evidence, static/config/artifact inspection, staged-diff review, and final preservation checks depend on selecting and repairing one confirmed root cause. | PENDING |

- E-459 — 2026-08-06T10:04:21+0200 — Recovery used exactly the authenticated
  rolling manifest. Every feature and main-checkout field required by the
  recovery gate was independently reproduced before this first edit; no extra,
  missing, or changed path or byte was found. The ledger already began with the
  required `State: IN_PROGRESS`, branch, and starting-HEAD lines, so they were
  preserved without rewrite. This append resumes its evidence log. No product
  or helper was launched; no install, activation, registration, approval,
  `pmset`, sleep-setting, sleep/wake, hardware, design, Figma, plugin,
  connector, network, merge, push, or main-checkout mutation was performed.
- E-460 — 2026-08-06T09:37:48+0200 — Timestamp correction: E-459's heading
  was composed with an unverified future wall-clock value. The first subsequent
  local `date` read was `2026-08-06T09:37:48+0200`; E-459's recovery facts are
  retained, but its timestamp is not accepted as evidence. This correction is
  appended rather than rewriting the earlier entry.

## Helper-session ownership checkpoint matrix — 2026-08-06

| ID | Safety invariant or verification | Independently reproduced evidence and bounded result | Verdict |
|---|---|---|---|
| S31-01 | An active sleep-override session cannot be re-armed to transfer supervision or extend its deadline | `handleArm` requires a concrete bridge connection identity and rejects whenever the queue-owned sentinel is active, before TTL processing, snapshots, sentinel writes, owner/deadline assignment, or `pmset`. The former active-session mutation/success path is absent. | FIXED OFFLINE / LIVE-XPC GATE |
| S31-02 | Only the exact connection that established a fresh session may renew its watchdog | The bridge passes its captured `ObjectIdentifier` into heartbeat handling. A pure ownership policy rejects no-session, missing-owner, and different-owner requests before either diagnostic or monotonic deadline mutation; exact-owner renewal alone proceeds. | FIXED OFFLINE / IDENTITY-LIFETIME GATE |
| S31-03 | Ownership hardening must retain de-risking recovery and owner-loss restoration | Disarm and repair remain available to any authenticated connection. The existing connection-end path still compares the invalidated identity with the active owner before restoring, while abort, restore, and parked-recovery paths clear ownership. | SOURCE-VERIFIED / INVALIDATION-RUNTIME GATE |
| S31-04 | An older helper must not be accepted as implementing the new ownership behavior | The producer literal and app-required helper safety revision independently advance from 5 to 6. Revision tests reject missing, 0...5, and future 7 while accepting 6 through the existing arm/restore/ownership proof wrappers. This remains self-reported compatibility metadata, not binary attestation. | FIXED OFFLINE / INSTALL-RECEIPT GATE |
| V31-02 | The focused defect must be discriminating, then pass with related and complete coverage | The pre-production source regression failed against the old implementation with ten issues. Exact-index verification later passed 35 focused tests in six suites and all 325 package tests in 32 suites. | PASS FOR EXACT STAGED CODE |
| V31-03 | Exact Debug/Release compilation and bounded static analysis | Core built in Debug and optimized Release with signing disabled. All 25 App, four helper, and one widget sources passed Swift 6 complete-concurrency typechecking with warnings-as-errors; each product linked in Debug and optimized Release with linker ad-hoc signing disabled. | PASS FOR OFFLINE SOURCES / XCODE GRAPH OPEN |
| V31-04 | Actual loose artifacts and source configuration must match only the claims made | Six exact outputs are arm64 Mach-O executables targeting macOS 15.0 / SDK 26.5, contain no `LC_CODE_SIGNATURE`, and report unsigned. Ownership/heartbeat symbols are linked in both helper outputs. Six source plist/entitlement files and `project.pbxproj` linted and their decoded values/bindings were inspected. | PARTIAL — NOT BUNDLES OR ATTESTATION |
| V31-05 | Selected bytes, authenticated remainder, and main checkout remain isolated | Pre-ledger exact index tree `67b15dd13c55bb33ab3ffdacdbdef78c774fa6e9` contains only nine selected 100644 code/test/doc paths. The three rolling-remainder design paths remain unstaged and byte-exact; the main checkout reproduces every recorded field and byte. | PASS BEFORE LOCAL CHECKPOINT |

This checkpoint is limited to active helper-session connection ownership,
watchdog-renewal admission, the associated behavior-revision boundary, tests,
and architecture wording. Scheduled-wake transaction durability, crash-session
journal timing, automatic-confirm intent fencing, stale-helper replacement,
Homebrew removal/upgrade safety, privileged child storage, and every live gate
remain separate work. `State: IN_PROGRESS` therefore remains authoritative.

### Helper-session ownership append-only evidence log (continued)

- E-461 — 2026-08-06T09:58:24+0200 — Before production edits, the literal
  required `swift test --package-path Packages/LidlessCore` reached the default
  Xcode-beta toolchain but failed at its unwritable
  `/Users/junaid/.cache/clang/ModuleCache`; the complete output is
  `verification-2026-08-06-thirty-first/swift-test-literal-baseline.log` (six
  lines / 2,347 bytes, SHA-256
  `03608d31562dac315f97125d584653485eeb4599ab5f4db3e334a001cb818214`).
  The established stable toolchain with workspace-local caches and SwiftPM's
  sandbox disabled passed the unchanged baseline's 320 tests in 31 suites;
  `swift-test-stable-baseline-final.log` is 812 lines / 63,496 bytes, SHA-256
  `57f1f8e8de9a1f8d9756e1bed02d872c776edc045edfc0dbd363b943ac0437ac`.
- E-462 — 2026-08-06T09:58:24+0200 — Current source tracing confirmed the
  selected root cause: any accepted connection could successfully re-arm an
  active session, replace `armedConnectionID`, and renew its deadline, while
  heartbeat carried no connection identity. Owner invalidation restored only
  while that original identity remained owner. The focused source regression
  was added before production changes and failed on the old implementation as
  one test / one suite with ten issues;
  `helper-session-ownership-red.log` is 1,346 lines / 63,024 bytes, SHA-256
  `7c7798d9e6a45ae5fc84aeb3a1ed026430f01f27c856e33b81e98a2a698c948c`.
- E-463 — 2026-08-06T09:58:24+0200 — The bounded repair adds a pure arm and
  heartbeat ownership policy, rejects every active-session arm before any
  risk-increasing work, threads the bridge identity into heartbeat, gates both
  deadline writes on exact ownership, updates the XPC contract wording, and
  advances independent producer/consumer safety revisions to 6. Recovery-only
  disarm/repair access is intentionally unchanged. Structural regressions pin
  rejection before sentinel, owner, deadline, and `pmset` mutations; fresh
  ownership before enable/success; non-owner return before both renewals; and
  owner comparison before invalidation restore.
- E-464 — 2026-08-06T09:58:24+0200 — Initial working-tree GREEN passed ten
  ownership/source tests (`helper-session-ownership-focused-green.log`, 83
  lines / 5,598 bytes, SHA-256
  `42d33fb9cc029292587a66ea01fcfa722a8cd420ea2303be6d85b224bd6c268b`),
  25 related revision/removal/recovery/presentation tests
  (`helper-session-ownership-related-green.log`, 75 lines / 5,816 bytes,
  SHA-256
  `6f33072ea8b2bead498d5e72b04d37d9551b2f247d1181cb8bfd4741b7c63d62`),
  and all 325 tests in 32 suites (`swift-test-full-working-green.log`, 754
  lines / 60,097 bytes, SHA-256
  `50094182f09979a3885a6c09276622338a9242ada731e55678286b56e0310f05`).
  Strengthening two source assertions first produced a test-only `Substring`
  compile error; `helper-session-ownership-tightened-green.log` is retained as
  non-evidence. Converting those helper inputs to `String` fixed the harness,
  and the final ten-test focused run passed in
  `helper-session-ownership-tightened-green-final.log` (51 lines / 3,510
  bytes, SHA-256
  `ec7fbb0096bfa17e8e6cf659d52236a2aad5de8b9169a7dc304d54a4b74d968e`).
- E-465 — 2026-08-06T09:58:24+0200 — Three independent read-only reviews found
  no concrete Blocker/High regression after the strengthened ordering tests.
  They independently confirmed active-arm rejection, exact-owner heartbeat,
  bridge identity propagation, owner invalidation recovery, cleanup of owner
  state, revision-6 consistency, and preserved de-risking operations. Their
  bounded artifact caveat is accepted: release scripts and a signed artifact
  do not prove the embedded helper's revision semantics or source-to-binary
  provenance, so no such claim is made here.
- E-466 — 2026-08-06T09:58:24+0200 — The nine selected non-ledger paths were
  staged alone and exported as exact index tree
  `67b15dd13c55bb33ab3ffdacdbdef78c774fa6e9`. The exact literal command again
  reproduced only the default Xcode-beta unwritable-cache failure
  (`exact-index-literal-swift-test.log`, six lines / 2,419 bytes, SHA-256
  `fb66ede62613d5aa0efa9a15ab8b1b39671bdf342ea92f9309319cef48e2c5c6`).
  Under the stable workspace-cached invocation, 35 focused tests in six suites
  passed (`exact-index-ownership-focused.log`, 171 lines / 12,077 bytes,
  SHA-256
  `664954424b446b4882519bd59db9539676459ef58d24cd831caedd3f4e08c5ff`),
  followed by all 325 tests in 32 suites
  (`exact-index-full-swift-test.log`, 826 lines / 64,537 bytes, SHA-256
  `9e2074d2e343eb821072b4216ad3bd875813f534f84bd53cef4c3c27aba189ac`).
- E-467 — 2026-08-06T09:58:24+0200 — Exact Core Debug and optimized Release
  builds passed with both signing controls disabled; their logs are 41 lines /
  2,433 bytes / SHA-256
  `da63518dfd39eaed39d90073e26c7c5458d203e81e4cd7bbf70cc1e99f0b6dcc`
  and nine lines / 682 bytes / SHA-256
  `f6c4a966804833fe434728c1a8dfe2fe08a7f878e823c144c303f38c0d6c545b`.
  Exact Swift 6 complete-concurrency typechecking with warnings-as-errors passed
  25 App, four helper, and one widget sources
  (`exact-index-all-products-typecheck.log`, four lines / 112 bytes, SHA-256
  `671c1b6b19345fba7395b3602ea039ec152e947de2c5bc3ae1effc6f31d36f71`).
  Direct Debug and optimized Release links of all three products passed with
  `CODE_SIGNING_ALLOWED=NO`, `CODE_SIGNING_REQUIRED=NO`, and linker ad-hoc
  signing disabled; their logs are four lines / 168 bytes / SHA-256
  `0c113b49443fbefd8b6d78f40bc3c0de1da24f2751c0c91699693bb42d767f91`
  and four lines / 170 bytes / SHA-256
  `74d85f7dbfbb286b825f95e8cd3a7df2acbbd76a5f8e51c2699630f019775a07`.
  Project-native `xcodebuild`/analyze was not invoked because live automatic
  registration is outside authorization; direct strict compiler analysis is
  the bounded static substitute.
- E-468 — 2026-08-06T09:58:24+0200 — Exact artifact inspection is preserved in
  `exact-index-artifact-inspection.log` (96 lines / 8,592 bytes, SHA-256
  `86791ce47c4ba830938451f50e1f34d2fec4113abd64f9df06e8d4e6504e87a7`).
  All six loose outputs are arm64 Mach-O executables with minimum macOS 15.0 /
  SDK 26.5, zero `LC_CODE_SIGNATURE` commands, and expected unsigned
  `codesign` results. Both helper configurations expose the ownership-policy,
  identity-bearing heartbeat handler, and bridge-heartbeat symbols. Six exact
  source plist/entitlement files and `project.pbxproj` passed `plutil -lint`;
  decoded values, selected bindings, and revision/ownership source bindings
  are in `exact-index-configuration-inspection.log` (163 lines / 7,816 bytes,
  SHA-256
  `3261053d606dda4755a27a5f30f997f5bf075910878ab0bc0154a0936f6fd251`).
  These are loose products and source configuration, not bundle, entitlement,
  signature, XPC-trust, ServiceManagement, runtime, notarization, or release
  proof.
- E-469 — 2026-08-06T09:58:24+0200 — Every staged source/test/doc hunk was
  reviewed; `git diff --cached --check` passed. Before this ledger append, the
  exact non-ledger binary-diff digest was
  `90fe7bb6b0199746188ee11f6e8ec45c6819763f24b24402e6f4bd8db602e1f9`
  and its NUL name-list digest was
  `c81dd726374653d7eeb82d91a1aaae72a53da2229449ae8c45b48c103d0e0cf2`.
  A first preservation command collapsed the main checkout's untracked
  directory and is retained in `precommit-preservation.log` as non-evidence.
  The corrected canonical `--untracked-files=all` run passed in
  `precommit-preservation-final.log` (49 lines / 2,999 bytes, SHA-256
  `49e873a794f3b34ccdb29da9b0fb65391d9c6aedb4e2a05f1e48af89771642a7`).
  Feature topology/branch/HEAD remained exact; all three design paths retained
  their recorded status, 0644 mode, byte count, hash, NUL-status digest
  `3a4984484500650d6b8866b3dfd45bc02ad0ff2888084f86deda5506c36e03dc`,
  and tracked binary-diff digest
  `5bfed6a6f1b1f3578736cce1d9ae66138f0f9e0614ffc8e93d0aa80c4d6e3b82`.
  The main checkout remained `main` at
  `7f17aaca11bc6228bed48b9265d63b9e576cdea7`, with clean index/tracked diff
  and its exact three `.playwright-mcp` records, NUL-status digest
  `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`,
  and empty tracked binary-diff digest.
- E-470 — 2026-08-06T09:58:24+0200 — `State: IN_PROGRESS` is retained because
  separately confirmed scheduled-wake persistence, crash-session journaling,
  auto-confirm intent, stale-helper replacement, Homebrew removal/upgrade, and
  privileged child-storage groups remain open. Real NSXPC identity and
  invalidation ordering, `ObjectIdentifier` lifetime/reuse, duplicate app
  processes, watchdog timing, helper replacement, signed XPC trust,
  ServiceManagement, actual `pmset` arm/restore, sleep/wake, closed-lid
  hardware, notarization, and release readiness remain unproved. The intended
  single local checkpoint subject is
  `safety: bind helper supervision to session owner`. No app/helper was
  launched; no install, activation, registration, approval, live XPC, `pmset`,
  sleep-setting mutation, sleep/wake, hardware, plugin, connector, Figma,
  network, merge, push, or main-checkout mutation was performed. After this
  commit, the supervisor must authenticate a fresh rolling remainder before a
  later invocation.

## Recovery audit and independent package re-verification — 2026-08-06

| ID | Recovery or verification surface | Independently reproduced evidence | Verdict |
|---|---|---|---|
| R32-01 | Required source records | The canonical handoff and original manifest reproduce SHA-256 `95bdacdde663c642c2f97d532c1ec2b931e94a7dfcda47b8031e011ab3944831` and `d84065171a261e24ae574b98164132472ff1e8bb635647403d814b9fcf58c36a`. The rolling manifest sidecar validates its authoritative JSON at SHA-256 `ffdd7a2bf13d7a24d50a695e212aa53aee09e824e340e069a698b6a51a583fbd`. All required handoff, manifest, orchestration, architecture, design-brief, and repository contribution instructions were read completely before this edit. No repository-local `AGENTS.md`, `CLAUDE.md`, or other agent instruction file is present. | PASS |
| R32-02 | Feature-worktree identity and topology | Canonical path is the required isolated worktree; it is a non-bare linked worktree on `codex/lidless-safety-repair-2026-08-04` at `dcfefde87693e6f3a66d428a6fbede3e3cd7a582`. Its administrative directory is `/Users/junaid/Xcode-Projects/Lidless/.git/worktrees/codex-safety-repair-2026-08-04`, common directory is `/Users/junaid/Xcode-Projects/Lidless/.git`, and its index was clean. | PASS |
| R32-03 | Complete feature remainder | Before this first edit, the only dirty paths were ` M Docs/orchestration/decisions.md`, ` M Docs/orchestration/progress.md`, and `?? Docs/orchestration/tasks/2026-08-04-design-reset-brief.md`. Their regular-file type, mode `0644`, byte counts `4591`/`5774`/`7188`, and SHA-256 values exactly matched the rolling manifest. The complete NUL-status digest was `3a4984484500650d6b8866b3dfd45bc02ad0ff2888084f86deda5506c36e03dc`; the tracked binary-diff digest was `5bfed6a6f1b1f3578736cce1d9ae66138f0f9e0614ffc8e93d0aa80c4d6e3b82`. | PASS |
| R32-04 | Main-checkout preservation | The canonical main checkout remained a non-bare worktree on `main` at `7f17aaca11bc6228bed48b9265d63b9e576cdea7`, with clean index, empty tracked binary diff, and exactly the three recorded untracked `.playwright-mcp` files. Every type, mode, size, and raw hash matched; the complete NUL-status digest was `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`. | PASS |
| A32-01 | Complete checkpointed package | All commits and the full diff from starting HEAD through `dcfefde87693e6f3a66d428a6fbede3e3cd7a582` are under fresh adversarial review. Prior tests, reports, matrices, and verdicts remain untrusted until reproduced against the current bytes. | IN PROGRESS |
| V32-01 | Exact invocation checkpoint | Focused regression evidence, the complete SwiftPM suite, unsigned Debug/Release builds, bounded static analysis, configuration/artifact inspection, staged-diff review, and post-commit isolation checks remain pending. | PENDING |

### Append-only evidence log (continued)

- E-471 — 2026-08-06T10:03:55+0200 — Recovery used exactly the authenticated
  rolling-remainder authority because HEAD is beyond the historical starting
  commit. Every required feature-worktree and main-checkout field and byte
  matched before this first edit; there was no normalization, overwrite, app
  or helper launch, install, activation, registration, approval, `pmset`,
  sleep-setting, design, Figma, plugin, connector, network, merge, push, or
  main-checkout mutation. `State: IN_PROGRESS` remains authoritative while the
  complete checkpointed safety package is independently reverified.

## Exact arm-intent confirmation checkpoint — 2026-08-06

| ID | Safety invariant or verification | Independently reproduced evidence and bounded result | Verdict |
|---|---|---|---|
| S32-01 | A queued confirmation may authorize only the pending intent that created it | Every pending intent now receives a process-local UUID. Manual UI, preset, and schedule tasks pass the captured UUID; replacement, cancellation, assessment change, and risk-plan change cannot make an older task apply to a newer pending intent. A second begin request is rejected while any intent is pending. | FIXED OFFLINE / MAIN-ACTOR RUNTIME GATE |
| S32-02 | Confirmation binds the exact risk-relevant settings through mutation and session commit | `ArmIntentPlan` snapshots effective cutoffs and helper Low Power Mode/TCP keepalive options. Equality is checked at confirmation entry, again after every pre-dispatch suspension, and after a proven helper mutation; dispatch, post-arm assessment, and the recorded session consume the snapshot rather than mutable configuration. Post-mutation drift enters verified restoration. | FIXED OFFLINE / LIVE-XPC GATE |
| S32-03 | Scheduled authorization remains valid only for the exact live occurrence while automation is enabled | A scheduled plan additionally snapshots its concrete `ScheduleEngine.Occurrence`. Current-plan reconstruction requires enabled automation, the same active window ID, and identical occurrence bounds. Disablement, edit, deletion, expiry, or overlap replacement revokes pre-dispatch authorization and forces restoration after proven mutation. Disabling automation also ends an accepted scheduled session through the existing cutoff/restoration path. | FIXED OFFLINE / CLOCK-DST RUNTIME GATE |
| S32-04 | Explicit cancellation cannot be silently replaced by schedule automation | Cancelling a scheduled pending card suppresses the exact occurrence captured in its plan before clearing schedule and pending bookkeeping. A changed scheduled plan or assessment clears the old pending task so a later tick may create a newly bound task; the scheduler cannot reuse or replace a user-cancelled occurrence. | FIXED OFFLINE / UI-TICK RUNTIME GATE |
| S32-05 | Projection refresh cannot overwrite an unrelated pending intent | Both the main overview control and `beginArmFlow` reject entry while a pending intent exists. Projection-only refresh retains identity, while a changed warning or manual/preset plan rotates identity and requires a new confirmation. | FIXED OFFLINE |
| V32-02 | The focused regressions discriminate the old behavior | Five production-source RED stages independently failed for missing identity binding, exact plan binding, pending-overwrite prevention, scheduled occurrence revocation, and schedule-aware cancellation/retry bookkeeping. The final cancellation RED failed with three issues before the final source change. | PASS — RED OBSERVED |
| V32-03 | Exact staged tests cover the focused, related, and complete package surfaces | Exact pre-ledger index tree `be6ba0402dc29f300efd22f62cd5e7944f1fd03b` passed four focused tests, 73 related tests in five suites, and all 329 package tests in 33 suites under the stable toolchain with local caches and SwiftPM sandboxing disabled. | PASS FOR EXACT STAGED CODE |
| V32-04 | Debug/Release compilation and bounded static analysis use the final production bytes | All 63 final production Swift sources match the exact staged export. `LidlessCore` built in Debug and optimized Release; all 25 App, four helper, and one widget sources passed Swift 6 complete-concurrency typechecking with warnings as errors; all three products linked in Debug and optimized Release with signing and linker ad-hoc signing disabled. | PASS FOR OFFLINE SOURCES / XCODE GRAPH BLOCKED |
| V32-05 | Actual loose artifacts and source configuration support only bounded claims | Six loose outputs are arm64 Mach-O executables targeting macOS 15.0 / SDK 26.5, contain no `LC_CODE_SIGNATURE`, and report unsigned. Exact source plist/entitlement files and `project.pbxproj` linted and were decoded; an independent Xcodegen round trip reproduced project/workspace/scheme bytes. These are not bundles, signatures, entitlements, or runtime trust proof. | PARTIAL — OFFLINE ARTIFACTS ONLY |
| V32-06 | Selected bytes, authenticated remainder, and main checkout stay isolated | Nine non-ledger 100644 paths alone form the exact source/test/doc tree. The rolling three-file design remainder reproduces every status/mode/size/hash and both digests; the main checkout reproduces every recorded field, file, and digest. | PASS BEFORE LOCAL CHECKPOINT |

This checkpoint is limited to exact pending-arm identity, risk-plan and schedule
occurrence binding, scheduled cancellation, post-mutation restoration on plan
drift, tests, and architecture wording. Scheduled-wake transactional
durability, helper interruption/owner-loss timing, crash-session journal
semantics, XPC timeout/connection liveness, stale-helper replacement,
Homebrew removal/upgrade safety, privileged child storage/path hardening,
release-artifact permission validation, live status reconciliation, and every
live/hardware gate remain separate work. `State: IN_PROGRESS` therefore
remains authoritative.

### Exact arm-intent append-only evidence log (continued)

- E-472 — 2026-08-06T10:34:23+0200 — Before production edits, the literal
  required `swift test --package-path Packages/LidlessCore` reached the default
  Xcode-beta compiler but failed solely at the sandbox-inaccessible
  `/Users/junaid/.cache/clang/ModuleCache`; `swift-test-literal-baseline.log`
  is six lines / 2,347 bytes, SHA-256
  `b2ed94195db3462988e5ef9b6cfb82ce20ca6eeadd9bd38b183dadfec3a73bef`.
  The stable Xcode toolchain with workspace-local caches and SwiftPM's sandbox
  disabled passed the unchanged baseline's 325 tests in 32 suites;
  `swift-test-stable-baseline.log` is 826 lines / 64,537 bytes, SHA-256
  `a30e242cbd010049b62a87b9c23932f65cede6ac4ec40c33b12c4c7cc7aed4d3`.
- E-473 — 2026-08-06T10:34:23+0200 — Source tracing confirmed the selected
  root cause: preset and schedule tasks invoked an ambient `confirmArm()`, so
  cancellation or replacement could make an old task confirm a later intent;
  settings were re-read rather than bound to confirmation; another begin could
  overwrite pending state. The first regression failed as one test / one suite
  with nine issues (`arm-intent-confirmation-red.log`, 8,645 lines / 346,208
  bytes, SHA-256
  `ae58538e86b2fd2862b8728fa65ebbbb0723df4ae2ed6fec6f0a42a6f12edd52`).
  Successive focused REDs then failed with eight plan issues
  (`arm-intent-plan-red.log`, 107 lines / 7,716 bytes, SHA-256
  `135d82c1102e06f186a2d72361afba3d20f9e1a80a24a6428a1933bed1b89f6a`),
  two overwrite/UI issues (`arm-intent-overwrite-red.log`, 404 lines / 15,984
  bytes, SHA-256
  `f30d7f10d3907cc2208fb10b33cad8ae77435b0b682acd7278e4df6705b58166`),
  and six exact-schedule issues
  (`arm-intent-schedule-revocation-red.log`, 1,404 lines / 61,568 bytes,
  SHA-256
  `31338eeb7fa568d727c87dc06e4c01b2c2a200b8d5e8dd7ba842511ad29721de`).
  The final cancellation/retry regression failed with three issues before its
  source fix (`arm-intent-schedule-cancel-red-final.log`, 2,537 lines / 102,492
  bytes, SHA-256
  `eaef94fb103568ce096f39e909adea241f8afcc64386f0e555bf701e45bed6c4`).
  A preceding test-only misplaced local produced a compile error and is
  preserved, but not promoted as RED evidence
  (`arm-intent-schedule-cancel-red.log`, SHA-256
  `b027fcdf0e31c51b64e70f4a849721254839c99237da4d3399154d3d29e9f2d3`).
- E-474 — 2026-08-06T10:34:23+0200 — The bounded repair adds the pure
  `ArmIntentConfirmationSafety` equality policy and an exact `ArmIntentPlan`,
  captures UUID/plan/occurrence at every arm-intent producer, rejects stale
  UUIDs and plan drift before helper dispatch, consumes confirmed cutoffs and
  options, and enters verified restoration if the plan changes after a proven
  arm. Pending overwrite is blocked at state and UI boundaries. Scheduled
  cancellation suppresses the captured occurrence, changed scheduled state is
  discarded for a fresh later task, and disabled automation terminates an
  accepted scheduled session. Structural tests pin preflight before
  `trackedArm`, postflight after it, and postflight before session commit.
- E-475 — 2026-08-06T10:34:23+0200 — The nine selected non-ledger paths were
  staged alone and exported as exact index tree
  `be6ba0402dc29f300efd22f62cd5e7944f1fd03b`. The exact literal command again
  reproduced only the default Xcode-beta cache denial
  (`exact-final-literal-swift-test.log`, six lines / 2,420 bytes, SHA-256
  `73955f998dbc9890dc407844916aaa0608a1099f92c6f387ed954bc301120ef1`).
  Stable exact-index verification passed four focused tests in one suite
  (`exact-final-arm-intent-focused.log`, 101 lines / 6,571 bytes, SHA-256
  `dd853d77a2cadd41c38af9018365908815b3e040c22ad00695f2aed028e18827`),
  73 related intent/battery/thermal/sleep/schedule tests in five suites
  (`exact-final-arm-intent-related.log`, 247 lines / 17,548 bytes, SHA-256
  `94b1a3d1e1b36c51bf53c074e51658e64216668c641c278c5314f8d0388b08bd`),
  and all 329 tests in 33 suites (`exact-final-full-swift-test.log`, 838 lines
  / 65,432 bytes, SHA-256
  `27b9fc61875223876d8437e431deeb5aae6df945e65790fda01f5cfb96b268b1`).
- E-476 — 2026-08-06T10:34:23+0200 — Project-native unsigned Debug and Release
  attempts stopped during package resolution at the managed environment's
  nested `sandbox-exec: sandbox_apply: Operation not permitted`, before product
  compilation; the complete terminal attempts are
  `xcodebuild-debug-final.log` (58 lines / 7,461 bytes, SHA-256
  `d07a78da73e27f57e32b0f715e9d413f4735c8a6b1293966d51862af17665746`)
  and `xcodebuild-release.log` (58 lines / 7,447 bytes, SHA-256
  `904a9f06b19f6a2e640442eff4c5a4d1e389f9e2fbad674d598cca048692cef7`).
  The bounded direct fallback used stable Xcode 6.3.2/SDK 26.5 and a
  before/after-identical 63-source inventory, SHA-256
  `93ace6e881722bc752b386759f9cf9aa70ec3ca2eebca5dbd4b93045f51e2237`.
  Final Core Debug/Release builds passed (`core-debug.log`, 40 lines / 2,462
  bytes, SHA-256
  `3498f3f238b860546113662ba37973844476a7fd2cd4bab55c74435344102804`;
  `core-release.log`, seven lines / 664 bytes, SHA-256
  `a591c590c95ef5d6920c2f0f7d8140543aab96ce3680ab08c57b9c4aad5b0d81`).
  Complete-concurrency warnings-as-errors typechecking passed all 25 App, four
  helper, and one widget sources (`all-products-typecheck.log`, seven lines /
  3,714 bytes, SHA-256
  `504187faec1f125c7713dc1caac30f6db2010fe118daa6656c5068af2d881f59`).
  Direct Debug and optimized Release links of all three products passed with
  signing controls and linker ad-hoc signing disabled (`products-debug.log`,
  seven lines / 27,899 bytes, SHA-256
  `bcd1585bfb2d9fcf1b8adfbd016d6361879608b694c1d2d1b2f1251036cc3517`;
  `products-release.log`, seven lines / 28,300 bytes, SHA-256
  `6b8b80d9bc47b8a235eac24613e18dd8094e767ebd32dc65451f06f9be316f4c`).
  No product was launched.
- E-477 — 2026-08-06T10:34:23+0200 — Exact staged/current source comparison
  found zero differences across all 63 compiled Swift files;
  `exact-final-source-index-proof.log` is nine lines / 1,032 bytes, SHA-256
  `0a884bac4e6d1e16903bd110324ff4076a599a572dfe0cace9675bd0b2af0de1`.
  Artifact inspection is 86 lines / 7,468 bytes, SHA-256
  `ae401c674dfc5f35895c3b6a697899a797312e06df838a0d7b0ad5f9f29ab314`:
  all six outputs are thin arm64 Mach-O executables with minimum macOS 15.0 /
  SDK 26.5, zero `LC_CODE_SIGNATURE`, and expected unsigned `codesign` exit 1.
  Debug and Release App symbols include `ArmIntentPlan`, its scheduled
  occurrence, and `ArmIntentConfirmationSafety.authorizes`;
  `exact-final-arm-intent-symbol-inspection.log` is 46 lines / 4,248 bytes,
  SHA-256
  `e88be289185512711e213215b1ae789b9dfcd6d0c496662ff78d299fe138daa6`.
  Seven exact source plist/entitlement/project files linted; decoded values and
  bindings are in `exact-final-configuration-inspection.log` (143 lines /
  13,233 bytes, SHA-256
  `22e2b971bfcc6494ff3c0e861f70fafa3c0afaad2dbce1eef1889ac74f7d1d8f`).
  An independent read-only Xcodegen round trip reproduced the committed
  project, workspace, and scheme byte-for-byte; its 52-line / 2,818-byte log
  has SHA-256
  `e7d20ceff11e3d7b6ac51f28a48f3597764e49c4806f66a7e07fd07f682dfeb1`.
  Loose products and source configuration prove no embedded bundle contents,
  entitlement application, signing identity, XPC trust, ServiceManagement,
  runtime, notarization, or release readiness.
- E-478 — 2026-08-06T10:34:23+0200 — Independent read-only source reviews
  first found and then verified closure of three scheduled-intent extensions of
  the same root cause: automation/edit/expiry revocation, stale replacement
  bookkeeping, and user cancellation followed by scheduler replacement. The
  final review found no remaining Blocker/High issue in this checkpoint and
  confirmed `git diff HEAD --check`. The retained Medium limitation is explicit:
  AppState suspension/interleaving is tested by pure policy plus ordered source
  contracts and strict compilation, not by executing a fake helper across the
  async boundary. Separate helper, wake, journal, timeout, removal, storage,
  release-verifier, and live-status findings were not folded into this commit.
- E-479 — 2026-08-06T10:34:23+0200 — Every selected source/test/doc hunk was
  reviewed and `git diff --cached --check` passed. Before this ledger append,
  the exact nine-path binary cached diff is 719 lines / 30,355 bytes, SHA-256
  `22e99be99901bc0cfaac1052ef63b7cf4c4d8f393b7765a63ce7176585f367e0`;
  its NUL name-list digest is
  `d154bd924c5e18cdf5ed5b69a0998d94a2dc67c6f5ac9f66cb52aee967754b4b`.
  Pre-commit preservation reverified feature topology, common directory,
  branch, and unchanged HEAD `dcfefde87693e6f3a66d428a6fbede3e3cd7a582`.
  The three design-remainder paths remain unstaged and reproduce status, mode,
  byte count, raw hash, NUL-status digest
  `3a4984484500650d6b8866b3dfd45bc02ad0ff2888084f86deda5506c36e03dc`,
  and tracked binary-diff digest
  `5bfed6a6f1b1f3578736cce1d9ae66138f0f9e0614ffc8e93d0aa80c4d6e3b82`.
  The main checkout remains `main` at
  `7f17aaca11bc6228bed48b9265d63b9e576cdea7`, with clean index/tracked diff
  and its exact three `.playwright-mcp` records, NUL-status digest
  `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`,
  and empty tracked binary-diff digest. The complete preservation log is 54
  lines / 3,278 bytes, SHA-256
  `8df3e0d3380ea643558e02a6d9cc6e55820cf1c20f57adf8ebdc876619ade5df`.
- E-480 — 2026-08-06T10:34:23+0200 — `State: IN_PROGRESS` is retained because
  the separately scoped groups and every live/hardware gate above remain open.
  Real MainActor scheduling, notifications authorization, NSXPC suspension and
  failure ordering, signed helper trust, actual arm/restore, schedule wall-clock
  behavior, sleep/wake, closed-lid hardware, helper crash/upgrade recovery,
  notarization, and release readiness remain unproved. The intended single
  local checkpoint subject is `safety: bind confirmation to exact arm intent`.
  No app/helper was launched; no install, activation, registration, approval,
  live XPC, `pmset`, sleep-setting mutation, sleep/wake, hardware, plugin,
  connector, Figma, network, merge, push, or main-checkout mutation was
  performed. After this one commit, the supervisor must authenticate a fresh
  rolling remainder before any later invocation.
- E-481 — 2026-08-06T10:34:23+0200 — Nomenclature correction: E-476's phrase
  “stable Xcode 6.3.2/SDK 26.5” means the stable Xcode developer directory with
  **Apple Swift 6.3.2** and macOS SDK 26.5; it is not an assertion that the
  Xcode application version is 6.3.2. This correction is appended rather than
  rewriting E-476.
- E-482 — 2026-08-06T10:34:23+0200 — Precision correction for S32-02: exact
  plan equality is checked at confirmation entry, once after the complete
  sequence of pre-dispatch suspensions and immediately before dispatch, and
  once after a proven mutation before session commit. “Again after every
  pre-dispatch suspension” describes the final check occurring after all such
  suspension points; it does not assert a separate equality call after each
  individual `await`.

## Recovery audit and independent package review — 2026-08-06T10:41:16+0200

| ID | Recovery surface | Independently reproduced evidence | Verdict |
|---|---|---|---|
| R33-01 | Required records and authority | The canonical handoff and original manifest reproduce their required SHA-256 values. The rolling manifest exists, its adjacent sidecar validates it as SHA-256 `c6eb3d1b5cb17e65d3b47b92c53d2c315d4b04f6946aa9bcd6601bc441b609a2`, and it is the sole recovery authority because HEAD has advanced beyond the historical starting commit. All mandated repository documents were read in full; no repository-local `AGENTS.md`, `CLAUDE.md`, `CODEX.md`, or equivalent instruction file was found. | PASS |
| R33-02 | Feature worktree | Canonical path, linked-worktree registration, common Git directory, branch `codex/lidless-safety-repair-2026-08-04`, HEAD `c3160589638f183c7d865a44986a8be6c737fdcf`, and clean index match. The exact three-path NUL-delimited porcelain-status digest is `3a4984484500650d6b8866b3dfd45bc02ad0ff2888084f86deda5506c36e03dc`; the tracked binary-diff digest is `5bfed6a6f1b1f3578736cce1d9ae66138f0f9e0614ffc8e93d0aa80c4d6e3b82`; every recorded status/type/mode/size/raw hash matches with no extra or missing dirty path. | PASS |
| R33-03 | Main checkout preservation | Canonical path, topology, branch `main`, HEAD `7f17aaca11bc6228bed48b9265d63b9e576cdea7`, clean index, and empty tracked diff match. Its exact three-path NUL-delimited status digest is `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`; every recorded `.playwright-mcp` status/type/mode/size/raw hash matches. No main-checkout byte was edited. | PASS |
| A33-01 | Complete checkpointed package | All 31 checkpoint commits and the 91-path diff from starting HEAD through `c3160589638f183c7d865a44986a8be6c737fdcf` are under fresh adversarial review. The historical original manifest is not being misapplied to this post-checkpoint state. | IN REVIEW |

### Append-only evidence log (continued)

- E-483 — 2026-08-06T10:41:16+0200 — Recovery completed before this first
  edit using exactly the authenticated rolling-remainder authority. Both
  worktrees reproduced every required identity, topology, index, status-stream,
  binary-diff, path, type, mode, size, and raw-byte hash field. The earlier
  false-stop evidence caused by applying the historical starting-state
  manifest after legitimate checkpoints remains preserved; `State: IN_PROGRESS`
  is correct under the authenticated rolling checkpoint.
- E-484 — 2026-08-06T10:41:16+0200 — Began a fresh read-only review of the
  complete checkpointed package and delegated three non-mutating adversarial
  lanes covering helper recovery/storage/supervision, app recovery/XPC/live
  proof, and helper lifecycle/release verification. No app/helper launch,
  install, activation, registration, approval, live XPC, `pmset`, sleep-setting
  mutation, design/Figma, plugin/connector, network, merge, push, or
  main-checkout mutation occurred.

## Checkpoint 33 — terminal helper connection loss — 2026-08-06T11:00:46+0200

| ID | Finding / invariant | Exact evidence and disposition | Verdict |
|---|---|---|---|
| F33-01 | Helper ownership did not terminate on every documented process-loss callback | The prior daemon installed only `invalidationHandler`. The local stable SDK says a remote exit/crash invokes interruption, interruption may permit reconnection, and interruption/invalidation/reply callback ordering is not guaranteed. An armed connection could therefore lose its owning app without entering the daemon's immediate restore path. | CONFIRMED HIGH / SELECTED ROOT CAUSE |
| F33-02 | One connection must have one fresh identity and one terminal transition | Every accepted connection now receives a fresh UUID, registers synchronously on the daemon state queue before `resume()`, and both callbacks converge on a queue-owned Set removal. Interruption first calls `invalidate()` so Foundation cannot silently retain safety ownership by reconnecting. Only the first removal may request restoration; a duplicate or reordered callback is ignored. | FIXED OFFLINE / LIVE NSXPC GATE |
| F33-03 | A terminal connection must not arm after its loss is committed | `handleArm` now checks the UUID in the same queue-owned live set before lifecycle advancement, ownership assignment, sentinel persistence, or sleep-setting mutation. Loss-before-arm rejects; arm-before-loss is followed on the serial queue by restoration. Heartbeats remain safe through the same queue ordering and existing exact-owner check. | FIXED OFFLINE / LIVE ORDERING GATE |
| F33-04 | Identity-collision rejection must not terminate another live connection | A rejected duplicate UUID keeps the pre-existing Set member intact and clears both token-bearing handlers before false return and before the connection is resumed. Rejection-triggered invalidation therefore cannot submit the colliding token. A pure regression pins Set cardinality and structural regressions pin cleanup ordering. | FIXED OFFLINE |
| F33-05 | App and helper must reject implementations without this behavior | The independently produced daemon revision and app-required revision advance from 6 to 7 while the unchanged wire protocol remains 6. Tests reject stale revision 6, future revision 8, missing, malformed, and contradictory proof. | FIXED OFFLINE / STALE-HELPER REPLACEMENT OPEN |
| V33-01 | Focused RED discriminates the old behavior | The source regression against the pre-fix daemon failed one test in one suite with eight issues: missing interruption handling, terminal invalidation, UUID/registry registration and end, restoration disposition, and removal of the count/object-address design. | PASS — RED OBSERVED |
| V33-02 | Focused and complete working-tree tests cover the repaired group | The terminal working-tree focused run passed 19 tests in four suites. After the collision hardening, the complete suite passed 334 tests in 34 suites. | PASS FOR WORKING TREE |
| V33-03 | Immutable staged bytes reproduce the behavioral evidence | Exact staged index tree `66d304fbae14358ec5eb64bae1554d33059329fd` passed the same 19 focused tests and all 334 package tests under the stable toolchain. | PASS FOR EXACT STAGED CODE |
| V33-04 | Independent review challenges the selected race and repair | Three read-only review lanes found no remaining Blocker/High issue in the final checkpoint bytes. Reviews separately traced both queue orders, duplicate callbacks, non-owner loss, terminal arm admission, collision rejection, revision wiring, and release compatibility. | PASS — OFFLINE BOUNDED |
| G33-01 | Real callback delivery and restoration remain unproved | No app/helper was launched and no live connection, helper registration, sleep-setting mutation, or crash was exercised. Real interruption/invalidation delivery, timing, reconnection, owner-loss restoration, watchdog fallback, and signed XPC trust remain explicit runtime/hardware gates. | OPEN LIVE GATE |
| G33-02 | Revision 7 creates a stale-helper upgrade requirement | Existing revision-6 helpers are intentionally rejected. Safe replacement/removal of an already registered stale helper and truthful protocol-versus-behavior-version setup copy remain separate release-blocking work. | OPEN SEPARATE GROUP |
| G33-03 | Other independently confirmed package defects remain separate | Crash-session journal finalization, scheduled-wake transaction durability, Homebrew raw-`launchctl` lifecycle bypass, release-artifact permission validation, and previously recorded storage/removal/live-proof groups are not changed by this checkpoint. | OPEN SEPARATE GROUPS |

This checkpoint is limited to helper interruption/invalidation ownership loss,
exactly-once connection termination, post-loss arm admission, the behavior
revision gate, focused tests, and architecture wording. It does not claim live
XPC, actual arm/restore, helper replacement, sleep/wake, hardware, signing,
notarization, or release readiness. `State: IN_PROGRESS` remains authoritative.

### Terminal helper connection-loss append-only evidence log (continued)

- E-485 — 2026-08-06T11:00:46+0200 — Before editing production source, the
  literal required `swift test --package-path Packages/LidlessCore` failed only
  because the default Xcode-beta manifest compiler could not write
  `/Users/junaid/.cache/clang/ModuleCache`; `swift-test-literal-baseline.log`
  is six lines / 2,347 bytes, SHA-256
  `dd9e1f94066ee692ffa1f2836ae74cc3384786e4d242abe7b51f5ee8f81f04e7`.
  Stable Xcode with workspace-local caches and SwiftPM sandboxing disabled
  passed the unchanged baseline's 329 tests in 33 suites;
  `swift-test-stable-baseline.log` is 838 lines / 65,423 bytes, SHA-256
  `60a0dbdc6cd90afda33dd9c56d08016fe4c6a748c9512c23a1c7ea684783e574`.
- E-486 — 2026-08-06T11:00:46+0200 — The stable macOS 26.5 SDK
  `NSXPCConnection.h` has SHA-256
  `d34e7696e475abf3accda0a82127a61f5a95f5cb6609cdf5f57bfdea61c5fd1b`.
  Its lines 79–88 document that remote exit/crash calls interruption, that an
  interrupted connection may reconnect, that interruption/invalidation and
  other callback ordering is unspecified, and that an invalid name may invoke
  invalidation asynchronously after resume. The prior helper installed only
  invalidation handling and tracked a reusable object address plus a count;
  those bytes could not substantiate immediate owner-loss restoration.
- E-487 — 2026-08-06T11:00:46+0200 — The production-source RED ran against
  the old helper before its fix and failed one test in one suite with eight
  issues (`helper-connection-loss-red-final.log`, 1,909 lines / 82,945 bytes,
  SHA-256
  `f33beaa4580d898ce22ca5d36484098778a9b82f4e241baa09dcefce2e8bdf8d`).
  A preceding filter spelling selected zero tests and is retained only as
  non-evidence (`helper-connection-loss-red.log`, 93 lines / 5,920 bytes,
  SHA-256
  `a2da3ba4df6f50a78928a88e6638c77c2b026c6c46aafd61425e5d7d45680958`).
- E-488 — 2026-08-06T11:00:46+0200 — The bounded repair adds the pure,
  queue-owned `HelperConnectionSupervisionSafety` registry, fresh UUID
  identities, synchronous pre-resume registration, terminal interruption via
  `invalidate()`, exactly-once Set removal, first-owner-loss restoration, and
  a pre-mutation live-token arm fence. Both collision handlers are cleared on
  duplicate registration before rejection. App-required and daemon-produced
  behavior revisions independently advance to 7; protocol 6 is unchanged.
- E-489 — 2026-08-06T11:00:46+0200 — Intermediate focused runs are preserved
  but not promoted as terminal evidence: one test-macro compile mistake
  (`helper-connection-loss-focused-green.log`, SHA-256
  `6ccf46dd2a8d0ca41b67ac38696368e143ecb5086319fb460b57d5a76e0ba02a`),
  one stale invalid-revision list failure
  (`helper-connection-loss-focused-green-final.log`, SHA-256
  `423838fd61bf04d8270f150f55ef0fc2720970be6feaeff2d405ba883ff6747a`),
  and superseded passing runs before final collision/test tightening. The
  terminal focused run passed 19 tests in four suites
  (`helper-connection-loss-focused-green-terminal.log`, 68 lines / 4,979
  bytes, SHA-256
  `eafc7a8cc2257b9947a1f13d1c566274843b8f18ebf17962db597d65269dbcf2`).
  The final complete working tree passed 334 tests in 34 suites
  (`swift-test-full-working-final.log`, 776 lines / 61,798 bytes, SHA-256
  `0ac5ae8c007c0549bbfc650c301f7d4e0724f0ddc0e60472fd65b6f0bf424f56`).
- E-490 — 2026-08-06T11:00:46+0200 — The eight selected paths were staged
  alone and exported as immutable index tree
  `66d304fbae14358ec5eb64bae1554d33059329fd`. Its literal command again
  reproduced only the default beta-toolchain cache denial
  (`exact-literal-swift-test.log`, six lines / 2,415 bytes, SHA-256
  `069fef54d2a90bf9c8f6f37ceeea2d5e3103d80c577999ed1f788ef240cf16d0`).
  Stable exact-index runs passed 19 focused tests in four suites
  (`exact-focused.log`, 139 lines / 9,497 bytes, SHA-256
  `40159b17764e3651b7312497d58489d8fad0b94cdad2878db1e5ff191c37765a`)
  and all 334 tests in 34 suites (`exact-full.log`, 852 lines / 66,514 bytes,
  SHA-256
  `e8f7fc2c3e86aad17689cdc557e25321202d4d736e4665059f8e427e9861a944`).
- E-491 — 2026-08-06T11:00:46+0200 — Precision correction for E-490: tree
  `66d304fbae14358ec5eb64bae1554d33059329fd` is the exact pre-final-ledger
  index tree; its seven non-ledger checkpoint paths are the final code, test,
  and architecture bytes. The literal command added only two ignored SwiftPM
  markers inside the export, so a later whole-directory 144-file digest was
  quarantined as non-authoritative. Independent projection of the Git tree
  verified all 142 paths by type, mode, size, Git blob, and raw SHA-256 with
  zero missing or changed records; the canonical record digest is
  `cf2093c26a2efaa4a3fbbf85d981cde04ab63ebc68ee95363df6f903d1454137`.
  `config-final/index-tree-142-correction.log` is 180 lines / 33,929 bytes,
  SHA-256
  `24fc7e30f693b434a823ba29ceaa85f4b31a4246516b0b6370af8433171d6337`.
  A first local projection harness accidentally assigned zsh's special
  `path` variable, lost command lookup, and stopped after two lines; that
  non-evidence is preserved rather than promoted. All 64 production Swift
  sources in the exact export and current tree match byte-for-byte
  (`exact-source-index-proof.log`, nine lines / 312 bytes, SHA-256
  `cd7f51ca7cccf3a824ac0e8ffdfaf1e1db73d454c30f6023b0e66a792bdc1d32`).
- E-492 — 2026-08-06T11:00:46+0200 — Exact configuration checks linted and
  decoded all six source plist/entitlement files and the project file
  (`config-final/plist-entitlements-lint-decode.log`, 116 lines / 4,794 bytes,
  SHA-256
  `073b6df19ae4c5e458ce598c57a666c7b28f8a661afc8b785dd2b4a69e206bc6`).
  Project bindings and the independent protocol-6/revision-7 producer and
  consumer chain passed (`project-bindings-protocol-revision.log`, 267 lines /
  13,744 bytes, SHA-256
  `143dfb5bffcb1e920021b6c7ae3be39b1aec5c5cf2c2129c2eec8f3ddd8a0d19`).
  Local Xcodegen 2.45.4 reproduced project, workspace, and shared scheme bytes
  in an isolated temporary copy (`xcodegen-isolated-roundtrip.log`, 40 lines /
  2,918 bytes, SHA-256
  `a1c687febe536ef4775675dd7ee6f10d31edfac0dd57b4d48c0177d95e69a59d`).
  These are source-configuration results, not proof of applied entitlements,
  built bundle contents, signature identity, XPC trust, or runtime behavior.
- E-493 — 2026-08-06T11:12:37+0200 — The exact pre-final-ledger tree's 64
  production Swift sources had an identical before/after inventory, SHA-256
  `9bcc09ca567450d05152834f4b0b2d05fa5cf673ff5979adfebb8fdfc4e1efc5`.
  Stable `LidlessCore` Debug and optimized Release builds passed with
  `CODE_SIGNING_ALLOWED=NO`, `CODE_SIGNING_REQUIRED=NO`, local caches, and
  SwiftPM sandboxing disabled (`direct-compiler-final/core-debug.log`, 41
  lines / 3,263 bytes, SHA-256
  `6fbec97c8e362ceccea512d10f816716ce40917f787bfe4bee16f59466629e4a`;
  Release seven lines / 1,395 bytes, SHA-256
  `3bc032732f1fbeef0199f57261659f6000f298c853dc691f8043af02a94aa6e9`).
  All 25 App, four helper, and one widget sources passed Swift 6 complete
  strict-concurrency typechecking with warnings as errors
  (`all-products-typecheck.log`, ten lines / 4,540 bytes, SHA-256
  `82ebd0d4e9a91ba35b7807ae6bfa9e645b4e528f660cb8ea46342bdc060eb24e`).
  All three exact source sets directly compiled and linked in Debug and
  optimized Release with SDKROOT and `-sdk` pinned to stable macOS 26.5,
  deployment target 15.0, signing disabled, and linker ad-hoc signing
  suppressed (`products-debug.log`, ten lines / 29,104 bytes, SHA-256
  `954ea230044612b61b38a1109e8be18ea1dccc3d50adb4f9d1e5dcf2765edafe`;
  Release ten lines / 29,517 bytes, SHA-256
  `7ef3aac0a7c181782c547e210275144d6366bceac3b667d108554ec15c79d965`).
  No product was launched.
- E-494 — 2026-08-06T11:12:37+0200 — Actual loose-output inspection is 175
  lines / 16,185 bytes, SHA-256
  `9c8270dbf20ac540f372215b08adb2151cb5cbbc0ce9ee6203136537b109ed71`:
  all six products are thin arm64 Mach-O executables with minimum macOS 15.0 /
  SDK 26.5, zero `LC_CODE_SIGNATURE`, and expected unsigned `codesign`
  display/verify exits. Both helper configurations contain demangled
  `HelperConnectionSupervisionSafety` symbols (`helper-symbols.log`, 110 lines
  / 18,925 bytes, SHA-256
  `66d867e471035fbdf81e4d75263d5f944e4f08060c19e2fec1f56ea6fe74e44c`).
  The corrected 17-entry evidence manifest verifies every primary log and has
  SHA-256
  `98c121706692fd8e15093285e495bf74628437db15048a316606347329afbdec`.
  Its first version was generated before the driver appended `result=PASS`;
  that invalid manifest remains quarantined and the correction is explicit in
  `manifest-correction.log`, SHA-256
  `b3064b0fbb1bec945e55805f43cc8f4332900ad14ef5dca7430eaa40fdfbf2be`.
- E-495 — 2026-08-06T11:12:37+0200 — Two earlier compiler harness attempts
  are retained only as non-evidence. Attempt 1 omitted the `SDKROOT`
  environment from direct `swiftc`; compilation/linking succeeded but the
  first artifact truthfully reported LC SDK 15.0, so the harness stopped
  (`direct-compiler-attempt-1-sdkroot-omitted/artifact-inspection.log`,
  SHA-256
  `e73b0a56b3cad40757cd566b505fd92cc8c8685c52abfae805b55f1bd047e649`).
  Attempt 2 fixed SDKROOT but Bash 3.2 rejected an intentionally empty Release
  flag array under `set -u` before a valid Release link verdict
  (`direct-compiler-attempt-2-empty-array/products-release.log`, SHA-256
  `03724043327f5497d4bad40acf7c1e5467fdc72fed1b40a198585db561d3223d`).
  The terminal run rebuilt everything in a fresh directory with a nonempty
  configuration flag set. Project-native `xcodebuild`/analyze was not retried:
  this ledger's preserved exact-tree evidence already establishes the managed
  nested-sandbox failure and automatic LaunchServices registration side effect.
  Strict direct typechecking is the bounded static-analysis substitute.
- E-496 — 2026-08-06T11:12:37+0200 — Three independent read-only reviews of
  the final connection-loss bytes found no remaining Blocker/High issue. A
  theoretical UUID-collision handler alias and imprecise ownership wording
  were found and closed before the terminal tests. Reviews also confirmed that
  the revision bump intentionally makes every installed revision-6 helper
  stale; safe stale-helper replacement/removal remains release-blocking but is
  a separate root-cause group. Real NSXPC callbacks, reconnection, and owner
  loss remain live gates. The crash-session journal, scheduled-wake durability,
  raw-`launchctl` lifecycle bypass, and release-permission findings remain open
  and unmodified.
- E-497 — 2026-08-06T11:12:37+0200 — All seven non-ledger checkpoint paths
  alone have binary cached-diff SHA-256
  `0476e745debcab4a4cd9396013d9c253e4facb71ac1e7b8c36d9cf4c46367455`
  and NUL name-list digest
  `fe885cdff47607c0e80972addab97e2455a15257850ff452404282d53faf6ef0`.
  Before this final ledger append, the exact eight-path index tree was
  `7a5de7cd9401e6a43cd5151faf0b54b2801bfdca`; the full cached binary-diff
  digest was
  `47dcaa1ad76a30ccd76094808fe317a996fb086f437984828384d605e9bb2ee6`
  and the NUL name-list digest was
  `0cb43079e7815db7cea03df04029fcb595e9832b4c629bcffab93d62cc1cbf2d`.
  Both cached and unstaged `diff --check` passed. Final staging after this
  append changes only this ledger; the seven executable/doc/test bytes remain
  exactly those tested, built, inspected, and hashed above.
- E-498 — 2026-08-06T11:12:37+0200 — Pre-commit preservation reproduced the
  two-worktree topology, common Git directory, feature branch and parent HEAD,
  exact eight-path staging set, and the authenticated three-file design
  remainder. That remainder still has NUL status digest
  `3a4984484500650d6b8866b3dfd45bc02ad0ff2888084f86deda5506c36e03dc`
  and tracked binary-diff digest
  `5bfed6a6f1b1f3578736cce1d9ae66138f0f9e0614ffc8e93d0aa80c4d6e3b82`;
  every recorded mode, byte count, and raw hash matches. The main checkout is
  still `main` at `7f17aaca11bc6228bed48b9265d63b9e576cdea7`, with clean index/tracked
  diff and its exact three `.playwright-mcp` records, NUL status digest
  `09f068790b258102315b5804d280fc79222a0fa7cb9ea79e2d49cb83425efd18`,
  and empty tracked-diff digest. `precommit-preservation.log` is 60 lines /
  4,287 bytes, SHA-256
  `659baf985effe844968f06d213bdce857e112372244f0dc70a073204d751dc04`.
- E-499 — 2026-08-06T11:12:37+0200 — `State: IN_PROGRESS` is retained because
  the separate root-cause groups and every live/hardware/release gate above
  remain open. The intended single local checkpoint subject is
  `safety: make helper connection loss terminal`. No app/helper/product was
  launched; no install, activation, registration, approval, live XPC,
  `pmset`, sleep-setting mutation, sleep/wake, hardware, signing, Figma,
  plugin/connector, network, merge, push, release, or main-checkout mutation
  was performed. After this one commit, the supervisor must authenticate a
  fresh rolling remainder before any later invocation.

## Checkpoint 34 — same-wire stale-helper recovery and bounded replacement — 2026-08-06T12:07:36+0200

| ID | Finding / invariant | Exact evidence and disposition | Verdict |
|---|---|---|---|
| F34-01 | Revision 7 made an installed revision-mismatched protocol-v6 helper unreachable from Setup's replacement action | The old `install()` path called `register()` for every stale state. An already enabled stale helper therefore remained registered and the new helper could not replace it. The same exact-revision predicate also rejected a structurally restored stale reply before independent registry-OFF evidence could complete de-risking recovery or cleanup. | CONFIRMED IMPORTANT / SELECTED ROOT CAUSE |
| F34-02 | Risk-increasing and de-risking compatibility must remain separate | Readiness, arming, one-source restore, outside-ownership classification, and scheduled-wake acceptance still require protocol 6 plus exact safety revision 7. Only the two-source restore/removal overloads accept a revision-missing, older, or newer protocol-6 responder. `helperSafetyRevision` remains 7. | FIXED OFFLINE |
| F34-03 | Revision mismatch cannot substitute for restoration proof | Same-wire recovery additionally requires a successful reply, `armed == false`, verified registry OFF, `restorePending == false`, and a separately obtained app registry-OFF observation. Nil/true/contradictory fields, negative replies, and either unknown observation reject. Different or unknown wire versions remain manual fallback. | FIXED OFFLINE |
| F34-04 | Replacement must be fresh, user-invoked, bounded, and fail closed | `install()` freshly reclassifies the live registration. Only a same-wire stale classification enters the existing token-bound cleanup and two-source restore proof; proven cleanup is followed by awaited unregister plus final inactive/OFF proof, then one register attempt and fresh post-register classification. There is no launch replacement or retry loop. A failed register after proven removal is surfaced as safe-but-uninstalled, never success. | FIXED OFFLINE / LIVE SERVICEMANAGEMENT GATE |
| F34-05 | Replacement must exclude app lifecycle races and invalidate removed wake evidence | App admission now requires quiescent termination, lifecycle, session, arm, restore, and sleep-transition state. The removal-style exclusion covers every suspension. Scheduled-wake reply evidence is invalidated before cleanup and reconciled only after lifecycle release; stale-recovery admission also performs a fresh helper classification and rechecks exclusions after suspension. | FIXED OFFLINE / LIVE ORDERING GATE |
| F34-06 | Setup must not offer unsafe automatic replacement | Setup and onboarding offer `Replace Helper…` only for exact protocol 6 with a stale behavior revision. Different-wire and nonresponding states display manual-fallback copy. Cleanup/register failures are rendered to the user instead of leaving only a generic stale status. | FIXED OFFLINE |
| V34-01 | TDD discriminates the old policy and the app/UI wiring | Focused REDs first failed for the missing recovery-compatibility policy, missing truthful replacement/error UI, and missing scheduled-wake invalidation/reconciliation. Production changes followed those failures. | PASS — RED OBSERVED |
| V34-02 | Working-tree behavioral verification covers the repaired group and whole package | The terminal focused run passed four tests in one suite. Nine collision-adjacent suites passed 51 tests. The complete package passed 338 tests in 35 suites under stable Xcode 26.5. | PASS FOR WORKING TREE |
| G34-01 | Live replacement remains unproved and unauthorized | No app/helper was launched; no real status selector, cleanup token, registry read, unregister/register, approval, mixed-version XPC, signing, or timing behavior was exercised. Unsupported old selectors, ServiceManagement ABA, installed-byte identity, and failed/approval-pending live outcomes remain explicit runtime gates. | OPEN LIVE GATE |
| G34-02 | Other independently confirmed package defects remain separate | Crash-session journal finalization, scheduled-wake transaction durability, Homebrew raw-`launchctl` lifecycle bypass, release-artifact permission validation, and earlier storage/removal/live-proof groups are not changed by this checkpoint. | OPEN SEPARATE GROUPS |

This checkpoint is limited to offline same-wire revision-mismatch recovery,
user-invoked bounded replacement admission, truthful Setup/onboarding states,
focused tests, and architecture wording. It does not claim live helper
replacement, actual restoration, sleep/wake, ServiceManagement behavior,
hardware, signing, notarization, or release readiness. `State: IN_PROGRESS`
remains authoritative.

### Same-wire stale-helper recovery append-only evidence log (continued)

- E-500 — 2026-08-06T12:07:36+0200 — Recovery began from feature HEAD
  `de9d9db3b7964de0f86f75772b5a82063564e709`. Before edits, the authenticated
  three-file design remainder reproduced NUL status digest
  `3a4984484500650d6b8866b3dfd45bc02ad0ff2888084f86deda5506c36e03dc`
  and tracked binary-diff digest
  `5bfed6a6f1b1f3578736cce1d9ae66138f0f9e0614ffc8e93d0aa80c4d6e3b82`.
  Main remained `main` at `7f17aaca11bc6228bed48b9265d63b9e576cdea7`
  with clean index/tracked diff and only its authenticated three
  `.playwright-mcp` paths. The rolling manifest and sidecar both reproduced
  SHA-256
  `ff00db0887befb47d49f81d5c5f50226ea3a379afffdbe3024ce3bd6f5560dac`.
- E-501 — 2026-08-06T12:07:36+0200 — The selected root cause was traced through
  `SleepOverrideSafety`, `NonSleepRestoreGate`, `HelperRemovalSafety`,
  `HelperClient.install()`/`uninstall()`, `AppState` restore and repair paths,
  and both Setup surfaces. The pre-repair focused test failed on the absent
  exact-wire recovery policy. Later REDs separately rejected missing UI error
  copy and missing scheduled-wake invalidation/reconciliation before those
  production changes were made.
- E-502 — 2026-08-06T12:07:36+0200 — The final policy retains exact protocol 6
  plus behavior revision 7 for every risk-increasing and one-source boundary.
  Its exact-wire compatibility predicate is consumed only by de-risking
  two-source restore/removal proof, stale repair eligibility, cleanup
  preparation, and the user-invoked replacement/manual-fallback split.
  Revision-mismatched statuses cannot prove outside ownership or scheduled
  wake and cannot arm.
- E-503 — 2026-08-06T12:07:36+0200 — The replacement sequence has one fresh
  classification, one reviewed cleanup/unregister attempt, and one register
  attempt. Existing cleanup token, launchd-state recheck, local unresolved-
  outcome fence, post-unregister inactive/OFF proof, and connection
  invalidation remain intact. A different/unknown responder or ambiguous
  result stops without registration; no automatic retry or launch-time path
  was added.
- E-504 — 2026-08-06T12:07:36+0200 — Terminal working-tree verification under
  `/Applications/Xcode.app` (Xcode 26.5) passed four focused stale-helper tests,
  51 tests across nine collision-adjacent suites, and all 338 tests in 35
  suites. The complete suite includes malformed reply, missing/older/future
  revision, different wire version, strict arm/one-source proof, two-source
  restore/removal, lifecycle fencing, scheduled-wake, and UI source contracts.
- E-505 — 2026-08-06T12:07:36+0200 — No app, helper, widget, or compiled product
  was launched. No live install, activation, registration, unregister,
  approval, XPC, `pmset`, sleep-setting mutation, sleep/wake, hardware,
  signing, design/Figma, authentication, credential, provider, plugin/MCP,
  connector, network, merge, push, deploy, release, or main-checkout mutation
  occurred. Exact staged builds, artifact inspection, independent final review,
  and pre-commit preservation are still pending at this evidence point.

## Checkpoint 34 independent-review correction — 2026-08-06T12:21:42+0200

| ID | Review finding / corrected invariant | Exact evidence and disposition | Verdict |
|---|---|---|---|
| F34-07 | Protocol compatibility alone cannot authorize destructive cleanup | The first draft admitted every protocol-v6 revision to cleanup and removal. Historical revision 3 is a concrete counterexample: later checkpoints introduced mandatory wake-ledger absence and other cleanup guarantees. Independent registry-OFF evidence proves only the main `disablesleep` flag; it does not prove wake cancellation, optional-setting restoration, data cleanup, or future cleanup semantics. F34-02/F34-04 and E-502/E-503 are therefore superseded where they described broad same-wire **cleanup/removal** admission. Broad same-wire two-source proof remains valid only for normal-sleep restoration. | HIGH FOUND / FIXED OFFLINE |
| F34-08 | Automatic cleanup/replacement needs an explicit reviewed revision | Helper state now preserves both wire and behavior revision. Cleanup requires protocol 6 plus current revision 7 or explicitly pinned reviewed predecessor revision 6. Automatic stale replacement requires exactly protocol 6 / revision 6. Missing, revisions 0–5, future revision 8, different wire, nonresponding, and unknown evidence stop before `commitUninstall`. The predecessor pin is literal 6, not `current - 1`, so a future bump cannot silently expand admission. | FIXED OFFLINE |
| F34-09 | Compatibility status is not installed-byte verification | Onboarding's prior “Helper installed and verified” copy contradicted the documented self-reported evidence boundary. It now says “Helper installed and responding,” aligned with Setup and without claiming executable attestation or an installation receipt. F34-06 is corrected accordingly. | IMPORTANT FOUND / FIXED OFFLINE |
| F34-10 | The emergency sleep command is not a full replacement procedure | Setup, onboarding, and client errors now label `sudo pmset -a disablesleep 0` as emergency normal-sleep recovery only and explicitly say it does not remove the helper, cancel helper-managed wakes, restore other settings, or delete helper data. Full removal points to Setup & Help in the matching Lidless version or a reviewed support procedure. The earlier “exact manual fallback” wording in F34-06/architecture is superseded. | IMPORTANT FOUND / FIXED OFFLINE |

### Independent-review correction evidence log (continued)

- E-506 — 2026-08-06T12:21:42+0200 — Independent full-diff review reported
  one High and two Important findings before commit: overly broad destructive
  same-wire cleanup, onboarding's installed-byte overclaim, and a sleep-only
  command presented as replacement guidance. Commit was stopped immediately;
  the previously green exact staged tree
  `cddef02fcfb7179b6575b6a46acc9bdef909ff96` and its build evidence are
  quarantined as pre-review, non-final evidence.
- E-507 — 2026-08-06T12:21:42+0200 — A new focused regression was added before
  the correction. It failed compilation because
  `isReviewedCleanupCompatibleHelper` and the explicit reviewed-predecessor
  pin did not exist. After the pure policy was added, a second source-contract
  RED failed because `install()` still used protocol-only admission. The
  production/client/UI correction followed those discriminating failures.
- E-508 — 2026-08-06T12:21:42+0200 — The corrected split is now three-tiered:
  exact revision 7 for risk-increasing and one-source proof; any exact-wire
  revision only for structurally complete two-source normal-sleep restoration;
  and exact wire plus revision 7 or reviewed predecessor 6 for destructive
  cleanup/removal. Only stale revision 6 may enter automatic replacement.
  Reported revision is retained in `HelperInstallState`; no revision bump,
  retry loop, or launch-time replacement was added.
- E-509 — 2026-08-06T12:21:42+0200 — Corrected working-tree verification
  passed five focused tests, 55 tests across ten cleanup/recovery/lifecycle
  suites, and all 339 package tests in 35 suites. Strict Swift 6 complete-
  concurrency App typechecking with warnings as errors also passed all 25 App
  sources. Exact staged tests, complete all-product builds, and restarted
  independent review remain pending at this evidence point.

## Checkpoint 34 final-review removal-guidance correction — 2026-08-06T12:34:49+0200

| ID | Review finding / corrected invariant | Exact evidence and disposition | Verdict |
|---|---|---|---|
| F34-11 | An unreviewed helper revision must not be sent to its matching app's generic uninstall path | Final independent review found that the corrected automatic gate was safe but the manual guidance still told every rejected revision to use a matching Lidless version. That is not a reviewed removal path: historical revision 3 predates mandatory wake-ledger-absence proof, and its matching app's destructive cleanup is a concrete counterexample. Rejected missing, 0–5, future, different-wire, nonresponding, or unknown helpers now remain registered and direct only to a separately reviewed, revision-specific support removal procedure. Revision 6 remains the sole pinned automatic predecessor. F34-10 is superseded only where it recommended a generic matching-version removal route. | HIGH FOUND / FIXED OFFLINE |

### Final-review removal-guidance evidence log (continued)

- E-510 — 2026-08-06T12:34:49+0200 — The reviewer reported F34-11 before
  commit. The exact staged tree
  `904c8b1cbd79ad44dac7d048ff5731eb6dce28e0`, its five focused, 60 related,
  and 339 complete exact-test passes, and its direct Debug/Release build and
  unsigned-product inspection are quarantined as pre-finding, non-final
  evidence. No commit or live action followed that green result.
- E-511 — 2026-08-06T12:34:49+0200 — A source-contract regression was changed
  before production copy. It failed ten expectations because client, Setup,
  onboarding, AppState, and architecture still contained generic matching-
  version removal guidance and lacked the separately reviewed support-only
  route. Production copy then removed every such recommendation, requires the
  helper to stay registered, and preserves the emergency command's sleep-only
  scope. The focused suite passed all five tests afterward. Exact staged
  package/build verification and restarted independent review remain pending.

## Checkpoint 34 final-review truth-boundary correction — 2026-08-06T12:39:04+0200

| ID | Review finding / corrected invariant | Exact evidence and disposition | Verdict |
|---|---|---|---|
| F34-12 | Setup and onboarding must not promise restoration that runtime evidence cannot prove | Modified UI surfaces still said every helper path restores normal sleep, the override cannot outlive Lidless, and crash/reboot recovery completes within seconds. Architecture already records memory-only fallback and forced-process-loss gaps plus open launchd/hardware gates. The copy now describes layered restoration requests and retries, reports completion only after verified normal sleep, and directs the user to verify uncertain recovery. Absolute “never,” “every,” “always,” and timing claims were removed. | IMPORTANT FOUND / FIXED OFFLINE |
| F34-13 | ServiceManagement `.notFound` cannot mint safe-but-uninstalled state | The install-state refresh collapsed `.notFound` with explicit `.notRegistered`. The installed SDK defines `.notFound` as an error, while this ledger's existing removal policy already classifies it as unknown. Refresh now preserves that distinction. Only explicit `.notRegistered` can yield `.notInstalled` or the post-replacement safe-but-uninstalled message; `.notFound`/unknown blocks retry and never claims the helper is absent. F34-04's earlier broad safe-but-uninstalled wording is narrowed accordingly. | IMPORTANT FOUND / FIXED OFFLINE |

### Final-review truth-boundary evidence log (continued)

- E-512 — 2026-08-06T12:39:04+0200 — The reviewer reported F34-12 and F34-13
  before commit. New source-contract REDs first failed on the absolute recovery
  copy, then on the combined `.notRegistered, .notFound` classifier and absent
  unknown-state retry block. Production changes followed each failure. The
  focused stale-helper suite passed all five tests after both corrections.
  Exact staged package/build verification and a restarted zero-finding review
  remain pending; no live action or commit occurred.

## Checkpoint 34 final-review force-sleep-boundary correction — 2026-08-06T12:44:03+0200

| ID | Review finding / corrected invariant | Exact evidence and disposition | Verdict |
|---|---|---|---|
| F34-14 | Broad revision-mismatched restore proof cannot authorize `sleepnow` | The broadened two-source proof entered `NonSleepRestoreGate.evaluateBaseProof`, whose prior one-shot branch returned `dispatchForceSleep` whenever a cutoff had requested the follow-up. That could send `disarm(forceSleep: true)` to a same-wire revision-6, missing, or future responder even though the broad boundary was authorized only for normal-sleep restoration. The gate now requires exact-current revision 7 before returning `dispatchForceSleep`. A stale structurally restored reply may complete normal-sleep restoration but skips the power mutation; AppState changes the notification, disables the chime/sound, and retains a truthful completion error. | IMPORTANT FOUND / FIXED OFFLINE |

### Final-review force-sleep-boundary evidence log (continued)

- E-513 — 2026-08-06T12:44:03+0200 — The reviewer reported F34-14 before
  commit. A pure RED showed missing, revision-6, and future revision-8 replies
  each returned `dispatchForceSleep` despite complete two-source normal-sleep
  proof; a source-contract RED also found no truthful skip path. After the
  correction, all three mismatches completed normal-sleep restoration without
  force-sleep authorization, the exact-current one-shot regression still
  passed, and the AppState source contract proved the skip copy path. Exact
  staged package/build verification and restarted independent review remain
  pending; no live action or commit occurred.

## Checkpoint 34 terminal-review recovery-fence correction — 2026-08-06T13:11:47+0200

| ID | Review finding / corrected invariant | Exact evidence and disposition | Verdict |
|---|---|---|---|
| F34-15 | Revision-mismatched completion must synchronously retire cached readiness | A broad same-wire restore reply could complete a session while `HelperClient.installState` still cached `.ready`; `finalizeSession()` could then call scheduled-wake reconciliation against the stale responder. Every broad completion surface and failed-arm already-restored path now synchronously invalidates wake reconciliation and records recovery-only helper state before finalization. A refresh epoch prevents an older suspended status refresh from overwriting that demotion. | HIGH FOUND / FIXED OFFLINE |
| F34-16 | Failed-arm structural status is a narrow negative-reply exception | Operation completion and removal still require `reply.ok`. `failedArmDisposition` intentionally does not claim operation success: a negative arm reply's fresh structural OFF status plus independent registry OFF may prove the attempted arm is already restored. Architecture and a revision-mismatch regression now state this exception instead of claiming every negative reply remains recovery work. | IMPORTANT FOUND / FIXED OFFLINE |
| F34-17 | Automatic predecessor replacement must remain bound to the selected target across cleanup preparation | Initial admission was revision-6-only, but generic uninstall also accepted current revision 7 after the `prepareUninstall` suspension. Replacement now carries the exact protocol-6/revision-6 target through preparation and rechecks it before `commitUninstall`. If an exact-current revision-7 responder has taken over, replacement returns ready without cleanup, deregistration, or registration; every other changed target aborts before destructive mutation. Ordinary user removal retains its separately reviewed revision-6-or-7 boundary. | HIGH FOUND / FIXED OFFLINE |
| F34-18 | Different-wire responders must not enter or continue automatic mutation loops | Launch reconciliation now requires same-wire recovery eligibility before query and rechecks the post-await reply. `NonSleepRestoreGate` ends an incompatible-wire generation as manual recovery rather than returning an unbounded retry, and AppState preserves the unresolved session/journal without claiming normal sleep. Established recovery stops dispatching unsupported XPC mutations and surfaces emergency sleep-only/support guidance. | HIGH FOUND / FIXED OFFLINE |
| F34-19 | Force-sleep skip/ambiguity handling must preserve notification opt-out | The new stale-revision skip path overwrote a nil notification title and would notify users who disabled state-change notifications; the adjacent ambiguous-follow-up path had the same defect. Both now rewrite title/body only when notification was already enabled, while retaining truthful error state and one-shot no-repeat behavior. | IMPORTANT FOUND / FIXED OFFLINE |
| F34-20 | Incompatible-wire terminalization cannot clear a late-arm recovery fence | The first F34-18 correction checked wire before `armRequestsInFlight`, so a different-wire reply could clear the generation while a suspended arm later enabled the override. Gate base/follow-up/final decisions now retain ownership while any arm is in flight. Sleep-transition recovery latches the incompatible status, sends no further unsupported mutation, waits only for arm settlement, and enters manual recovery afterward without claiming completion. | CRITICAL/HIGH FOUND / FIXED OFFLINE |
| F34-21 | Unknown helper classification is not an indefinite progress state | `.unknown` includes ServiceManagement `.notFound`, different-wire demotion, and ambiguous terminal classifications. Setup and onboarding no longer render it as “Checking…” with a spinner. They state that helper status is unverified, offer Re-check, explain emergency sleep-only recovery and support boundaries, and never offer automatic install/replacement from unknown evidence. | IMPORTANT FOUND / FIXED OFFLINE |

### Terminal-review recovery-fence evidence log (continued)

- E-514 — 2026-08-06T13:11:47+0200 — Independent review continued after the
  quarantined exact tree from E-510. Each finding above was reported before
  commit; no green package/build result from an earlier tree is reused as final
  evidence.
- E-515 — 2026-08-06T13:11:47+0200 — The F34-15 source contract failed first
  because no synchronous demotion, refresh epoch, or pre-finalization wake
  invalidation existed. Production wiring then covered sleep transition,
  ordinary restore, force-sleep follow-up, quit final proof, and failed-arm
  already-restored completion. The focused stale-helper suite passed afterward.
- E-516 — 2026-08-06T13:11:47+0200 — F34-16 has a pure regression over
  missing, revision-6, and future revision-8 same-wire status. It distinguishes
  unsuccessful operation proof from two-source failed-arm structural status.
  Architecture now records the same narrow exception.
- E-517 — 2026-08-06T13:11:47+0200 — The F34-17 source RED found no expected
  target carried into uninstall and no pre-commit target recheck. The corrected
  sequence rechecks registration, then exact selected target, then cleanup
  authorization, before setting the unresolved-outcome fence and dispatching
  `commitUninstall`. A second RED required the revision-6-to-current-revision-7
  race to return benign ready instead of a false replacement failure.
- E-518 — 2026-08-06T13:11:47+0200 — Pure launch and restore-gate REDs showed
  different-wire armed/pending replies entering restore and returning retry.
  Corrected tests require launch abandonment and terminal manual recovery at
  zero in-flight arms. Source contracts require same-wire cached eligibility,
  post-await validation, and no automatic unsupported retry path.
- E-519 — 2026-08-06T13:11:47+0200 — Notification source-contract REDs first
  found unconditional title replacement in both skipped and ambiguous
  force-sleep follow-up paths. Both paths now preserve nil notification opt-in.
- E-520 — 2026-08-06T13:11:47+0200 — The F34-20 regression first observed
  `.manualRecoveryRequired` and lost gate ownership with
  `armRequestsInFlight == 1`. Base, follow-up, and final proof now return retry
  while retaining ownership at count 1, then terminalize at count 0. A direct
  sleep-transition source contract requires a generation-bound incompatible
  status latch before helper redispatch.
- E-521 — 2026-08-06T13:11:47+0200 — F34-21 source REDs found nine false or
  missing unknown-state UI expectations across Setup and onboarding. The
  corrected focused suites pass six stale-helper tests, thirteen restore-gate
  tests, and seven launch-reconciliation tests. A fresh strict Swift 6 complete-
  concurrency App typecheck with warnings as errors passes all 25 App sources.
  Full exact-tree tests/builds and a zero-material-finding independent review
  remain pending; no live action or commit occurred.

## Checkpoint 35 — one wake-admission boundary and fence integrity — 2026-08-06T14:12:47+0200

Continuation lane (Claude) taking over the paused Codex lane. Every prior claim
was treated as untrusted and re-derived from the working tree; the recorded
handoff HEAD and all four dirty-state fingerprints reproduced exactly before
any edit.

| ID | Finding / invariant | Exact evidence and disposition | Verdict |
|---|---|---|---|
| F35-01 | `refreshInstallState` bypassed the wake-admission boundary | The app never sees the `HelperStatus` that `HelperClient.refreshInstallState()` classifies internally, so a live non-current classification demoted `installState` but left `scheduledWakeReconciliation` holding a confirmation produced by a different responder. A later exact-current takeover then read `begin(desired:)` as already confirmed and never re-dispatched the wake. `retainRecoveryOnlyHelperStateIfNeeded` is now one primitive with two entry points: the status-bearing one demotes the client first, then both converge on a single `!helperState.isUsable` decision. | HIGH FOUND / FIXED OFFLINE |
| F35-02 | The initial install state was rendered as a terminal verdict | `installState` initialised to `.unknown`, which checkpoint 34 had just redefined as a *concluded* "cannot be verified" verdict with emergency/support copy. Every fresh launch therefore showed that terminal copy before anything had been classified. A distinct pre-refresh `.checking` case is now the initial value, is never produced by live evidence, is rendered as progress, and fails both `install()` classification switches closed. | IMPORTANT FOUND / FIXED OFFLINE |
| F35-03 | Failed-arm disposition consumed an unadmitted reply | The demotion was wrapped in `if responseIsOwned`, but a superseded reply is still consumed: `failedArmDisposition` can disarm the phase or start recovery, because a failed arm may have partially applied. The boundary crossing is now unconditional and precedes the ownership guard. Demotion-only plus the live re-classification at the end of that branch makes this the fail-closed direction. | IMPORTANT FOUND / FIXED OFFLINE |
| F35-04 | The incompatible-wire fence was defeated by any later proof loss | Terminalizing deliberately preserves `pendingRestore` and `.disarming` to keep the session and journal live, so the fence was represented only by the absence of a monitor task. `startTerminalRecoveryAfterHelperProofLoss` restarts a monitor from exactly that state, re-dispatching unsupported privileged mutations; when the call throws — the expected outcome for a mismatched responder — the `catch` never consults the gate and the loop retried every 5 s forever, overwriting the manual-recovery instruction with "Lidless will keep checking." An explicit `manualRecoveryGeneration` latch is now consulted by both the monitor's start path and its loop, including after the retry delay. | CRITICAL/HIGH FOUND / FIXED OFFLINE |
| F35-05 | The sleep-transition fence had no representable state | That path clears `pendingRestore` before fencing, so a generation-keyed latch alone reported "recovery still running" for an equally terminal state, and the quit handler overwrote the fence's own message with the false one. It is keyed on `sleepGeneration` instead, which `recordSleepTransition` bumps, so a stale fence cannot be inherited. Exactly two `phase = .disarming` sites exist and both were re-verified. | HIGH FOUND / FIXED OFFLINE |
| F35-06 | Quit copy claimed verification that had stopped | `.disarming` no longer implies work in progress. The quit refusal now branches on `automaticRecoveryStopped`, states that Lidless cannot clear the state itself, and names force-quit. The first correction of this copy asserted force-quit "will not change the current sleep setting", which `HelperDaemon.connectionEnded` → `.restoreOwnedSession` → `performRestore` refutes; the final wording claims only that force-quit cannot make the setting worse and that ending the connection is a signal *a* Lidless helper treats as a restoration trigger — hedged because the fenced responder's protocol is by definition unverifiable. | IMPORTANT FOUND / FIXED OFFLINE |
| F35-07 | A concluded `.unknown` was invisible outside Setup | `AppState.statusDetail` and the menu-bar banner both excluded `.unknown` from their "helper needs attention" condition, written when `.unknown` meant "not yet checked". Both now suppress only `.checking`, and terminal states (`.unknown`, `.notResponding`, non-reviewed `.stale`) get a `.warning` banner, truthful text, and an "Open Setup…" action instead of a one-tap "Set Up…" chore. Setup's status icon no longer marks a terminal stale revision with the retryable circular-arrows glyph. | IMPORTANT FOUND / FIXED OFFLINE |
| F35-08 | Removal-failure guidance contradicted what the code proved | The alert appended "Do not assume the helper is still installed after an error" to every failure, including the seven paths whose own message states that no cleanup or deregistration was requested — pushing the user toward manual removal, the one action that strips launchd's KeepAlive/RunAtLoad supervision from a provably intact helper. `HelperRemovalFailureInfo.didNotStartKey` now marks codes 5, 6, 7, 10, 11, 12 (both sites) and 13; codes 3, 4, 8 and 9 stay ambiguous (code 4 delivered `commitUninstall`, so remote cleanup did run). Guidance is composed alongside the failure. The uninstall button stays enabled: gating it on a cached classification would reintroduce the cached-eligibility anti-pattern this repair removed. | IMPORTANT FOUND / FIXED OFFLINE |
| F35-09 | Replacement understated an irreversible sequence | "Helper safety update required" + "Replace Helper…" ran remote cleanup, deregistration and re-registration with no disclosure. Both Setup and onboarding now state that replacing removes the current helper first — cancelling its scheduled wakes, restoring the other settings it manages, deleting its data, deregistering it — and that a failed re-registration leaves no helper registered. | IMPORTANT FOUND / FIXED OFFLINE |
| F35-10 | A possibly-applied wake was classified as an explicit rejection | A responder replying `ok: true` from a refused revision may already have programmed the RTC wake. Reusing `.rejected` recorded no ordering hazard. `scheduleWake` now splits the guards: `!reply.ok` throws `.rejected`; refused-after-delivery throws the new `HelperClientError.outcomeUnknown`, which maps to `.uncertain` and sets the sticky hazard. | MINOR FOUND / FIXED OFFLINE |
| F35-11 | Launch wake maintenance was dead code | `reconcileWithHelper`'s trailing `maintainScheduledWake()` always self-blocked on its own `!launchReconciliationInFlight` guard, because the `defer` clears the flag at function exit. The exclusion is now released explicitly after the decision and demotion — preserving its ordering rule — and before that maintenance pass. | MINOR FOUND / FIXED OFFLINE |
| V35-01 | Strict TDD with observed RED on every change | Each of the fourteen new regressions failed first against the pre-change tree (8, 13, 1, 5, 9, 2, 1 and 5 discriminating expectations across the successive passes) before any production edit. The strict Swift 6 typecheck independently produced the RED for `.checking` by rejecting two non-exhaustive `install()` switches. | PASS — RED OBSERVED |
| V35-02 | Complete verification at the final tree | 357 tests in 35 suites; strict Swift 6 complete-concurrency typechecks with warnings-as-errors over 25 App, 4 Helper and 1 Widget sources; Debug and Release `LidlessCore` builds; Debug and Release unsigned `xcodebuild` with verified bundle layout. Baseline before this lane was 343 tests. | PASS FOR WORKING TREE |
| V35-03 | Independent adversarial review reached zero material findings | Three review passes on Opus-class reasoning against the live tree. Pass 1 independently reproduced F35-01 and F35-02 and found F35-04/F35-06/F35-07/F35-08/F35-09; pass 2 found F35-05 and refuted nothing already fixed; pass 3 refuted the force-quit clause in F35-06 with a direct daemon citation. Every reported defect was reproduced in the code before being accepted. | PASS |
| G35-01 | No live behaviour is proved | No app, helper or widget was launched; no install, activation, registration, unregister, approval, live XPC, `pmset`, sleep-setting mutation, sleep/wake, hardware, signing, notarization, network, merge, push or release action occurred. `xcodebuild` runs its normal `lsregister` bundle-registration build phase; that registers the built bundle with LaunchServices and does not install, activate or contact the privileged helper. | OPEN LIVE GATE |
| G35-02 | Other confirmed package defects remain separate | Crash-session journal finalization, scheduled-wake transaction durability, Homebrew raw-`launchctl` lifecycle bypass, release-artifact permission validation, and the earlier storage/removal/live-proof groups are untouched by this checkpoint. | OPEN SEPARATE GROUPS |

### Checkpoint 35 append-only evidence log

- E-522 — 2026-08-06T14:12:47+0200 — Recovery began from feature HEAD
  `de9d9db3b7964de0f86f75772b5a82063564e709` on branch
  `codex/lidless-safety-repair-2026-08-04`. Before any edit, the recorded
  handoff fingerprints reproduced exactly: combined `git diff HEAD --binary`
  `9839001466efe26ca922f59b190d6a2596476f8637d1d51dfefee7cf8b4db8f9`, cached
  `ebc9282c3b7dcc7d14e0d1a37dc51dd3a807fbfca588d0ea811847f2a04036bf`,
  unstaged `159cc8744fb2bab1999f068a7d597f9f20ad13b53cafbfb4a8991108b0176810`,
  and untracked design brief
  `4835b0dc2fa44257d2e4aca6429e5bd5ad1cf93989686c709311d91b9659e7f7`. The
  Git index was never modified during this lane; its digest is unchanged at
  commit time.
- E-523 — 2026-08-06T14:12:47+0200 — The central invariant was audited ingress
  by ingress rather than by inspection of the previously claimed paths. Sleep
  transition, restore monitor, force-sleep follow-up, quit final proof,
  failed-arm disposition, launch reconciliation, heartbeat, `scheduleWake`,
  `refreshInstallState`, and `install`/`uninstall`/`prepareUninstall` were each
  traced to either a boundary crossing or an `AppState`-level invalidation.
  Two ingresses did not cross it (F35-01, F35-03); both now do.
- E-524 — 2026-08-06T14:12:47+0200 — Verification reproduced the repository's
  own commands under the documented stable toolchain
  `/Applications/Xcode.app` (Xcode 26.5), not the active 27.0 beta:
  `swift test --package-path Packages/LidlessCore` (357 tests, 35 suites);
  `xcodebuild -project Lidless.xcodeproj -scheme Lidless -configuration
  {Debug,Release} CODE_SIGNING_ALLOWED=NO build` with the CI bundle-layout
  assertions; Debug and Release `swift build` of `LidlessCore`; and the
  recorded strict typecheck
  `swiftc -typecheck -swift-version 6 -strict-concurrency=complete
  -warnings-as-errors -target arm64-apple-macosx15.0` over all App, Helper and
  Widget sources. One setup failure is preserved and not counted: the first
  Helper typecheck wrongly passed `-parse-as-library` to a target with a
  top-level `main.swift`; the corrected invocation passed.
- E-525 — 2026-08-06T14:12:47+0200 — The independent reviewer was read-only and
  ran no privileged, lifecycle or state-mutating command. Two of its findings
  were rejected as written and re-scoped after direct code inspection: a
  proposed negative assertion that would have banned the terminal `case .stale:`
  arm outright, and the suggestion to disable the uninstall button in
  guaranteed-failure states, which would have reintroduced cached-eligibility
  gating. Three pre-existing test assertions pinned code shapes this checkpoint
  deliberately changed — `if responseIsOwned`, `guard reply.ok,` (committed at
  HEAD as a proxy for "never accept an ok-only reply"), and the SetupPane
  removal-alert copy. Each was re-verified for provenance and rewritten to test
  the underlying invariant at its new location rather than deleted.
- E-526 — 2026-08-06T14:12:47+0200 — Accepted as-is, with reasons rather than
  silence: an ambiguous force-sleep follow-up still plays its notification
  sound while the skipped path does not (cosmetic, no truth claim); a
  follow-up-stage `.manualRecoveryRequired` reports "without claiming normal
  sleep" even though base-stage two-source proof already succeeded
  (conservative in the safe direction); and `markForceSleepFollowUpSkipped`
  can say "skipped" for a request that was dispatched (cosmetic, terminal path
  only). None affects a gate decision.
- E-527 — 2026-08-06T14:12:47+0200 — No app, helper, widget or compiled product
  was launched. No install, activation, registration, unregister, approval,
  live XPC, `pmset`, sleep-setting mutation, sleep/wake, hardware, signing,
  design/Figma, authentication, credential, provider, plugin/MCP, connector,
  network, merge, push, deploy, release, or main-checkout mutation occurred.
  All verification artifacts are under the git-ignored `build/` tree.
- E-528 — 2026-08-06T14:12:47+0200 — A late review pass found that the fenced
  copy was written to `lastError` but was unreachable: `lastError` renders only
  in `MenuPanelView`, `SetupPane` and `OnboardingView`, `OverviewPane` renders
  it nowhere, `mainPane` defaults to `.overview`, and `requestMainWindow(pane:)`
  assigns the pane only when one is passed. The fenced user therefore saw only
  the `.restoring` hero, "Restoring sleep…" — precisely the false impression the
  fence exists to remove — and the copy telling them to open Setup & Help did
  not take them there. All four quit-refusal branches in
  `applicationShouldTerminate`, the incompatible-wire fence, and
  `repairOverride`'s "Open Setup" branch now pass `pane: .setup`.
  `beginArmFlow`'s bare `requestMainWindow()` is deliberately left alone: it
  sets no error text at all, so routing it would not fix it, and deciding what
  it should say is outside this checkpoint. It is recorded here as open.
- E-529 — 2026-08-06T14:12:47+0200 — Committed roster (24 paths): `ARCHITECTURE.md`;
  `App/Sources/{AppState,LidlessApp}.swift`; `App/Sources/Helper/HelperClient.swift`;
  `App/Sources/Simulation/Simulation.swift`;
  `App/Sources/UI/{Main/SetupPane,MenuBar/MenuPanelView,Onboarding/OnboardingView}.swift`;
  this status ledger; `Packages/LidlessCore/Sources/LidlessCore/{HelperRemovalSafety,LaunchReconciliationSafety,LidlessIDs,NonSleepRestoreGate,SleepOverrideSafety}.swift`;
  and nine `Packages/LidlessCore/Tests/LidlessCoreTests` suites. Deliberately
  excluded and left uncommitted so the founder still owns them:
  `Docs/orchestration/decisions.md` and `Docs/orchestration/progress.md`, whose
  pending edits are the 2026-08-04 design-reset entry, and the untracked
  `Docs/orchestration/tasks/2026-08-04-design-reset-brief.md`
  (`4835b0dc2fa44257d2e4aca6429e5bd5ad1cf93989686c709311d91b9659e7f7`,
  unchanged throughout this lane).
- E-530 — 2026-08-06T14:12:47+0200 — Remaining risks and next step. Every live
  gate from checkpoint 34 stays open and this checkpoint adds no runtime proof:
  the fence, the wake-admission demotion, replacement, and removal guidance are
  all verified only against source, pure policy, and source-order contracts. A
  fenced session still cannot be resolved inside the app — quitting from the
  menu stays blocked while normal sleep is unverified, and making it resolvable
  would need single-source completion after user-performed emergency recovery,
  a policy change this lane was not authorized to make and which the founder
  should rule on. `beginArmFlow`'s silent window request is open. The next step
  is a founder decision on that fenced-session exit policy, then the live
  hardware shakedown that every offline checkpoint has deferred.
- E-531 — 2026-08-06T14:12:47+0200 — Routing the fenced state to Setup made the
  removal refusal reachable directly from it, where "Lidless is keeping the
  helper installed while recovery continues" was false: recovery had terminally
  stopped. The refusal itself is correct — `canProceedRemoval(isDisarmed:)`
  rightly declines — so only its reason was corrected, branching on
  `automaticRecoveryStopped`. The reviewer's final summary also listed the
  launch-reconciliation dead-call (F35-11) as still open; that note was stale
  from an earlier pass and the fix was re-verified in place before the report
  was accepted. Review reached zero unresolved Critical, High or Important
  findings at the committed tree.
