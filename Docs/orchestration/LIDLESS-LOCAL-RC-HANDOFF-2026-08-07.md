# Lidless Local RC Handoff — 2026-08-07

## Current truth

Lidless is a verified **local** release candidate inside the corrected,
offline task root. The dark-only redesign, policy hardening, privileged-helper
recovery model, scheduled-wake transaction, persistence truth, cleanup
refusals, release policy, deterministic visual evidence, and documentation are
implemented and locally verified.

It is not signed, installed, notarized, published, or proven on live power
hardware. Those boundaries are intentional, not unfinished claims.

Repository:
`/Users/junaid/Documents/Codex/2026-08-07/lidless-completion-clean-20260807-2/outputs/Lidless`

Task-contract branch: `codex/lidless-completion-clean2-2026-08-07`

Task-contract start: `b093e3d`

The checkout's `.git` link points outside the authorized output root. No
staging, commit, or push was attempted. Continue working from the files in this
task root; obtain a fresh exact instruction before any operation that would
need the external Git metadata or mutate a remote.

## Read this order

1. [`local-rc-2026-08-07.md`](../verification/local-rc-2026-08-07.md) — exact
   evidence, limits, hashes, and gates.
2. [`ARCHITECTURE.md`](../../ARCHITECTURE.md) — current safety and trust model.
3. [`decisions.md`](decisions.md) — current dark-only/product/process authority.
4. [`recovery-and-live-validation.md`](../verification/recovery-and-live-validation.md)
   — approval-gated operator plan.
5. [`progress.md`](progress.md) — chronological lane record.

`LIDLESS-SAFETY-REPAIR-STATUS-2026-08-05.md` and the July/August reset briefs
are historical evidence. They do not override this handoff, the current
architecture, or the founder's latest dark-only direction.

## What changed

- Replaced the rejected neon/aurora/character/eye/rounded-type UI with a quiet
  native dark safety instrument across menu, window, panes, onboarding, widget,
  menu-bar symbols, public copy, and the complete icon set.
- Unified all surfaces around explicit proof states and one truthful primary
  action; refusal, restoring, outside-override, stale, and unknown states no
  longer borrow optimistic language or controls.
- Normalized all cutoff inputs and hardened battery/thermal evidence, critical
  pressure, clock rollback, arm confirmation, and cutoff ordering.
- Hardened XPC admission, bounded child termination, sentinel/watchdog/launchd
  recovery, boot-bound durable mutation uncertainty, and exactly-once request
  completion.
- Added a fail-closed scheduled-wake parser, durable ledger and launchd witness,
  exact readback, duplicate cancellation, and crash/reboot reconciliation.
- Made config/session persistence failures explicit, fenced every new arm while
  prior evidence is unresolved, required the first journal before armed UI,
  retained/retried finalized journals until truthful history is durable,
  preserved corrupt history bytes, and made failed history clearing
  transactional and retryable. Unresolved load failures remain visibly
  distinct from later save results, so a fail-closed admission fence never
  loses its explanation.
- Removed dead helper-removal policies and automatic replacement/cleanup. App,
  client, helper compatibility selectors, and simulator now refuse cleanup
  without mutation.
- Hardened release workflow permissions, checkout credential handling,
  universal-architecture ordering, exact three-path launchd recovery
  verification, and deterministic local policy fixtures.
- Checked in complete simulation-only app/widget render harnesses and contact
  sheets; the entire PNG matrix regenerates byte-identically.

## Fast local re-verification

From the repository root:

```bash
make test-local
make visual-evidence
bash -n Scripts/*.sh
plutil -lint App/Resources/Info.plist \
  Widget/Resources/Info.plist \
  Helper/Resources/com.lidless.helper.plist \
  App/Resources/Lidless.entitlements \
  Widget/Resources/LidlessWidget.entitlements \
  Scripts/ExportOptions.plist
```

The final completion run additionally used a new isolated SwiftPM cache and
scratch path. It passed **429 tests in 43 suites**. Strict Swift 6 compilation
with complete concurrency and warnings-as-errors passed for app, helper, and
widget; a separate SwiftPM Release-configuration run also passed all 429 tests.
XcodeGen regenerated with an identical project hash. The complete visual
artifact hash was stable across consecutive full renders.

Independent product, engineering, and safety reviewers found and verified the
closure of stale-widget truth, launchd-verifier, unresolved-session overwrite
and relabeling, corrupt-history preservation, failed-clear recovery, and stale
load-error visibility, plus the stale duplicate-architecture defect. Their
final follow-ups report no unresolved Critical or Important defect inside the
local verification boundary.

## Known environment limitation

The managed workspace blocks Xcode's nested Swift package sandbox during
package resolution (`sandbox_apply: Operation not permitted`) before target
compilation. Therefore Debug/Release bundle assembly and static analysis are
not claimed here. Direct strict target compilation is green, but signed bundle
graph, entitlements, embedding, runtime trust, and notarization must be
verified in an authorized unrestricted Xcode environment.

## Remaining gates

- One real signing team across app, widget, helper, and app group.
- Signed helper registration/approval and same-team XPC behavior.
- Live `pmset`, registry, watchdog, crash/relaunch, reboot/power-loss,
  sleep/wake, force-sleep, and scheduled-wake matrix.
- Real battery/thermal/closed-lid hardware behavior.
- Signed WidgetKit app-group and deep-link behavior.
- Hands-on VoiceOver, keyboard, focus, contrast, Reduce Motion, and long-copy
  QA.
- A separately reviewed signed helper-removal procedure.
- Notarization, stapling, packaging, publication, and release.

Every item above needs a fresh exact instruction. Do not weaken a refusal,
clear durable evidence, remove launchd supervision, or treat the manual
`disablesleep 0` fallback as full cleanup to make a live test appear green.

## Visual evidence

- [`menu-contact-sheet.png`](../screenshots/menu-contact-sheet.png)
- [`window-contact-sheet.png`](../screenshots/window-contact-sheet.png)
- [`secondary-contact-sheet.png`](../screenshots/secondary-contact-sheet.png)
- [`onboarding-contact-sheet.png`](../screenshots/onboarding-contact-sheet.png)
- [`widget-contact-sheet.png`](../screenshots/widget-contact-sheet.png)
- [`icon-contact-sheet.png`](../screenshots/icon-contact-sheet.png)

## Successor starting point

No routine local product or engineering decision is waiting on the founder.
The next meaningful lane begins only when one of the signed/live/release gates
above is explicitly authorized. Before crossing it, rerun the local suite and
visual evidence, record the immutable source identity, then follow the
approval-gated matrix rather than improvising on a real machine.
