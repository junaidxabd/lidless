# Lidless Local RC Handoff — 2026-08-07

> Refreshed 2026-08-08 after the live UI/accessibility QA checkpoint. The
> local implementation is verified, but the founder-requested Overview
> refinement remains active and is not yet part of a final RC verdict.

## Current truth

Lidless is a verified **local checkpoint** inside the corrected, offline task
root. The dark-only redesign, policy hardening, privileged-helper
recovery model, scheduled-wake transaction, persistence truth, cleanup
refusals, release policy, deterministic visual evidence, and documentation are
implemented and locally verified.

It is not signed, installed, notarized, published, or proven on live power
hardware. Those boundaries are intentional, not unfinished claims.

Repository:
`/Users/junaid/Documents/Codex/2026-08-07/lidless-completion-clean-20260807-2/outputs/Lidless`

Task-contract branch: `codex/lidless-completion-clean2-2026-08-07`

Task-contract start: `b093e3d`

The founder explicitly authorized feature-branch commits and pushes. The
implementation checkpoints through `b3002f1` are on
`origin/codex/lidless-completion-clean2-2026-08-07`; main was not merged or
pushed. The latest visual-regression checkpoint is `f34550c`. Continue using
only this task-owned repository and feature branch.

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
- Live UI QA then fitted onboarding to its real sheet, made disclosure and
  safety controls explicit to accessibility, suppressed simulation-only
  notification/widget side effects, added useful chart summaries, and fixed
  selected History at the minimum supported window size.
- The Overview evidence matrix now covers verifying, restoring, and every arm
  confirmation/refusal at minimum/default/wide sizes, with a dedicated
  transition contact sheet.
- A maximum-text-size stress matrix now covers the dense long-error menu,
  minimum Overview confirmation, and recovery onboarding without clipped
  actions or unsafe copy loss.
- No-internal-battery simulation now drives truthful menu, Overview, and
  Simulator states. Battery-dependent controls disable, history and floor
  semantics become explicitly inactive, and the state is covered at every
  supported Overview width plus a dedicated Simulator render.
- Charging and battery-power simulation states are mutually consistent;
  charging removes the drain claim and marks the floor paused on power across
  the menu and every Overview width. The schedule editor now scrolls under
  maximum text sizing while its Cancel/Save actions remain pinned.
- Populated History is now also captured at maximum text size in the minimum
  window; its selected row, stat cards, chart, and audit copy remain unclipped.
- Every populated Schedule enable switch now announces the days and time range
  it controls instead of an ambiguous generic label.

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

The post-UI Debug and independent Release SwiftPM runs each passed **443 tests
in 44 suites**. Strict Swift 6 compilation with complete concurrency and
warnings-as-errors passed for app, helper, and widget. The unsigned Debug Xcode
graph passed after the charging/editor functional changes. After the final
layout-height tightening, macOS file coordination hung subsequent Xcode
invocations before project loading, including a fresh isolated regenerated
project; exact-source Release/analyze is therefore pending rather than claimed.
XcodeGen still regenerated with an identical project hash. The
complete visual artifact hash
`4363524e2ba85990bcf36706c1c2e4eb278eb237fcaa2ef88e99d5c250bef661`
was stable across consecutive full renders.

Independent product, engineering, and safety reviewers found and verified the
closure of stale-widget truth, launchd-verifier, unresolved-session overwrite
and relabeling, corrupt-history preservation, failed-clear recovery, and stale
load-error visibility, plus the stale duplicate-architecture defect. Their
final follow-ups report no unresolved Critical or Important defect inside the
local verification boundary.

## Current local limitation

The last full unsigned Xcode graph is locally green; the current exact source
is directly compiled and visually rendered, but its final Release/analyze
rerun remains blocked before project loading by macOS file coordination. The
last full graph proves analysis and unsigned bundle layout for its checkpoint;
the current direct checks prove source compilation only. Neither proves signing,
entitlements at runtime, helper trust, privileged behavior, or notarization.
The app ran in a unique simulation-only bundle and exposed its status item,
but this desktop session created zero inspectable app windows for every
shell-launched app tested, including Finder and Preview. Temporary activation
experiments were reverted. A bounded live popover pass remains pending in a
normal interactive window-server session.

The ignored diagnostic copy at
`build/xcode-verify-roots/ui-stress-serial` is about 2.3 GB. It contains only a
task-local project copy and build caches; automated destructive cleanup was
blocked, so a later local cleanup may remove that exact directory.

## Remaining gates

- Founder approval of the proposed Overview proof-spine composition, followed
  by implementation and a repeated minimum/default/wide visual pass.
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
- [`window-transition-contact-sheet.png`](../screenshots/window-transition-contact-sheet.png)
- [`accessibility-contact-sheet.png`](../screenshots/accessibility-contact-sheet.png)
- [`secondary-contact-sheet.png`](../screenshots/secondary-contact-sheet.png)
- [`onboarding-contact-sheet.png`](../screenshots/onboarding-contact-sheet.png)
- [`widget-contact-sheet.png`](../screenshots/widget-contact-sheet.png)
- [`icon-contact-sheet.png`](../screenshots/icon-contact-sheet.png)

## Successor starting point

The immediate local lane is the approved Overview refinement, followed by a
repeat of the live and deterministic UI matrix. All other routine local
verification is pre-authorized. Before crossing a signed/live/release gate,
rerun the local suite and visual evidence, record the immutable source identity,
then follow the approval-gated matrix rather than improvising on a real
machine.
