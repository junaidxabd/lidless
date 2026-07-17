# Lidless — Progress Log

> Session log, newest entry first. A fresh Claude session starts by reading this file, then `decisions.md`, then `ARCHITECTURE.md`. Pattern borrowed from NugVue's `docs/web-build/orchestration.md`.

---

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
