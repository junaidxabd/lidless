# Lidless design reset — Phase 0 approval brief

Date: 2026-08-04

Status: discovery complete; no Figma canvas objects created; founder approval
required before foundations, components, or screens are drawn.

Figma draft: https://www.figma.com/design/YkIFq8wiDpjYBwxpyO56LQ

## Source-of-truth decisions

- The founder's current direction — the existing Lidless UI is disliked and the
  replacement must start from scratch — supersedes the 2026-07-17 Happy Mac,
  eye, aurora, glow, SF Rounded, and dark-mode-locked direction.
- The existing implementation remains useful only for product behavior,
  information hierarchy, and safety-state coverage. It is not a visual
  reference.
- The verified sleep-state work on this branch is the functional source of
  truth: the interface must distinguish normal sleep, verification in progress,
  a proven keep-awake session, restoration in progress, an outside override,
  an unreadable/unknown sleep state, and helper setup/version failures.
- Lidless targets macOS 15.0. The official macOS 26 and 27 Figma libraries are
  available as reference material, but the design must remain implementable
  with native SwiftUI/AppKit behavior on macOS 15. Newer visual effects are not
  assumed.

## Direction: quiet safety instrument

Lidless should feel like a trusted macOS utility: calm, native, exact, and
immediately legible. It should look expensive because the hierarchy, spacing,
type, state language, and native materials are correct — not because it has
more decoration.

Principles:

- State before brand: the first line always states what macOS sleep will do.
- Proof is visible: when the app has verified the system state, say so; when it
  cannot, never substitute a reassuring default.
- One primary action: Keep Awake when normal; Restore Normal Sleep when active.
- Native material economy: use the popover/window material supplied by macOS,
  with quiet grouped surfaces and hairline separators. No simulated glass stack.
- SF Pro, standard macOS controls, tabular numerals, adaptive light and dark
  appearance, and a 4-point spacing grid.
- Color is semantic and sparse: blue for an active keep-awake session, green for
  verified normal sleep, orange for a recoverable warning, red for an unsafe or
  unverified condition. No decorative gradients.
- Motion explains a state transition; it does not create atmosphere. Reduce
  Motion receives an equivalent static transition.

Explicit exclusions:

- no eye motif or eye-shaped switch;
- no Happy Mac mascot or laptop illustration;
- no aurora, glowing numerals, bloom, or gradient theatre;
- no permanent dark-mode lock;
- no SF Rounded product-wide treatment;
- no large custom draggable control where a native button or segmented control
  communicates the action more clearly.

## V1 surfaces

### Menu-bar panel (primary surface, approximately 380 pt wide)

1. Compact header: Lidless, simulation label when applicable, settings/history
   access, and a small truthful state badge.
2. Status block: explicit headline, verification line, countdown/cutoff only
   when relevant, and one prominent action.
3. Quick presets when disarmed: Until 7 AM, 4 hours, and To 20%.
4. Compact telemetry: battery, drain, and thermals.
5. Inline safety/setup banner only when action is required.
6. Arming confirmation replaces the middle of the panel and shows projection,
   floor, thermal guard, exact cutoff, low-battery warning/refusal, Cancel, and
   Keep Awake.

There is no persistent decorative hero and no footer bar.

### Main overview (approximately 920 × 640 pt)

- Native sidebar and toolbar architecture.
- A concise system-state summary with the same action and verification language
  as the panel.
- Current-session/cutoff summary, battery trend, and last-session recap.
- Recovery and unknown-state notices are visually stronger than ordinary data.
- Existing secondary panes remain functionally represented, but their full
  redesign follows after the core direction is approved.

## Required state matrix

| State | Headline | Proof/detail | Primary action |
|---|---|---|---|
| Verified normal | Sleeping normally | Sleep enabled · Verified | Keep Awake… |
| Arming | Verifying keep-awake… | Do not imply success yet | Disabled progress action |
| Armed | Staying awake | Sleep override verified · cutoff/countdown | Restore Normal Sleep |
| Restoring | Restoring normal sleep… | Recovery remains visible until exact proof | Disabled progress action |
| Outside override | Sleep is disabled outside Lidless | No Lidless session explains it | Restore Normal Sleep |
| Unknown | Sleep state unknown | Lidless could not verify the system state | Check Again / Setup |
| Helper unavailable/outdated | Setup required | Exact install, approval, stale, or version reason | Set Up… / Approve… |

Low-battery warning and below-floor refusal are variants of the arming
confirmation, not separate ambient themes.

## Foundations plan

Pages:

1. `00 — Brief`
2. `01 — Foundations`
3. `02 — Components`
4. `03 — Menu Panel`
5. `04 — Main Overview`
6. `05 — State Matrix`

Collections and styles:

- `Color / Semantic`: Light and Dark modes; approximately 22 variables for
  canvas, surfaces, text, separators, controls, and four state roles.
- `Dimensions`: approximately 16 variables for the 4-point spacing scale,
  compact control heights, icon sizes, and restrained corner radii.
- Text styles: approximately 9 SF Pro roles, with tabular figures on durations
  and telemetry.
- Effect styles: at most two — native-popover depth reference and focus ring.

Initial components:

- state badge;
- verification line;
- status summary;
- primary/secondary action row;
- preset control;
- metric row;
- safety/setup banner;
- arming confirmation;
- menu panel shell;
- main overview section.

The official Apple macOS library is searched immediately before each component.
Matching native primitives may be reused; incompatible macOS 26/27-only effects
will be rebuilt with macOS 15-safe semantics.

## Discovery record and gaps

- The Figma file is a new blank draft: one empty page, no local collections,
  variables, styles, or components.
- SF Pro, SF Pro Rounded, SF Compact, and SF Compact Rounded are available.
  The new direction uses SF Pro; the rounded families are not the default.
- Apple macOS 26 and macOS 27 libraries are visible. Material 3 and Figma's
  generic Simple Design System are intentionally out of direction.
- Code Connect is unavailable on the connected Starter/View seat. No plan or
  seat change is required for the design work; mapping will remain documented
  manually.
- No current code-side Code Connect files or mappings were found.
- Full settings panes, onboarding, widget, icon, and marketing imagery are not
  part of the first approval artifact. They follow once the core panel and
  overview language is accepted.

## Approval gate

After approval, build in this order: foundations → components → menu panel and
critical state variants → main overview → visual/accessibility review. Only then
translate the approved system into SwiftUI. No existing UI source is changed as
part of this Figma gate.
