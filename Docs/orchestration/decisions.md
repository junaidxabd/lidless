# Lidless — Decision Log

> Append-only rationale for non-obvious choices. Architecture decisions live in
> `ARCHITECTURE.md`; this file covers process + design-direction decisions.

## Process
- **Files are the source of truth** (pattern from NugVue `docs/web-build/orchestration.md`):
  session state lives in `Docs/orchestration/progress.md`; a fresh chat reconstructs from
  files, not from conversation memory.
- **Design changes ship as mockups first** (`build/mockups/*.html` → Chrome screenshot),
  user approves, only then Swift. The HTML mockups are throwaway; the recipes transfer.
- **ultracode loops**: research fleet → inline build → adversarial critique fleet with a
  structured fix schema. Critics must compare against real references (Apple marketing
  pages, Kare originals) and return measured, CSS-level fixes — vague critique is rejected.

## Design direction (v4, 2026-07-17)
- **Mascot**: Susan Kare's Happy Mac face rendered ON the screen of an open MacBook.
  A face on a screen is content (charming, heritage); a face on hardware is a creature
  (creepy — three rejected iterations proved it). Softened-pixel hint: blocky corner radii
  + faint pixel grid, not literal pixelation. Face geometry follows Kare: 1:2 eye slots,
  tall hooked nose from the eye-top line, one continuous smile with upturned caps under
  the eye outer edges, near-uniform stroke.
- **Light model**: one key light (top, slightly left); machine is space-black defined by
  rim light; the screen is the only emitter — its glow lands on the hinge (cyan,
  center-peaked), pools on the plate below, and every shadow is navy-tinted, below-only.
  (From Apple MacBook-hero study + joshwcomeau shadow doctrine.)
- **Liquid glass**: one true glass plate (the panel) — backdrop blur 26 saturate 165
  brightness 1.12 over a visible aurora; gradient specular rim decaying from the lit
  corner; caustics at 0.25 opacity; never glass-on-glass (switch is tinted gradient, puck
  is a machined solid bead).
- **Type**: SF Pro Rounded; countdown is the ONLY 700+ weight, tabular numerals, whisper
  glow (no halo, no dark drop); AWAKE is a tinted-glass status chip, not a CTA; letterpress
  text-shadows banned.
- **Structure**: header (wordmark / frosted icon buttons / status chip) → machine hero →
  headline + big countdown → glass slide-switch (Sleep⟷Awake, draggable puck) → single
  inset stat well (battery/drain/thermals). No footer bar (user rejected it).
- **Dark-mode locked** by design; Reduce Motion stills all animation, keeps glow.

## Design execution verdict (2026-07-17, end of session 1)
v4's rendering was rejected: "cheaply made to look expensive." Direction (mascot, structure,
mood) stands; execution must be rebuilt taste-first from Junaid's own Threads references.
Lesson recorded: glow quantity is not quality — polish is restraint, optics, spacing, true
materials. Next session starts with the taste board, not with more effects.

## Pending user decisions
- Mascot name? (appears in onboarding copy)
- Replace app icon with the v4 mascot icon? (current icon is still the old eye)
- Face size / screen hue / panel darkness fine-tuning after seeing the full state set.
- Repo home: stays on junaidxabd or transfers to nugvue.

## Design reset (2026-08-04; supersedes v4 visually)

The founder subsequently said the Lidless UI was disliked and asked for a new
design from scratch. That current instruction supersedes the v4 visual direction
above, including its Happy Mac mascot, eye metaphor, aurora/glow treatment,
SF Rounded typography, and dark-mode lock. The history remains here so rejected
ideas are not accidentally rediscovered and presented as new.

The replacement direction is a quiet, adaptive, native macOS safety instrument:
state before brand, visible verification, one primary action, sparse semantic
color, SF Pro, native materials, and no decorative hero. The exact Phase 0 brief
is in `tasks/2026-08-04-design-reset-brief.md`. Figma foundations and screens are
approval-gated; no SwiftUI visual implementation starts first.

## Earlier (implementation phase)
- Swift 6.0 compatibility required (CI = Xcode 16.4) — avoid 6.3-only inference; the one
  divergence hit: sending non-Sendable `SMAppService` through `self` into async work
  (fixed via nonisolated static construct-and-use).
- Zero-account default build: Manual + ad-hoc signing, entitlements commented out; widget
  shows placeholder until team-signed (documented in README).
- Simulation mode uses ephemeral stores — dry-run must never touch real config/history.

## Local RC decisions (2026-08-07; current authority)

These decisions supersede every older visual direction above while preserving
that history as a record of rejected work.

- **Dark-only, native safety instrument.** The 2026-08-04 adaptive/light idea
  was superseded by the founder's latest dark-only instruction. The shipping
  surfaces use fixed dark semantic tokens, native type and symbols, restrained
  motion, strong hierarchy, and explicit proof language.
- **No character or eye motif.** The eye, Happy Mac, aurora, glow, draggable
  glass switch, and SF Rounded system were removed from app, widget, icon,
  screenshot generator, and public copy. The replacement icon is a restrained
  closed-laptop seam that survives the complete 16–1024 px asset set.
- **One canonical primary action.** Normal, armed, restoring, outside-override,
  stale, and unknown presentations map to one truthful action model. Unknown or
  stale evidence never receives an optimistic control or progress treatment.
- **All stale helpers are terminal.** No stale revision is advertised as
  replaceable. Automatic cleanup, replacement, and uninstall are disabled;
  compatibility selectors remain only as side-effect-free refusals. Keeping
  the helper registered preserves launchd recovery supervision until a signed,
  revision-specific removal procedure is reviewed live.
- **Durable uncertainty beats inferred absence.** Privileged child mutations
  persist a synchronized marker with boot-session identity. Scheduled wakes
  use a strict parser, a phase ledger, and a separate launchd reconciliation
  witness. Crash recovery cancels uncertain or duplicate observations instead
  of promoting them from disk state.
- **Persistence failures are product state.** Config, history, and active-session
  writes return explicit results. An orphan session journal stays durable until
  helper reconciliation selects a truthful end reason; history is saved before
  the journal is cleared.
- **Local RC is not a release.** Offline tests, strict typechecks, unsigned
  builds, static analysis, and rendered UI evidence may establish a local
  candidate. Signing, helper approval, live `pmset`, launchd/reboot/sleep tests,
  WidgetKit hosting, accessibility input QA, notarization, publication, and any
  system mutation remain separate gates.
