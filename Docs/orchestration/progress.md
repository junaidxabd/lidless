# Lidless — Progress Log

> Session log, newest entry first. A fresh Claude session starts by reading this file, then `decisions.md`, then `ARCHITECTURE.md`. Pattern borrowed from NugVue's `docs/web-build/orchestration.md`.

---

## 2026-08-07 — Dark-only local release candidate

### Product and visual system

- Rebuilt every shipping surface as a fixed-dark native macOS safety
  instrument. Removed the rejected eye/character, aurora, glow, draggable glass
  switch, SF Rounded, and decorative hero language from app, widget, icon,
  screenshot tooling, and public copy.
- Added explicit verified-normal, verified-armed, restoring, outside-override,
  stale/unverified, helper-setup, confirmation, refusal, and long-error states.
- Stale widget snapshots now suppress old telemetry and say only that current
  sleep and battery evidence is unknown; snapshot age never infers that the app
  stopped running.
- Added a complete checked-in render pipeline for 11 canonical menu states, a
  12-combination responsive window matrix, 7 secondary panes, 4 onboarding
  states, 4 widget states, 10 icon sizes, and 6 contact sheets.
- Regenerated the complete PNG set twice with identical combined hash
  `29ebab464ccf83376b0b9d8ef21d7e50057d57b4851e2b69bbcd0d55b14f07b0`
  and inspected every contact sheet at original detail.

### Safety, engineering, and release policy

- Normalized configuration and hardened battery/thermal evidence, arm
  confirmation, cutoff ordering, critical pressure, and clock rollback.
- Hardened helper admission, request completion, bounded child reaping,
  sentinel/watchdog/termination behavior, durable boot-bound mutation
  uncertainty, and launchd recovery witnesses.
- Rebuilt scheduled wakes as a fail-closed parser plus durable intent/readback/
  cancellation ledger with duplicate and crash/reboot reconciliation.
- Made config/session persistence failures explicit; first-checkpoint failure
  now restores instead of presenting armed, every new arm is fenced by prior
  unresolved evidence, finalized records outrank stale journals, corrupt
  history bytes are preserved, failed clearing restores rows for retry, and a
  later save cannot hide the unresolved load error behind the active arm fence.
- Disabled automatic stale-helper replacement and cleanup. Dead removal policy
  code is gone; compatibility entry points refuse without real or simulated
  mutation.
- Hardened CI/release permissions, checkout credential behavior,
  universal-architecture verification ordering, exact three-path launchd
  recovery validation, and deterministic fixtures.
- Removed the unmarked stale `ARCHITECTURE 2.md`; a source contract now permits
  only the canonical root `ARCHITECTURE.md`.

### Fresh verification

- Final repository-local Core run: 429 tests in 43 suites passed.
- New pristine cache/scratch run: 429 tests in 43 suites passed.
- SwiftPM Release-configuration run: 429 tests in 43 suites passed.
- Strict Swift 6, complete-concurrency, warnings-as-errors compilation passed
  for app, helper, and widget sources.
- XcodeGen regeneration produced an identical project hash.
- Shell syntax and all product/release property lists passed.
- Full Xcode Debug/Release/analyze remains environment-blocked before target
  compilation by the managed nested package sandbox; no success is claimed.
- Independent product, engineering, and safety review findings were reproduced,
  fixed, and re-reviewed; no Critical or Important local-boundary finding
  remains.
- Signing, helper approval, live power/system mutations, crash/reboot/sleep and
  hardware tests, WidgetKit hosting, accessibility input QA, notarization, and
  release remain fresh-authorization gates.

### Durable handoff

- Verification: `../verification/local-rc-2026-08-07.md`
- Live/recovery plan: `../verification/recovery-and-live-validation.md`
- Successor handoff: `LIDLESS-LOCAL-RC-HANDOFF-2026-08-07.md`
- The 2026-08-04 adaptive/light direction is historical and superseded by the
  current dark-only authority in `decisions.md`.

## 2026-08-04 — Safety repair + design reset discovery

### Safety repair (isolated branch; not installed or merged)

- Branch: `codex/lidless-safety-repair-2026-08-04` in a dedicated worktree.
- Sleep override arming/restoration now require exact readable proof; unknown
  state never becomes success. Recovery remains visible and retries until normal
  sleep is verified.
- XPC peer trust now fails closed without a signed same-team app identity.
- Helper protocol is v6; widget and app expose unknown/unverified state.
- 164 core tests pass. Debug and Release unsigned compile checks and Debug static
  analysis pass. Signed runtime/helper activation remains deliberately untested.

### Design reset Phase 0

- Created a blank Figma draft:
  https://www.figma.com/design/YkIFq8wiDpjYBwxpyO56LQ
- Inspected the empty file, available fonts, and Apple macOS libraries. No canvas
  objects, variables, styles, or components have been created yet.
- The founder's current from-scratch instruction supersedes the prior eye,
  Happy Mac, aurora, glow, rounded-type, dark-only direction.
- Approval brief: `tasks/2026-08-04-design-reset-brief.md`.
- Next: founder approves or revises the direction; then build Figma foundations,
  components, core states, and overview before any SwiftUI visual rewrite.

### External gates still untouched

- No VM resume, Apple ID sign-in, Messages/iMessage setup, group creation, bot
  send, analytics authentication, provider configuration, connector setup,
  install, merge, push, or deployment.

## 2026-07-17 — Session 1 (full build + design exploration)

### Shipped (pushed to https://github.com/junaidxabd/lidless, main, CI green)
- Complete working app: menu bar panel, main window (5 panes + simulator), privileged
  SMAppService helper with layered safety net, WidgetKit widget, `--simulate` dry-run mode,
  151 passing core tests, GitHub kit (README/ARCHITECTURE/LICENSE/CONTRIBUTING/CI/release
  script/cask). 7 commits. CI verified on fresh runners (one Swift 6.0 vs 6.3 compiler
  divergence found & fixed: non-Sendable SMAppService sending — see decisions.md).
- Adversarially reviewed by agent fleets: 53-agent review (24 confirmed findings, all fixed),
  8-verifier fix-verification pass (uninstall-gate bypass, arm-timeout outcome-unknown
  regression, thermal-debounce defeat, RTC-wake reconciliation, widget staleness, ephemeral
  sim stores — all fixed). Details in git history.
- Current shipped UI: dark-locked "liquid glass v1" (aurora, glass slide-switch, SF Rounded).
  Functional and clean, but superseded by the v4 design direction below — NOT yet implemented.

### Design exploration (mockups only — NOT implemented in Swift)
Direction evolved through user feedback:
eye motif (creepy) → beacon eye (still creepy) → mascot on closed lid (creepy) →
**APPROVED-PENDING: Susan Kare Happy Mac face on the SCREEN of an open MacBook** —
space-black machine, rim-lit, screen as sole light source, face carved into the glow.
- v4 hero mockup: `build/mockups/final4-armed.png` (source: `mock4-armed.html`)
- Built via ultracode loop: 4-agent material research (Apple refs + liquid-glass recipes)
  → rebuild → 3-critic pixel-level critique (scored 5/4/6, 24 measured fixes) → v4.
- Research corpus: `build/research/` (Apple MacBook hero, Kare article screenshot,
  threads/dribbble captures). Technique toolbox lives in the workflow results and is
  summarized in decisions.md §Design.

### VERDICT ON v4 (end of session 1)
Junaid: "better, but... it feels like the type of app that was cheaply made to look
expensive." KEEP: mascot concept (Kare face on open MacBook screen), dark mood, panel
structure. REJECTED: the visual execution — glow/gradient theatrics ≠ polish.

### In progress / next up (in order) — see tasks/2026-07-17-design-rethink-brief.md
1. TASTE BOARD FIRST: Threads "look" loop over Junaid's saved favorites (he scrolls the
   automation Chrome on threads.com/saved; on "look" → screenshot + analyze why it reads
   high-quality). Build the board before designing anything.
2. Rethink the panel's visual execution against the taste board; mockups → approval.
3. Implement approved design in SwiftUI (mascot = animatable Shape view; logic untouched;
   Swift 6.0-compatible). Then screenshots, README, push.
4. Still open from earlier: state-set + icon mockups; real-hardware overnight helper
   shakedown; team signing for widget + notarization; possible repo transfer → nugvue.

### Collaboration loops with Junaid
- Mockups BEFORE Swift. He iterates fast via chat feedback mid-turn; render → send image →
  react. Never claim a visual is good without looking at the render.
- Threads "look" loop: automation Chrome is logged into his Threads. He scrolls his Saved
  feed; when he says "look", screenshot and analyze the visible post as a design reference.
- ultracode is his standing opt-in for agent fleets; the research→build→critique loop
  (with pixel-measuring critics) is the proven design pattern.

### Environment notes
- Xcode 26.5 / Swift 6.3 local; CI runners are Xcode 16.4 / Swift 6.0 — keep code 6.0-compatible.
- xcodegen installed; project.yml is authority, xcodeproj committed. `make build/test/screenshots`.
- Local build quirk: stale embedded-binary signing errors → `rm -rf build/DerivedData` fixes.
- chrome-devtools MCP drives a persistent visible Chrome (Threads session lives there).
- Mockup pipeline: write HTML → navigate file:// → resize_page → take_screenshot → Read → iterate.
