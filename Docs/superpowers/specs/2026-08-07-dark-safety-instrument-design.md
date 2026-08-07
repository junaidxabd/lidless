# Lidless Dark Safety Instrument Design

Date: 2026-08-07

Status: approved for autonomous implementation by the founder's completion-lane instruction.

## Product decision

Lidless will be rebuilt as a dark-only, native macOS safety instrument. The
surface exists to answer one question without ambiguity: **what will this Mac
do when the lid closes, and has Lidless proved it?** Brand, telemetry, and
configuration remain subordinate to that answer.

The current eye, aurora, bloom, simulated-glass, rounded-type, and draggable
switch system is rejected implementation history. It must not survive in the
shipping icon, menu-bar item, app surfaces, widget, screenshots, copy, or icon
generator.

## Approaches considered

### 1. Quiet Native Control Center — selected

A 380-point native-material menu panel leads with a truthful state sentence,
an explicit proof line, and one standard primary button. Presets and telemetry
sit beneath it without a decorative hero. The main window retains a native
sidebar and uses a concise status summary plus a restrained battery trace.

This is the best balance of immediate safety legibility, native macOS register,
and enough operational detail for overnight-agent and remote-access users.

### 2. Energy Ledger

The battery curve and cutoff ledger would be the visual identity. It serves
expert users well, but makes telemetry compete with the safety state and can
read like a monitoring dashboard instead of a dependable utility.

### 3. Minimal Menu Command

Only status, proof, the primary action, and presets remain in the panel; all
detail moves to the window. It is calm, but hides too much evidence during a
consequential arm decision.

The selected direction borrows only Energy Ledger's restrained battery trace.

## Audience and single job

- Primary audience: people leaving a MacBook running unattended for long jobs
  or remote access.
- Primary surface: the menu-bar panel.
- Single job: communicate verified sleep behavior and provide the one safe
  next action.

## Compact design system

### Color

Every visual value derives from these named tokens. Semantic macOS colors are
used for state, not decoration.

- `canvas` — `#0B0D12`: the fixed dark ground.
- `surface` — `#151922`: grouped content and panel sections.
- `surfaceRaised` — `#1C212C`: hover, selection, and focused summaries.
- `separator` — `#2C3342`: hairlines and boundaries.
- `textPrimary` — `#F3F5F8`: high-emphasis text.
- `textSecondary` — `#A7B0C0`: supporting copy.

Active uses system blue; verified normal uses system green; recoverable outside
override uses system orange; unknown/unverified danger uses system red. Color
never carries meaning alone. There are no decorative gradients.

### Type

The project requirement for native SF Pro overrides the general preference for
a custom display face.

- Display: SF Pro, 28–32 pt, semibold, used only for the current state or
  remaining duration.
- Body: SF Pro, native body/callout roles, regular or medium.
- Utility: SF Mono only for commands; SF Pro tabular figures for durations,
  percentages, and drain rates.
- Product-wide SF Rounded and arbitrary kerning are removed.

### Geometry and spacing

- Four-point grid: 4, 8, 12, 16, 20, 24, 32.
- Native control heights and focus rings.
- Restrained continuous corners: 8 for compact controls, 12 for grouped
  surfaces, 16 only for the primary status summary.
- Minimum interactive target: 28 pt for pointer-native compact controls and
  44 pt for the primary action.
- Body copy is constrained to a readable measure; long recovery detail moves
  behind disclosure controls.

### Signature

Lidless's signature is a **proof seal**: a small state-specific SF Symbol in a
quiet rounded square paired with an explicit verification sentence. It is a
functional identity used consistently in the panel, overview, onboarding, and
widget—not a mascot.

The Finder/Launchpad icon uses a separate abstract **lid seam** mark: a precise
clamshell hinge and wake notch that cannot be read as an eye, face, bolt, or
generic moon. At 16 pt it must retain one dark mass and one clear light mark.

### Aesthetic risk

The deliberate risk is restraint: the verified-normal state receives the
strongest proof treatment even though it is the inactive state. This reverses
the common “only active glows” dashboard convention and reinforces Lidless's
safety promise. The active state is blue and clear, not theatrical.

### Genericness self-test

A generic utility design would use interchangeable cards, a centered hero,
and a blue gradient CTA. Those were removed. The revised system is specific to
Lidless through the proof seal, exact sleep language, lid-seam identity, and
the hierarchy of verified normal over mere activity.

## Menu-bar item

The eye symbols are replaced with state symbols that remain legible at menu-bar
size:

| State | Symbol | Optional text |
|---|---|---|
| Verified normal | `moon.zzz` | none |
| Verifying arm | `hourglass` | none |
| Verified armed | `bolt` | countdown when under 24 hours |
| Restoring | `arrow.triangle.2.circlepath` | none |
| Outside override | `exclamationmark.triangle` | none |
| Unknown | `questionmark.circle` | none |

The accessibility label always names the full state.

## Menu panel

Target width: 380 pt. No persistent hero, footer bar, custom switch, nested
glass, atmospheric motion, or decorative illustration.

```text
┌──────────────────────────────────────────┐
│ Lidless  [SIM]          [History] [Setup]│
│                                          │
│ [proof seal]  Sleeping normally          │
│               Normal sleep · Verified    │
│                                          │
│ [            Keep Awake…              ] │
│                                          │
│ Until 7 AM    4 hours    To 20%          │
│ ──────────────────────────────────────── │
│ Battery 68%   Drain 9.0%/h   Thermal OK  │
└──────────────────────────────────────────┘
```

Contextual banners appear immediately below the header only when action is
required. Arming confirmation replaces the status/action/preset middle region
instead of stacking another card onto it. It shows exact assessment, projected
cutoffs, the verification boundary, Cancel, and Keep Awake. During arming the
confirmation action becomes disabled progress; repeated activation cannot
silently no-op.

The primary action is always a real `Button` with keyboard focus and semantics
derived from canonical state:

- verified normal: `Keep Awake…`
- verifying arm: `Verifying…` disabled
- verified armed: `Restore Normal Sleep`
- restoring: `Restoring…` disabled
- outside override: `Restore Normal Sleep`
- unknown: `Check Again`; Setup remains adjacent secondary help

## State language

| State | Headline | Proof/detail | Primary action | Semantic role |
|---|---|---|---|---|
| Verified normal | Sleeping normally | Normal macOS sleep · Verified | Keep Awake… | green |
| Verifying arm | Verifying keep-awake… | Do not close the app yet | disabled progress | neutral |
| Verified armed | Staying awake | Sleep override · Verified | Restore Normal Sleep | blue |
| Restoring | Restoring normal sleep… | Keep Lidless open until verified | disabled progress | neutral |
| Outside override | Sleep disabled outside Lidless | No Lidless session explains it | Restore Normal Sleep | orange |
| Unknown | Sleep state unknown | Lidless could not verify the system state | Check Again | red |
| Helper unavailable | Setup required | Exact classified reason | Set Up… / Approve… / Open Setup… | orange or red |

Outside override and unknown never share the same headline, proof, or action.
Transitions never inherit the blue verified-active styling.

## Main window

`NavigationSplitView` remains. The sidebar and toolbar use native macOS
selection, material, and controls. The detail ground is fixed dark.

```text
┌──────────────┬─────────────────────────────────────────────┐
│ Overview     │ [proof seal] Sleeping normally   [Keep…]   │
│ Cutoffs      │ Normal macOS sleep · Verified              │
│ Schedules    ├──────────────────────┬──────────────────────┤
│ History      │ Battery trend        │ Current safeguards   │
│ Setup        │ restrained trace     │ floor / thermal/time │
│              ├──────────────────────┴──────────────────────┤
│              │ Last session / actionable recovery notice  │
└──────────────┴─────────────────────────────────────────────┘
```

The overview renders all six sleep states and helper failures. Recovery and
unknown notices outrank telemetry. At minimum width the two lower columns stack
without horizontal clipping.

Secondary panes preserve their functionality with native grouped forms. They
receive consistent section spacing, concise summaries, progressive disclosure
for terminal recovery text, contextual accessibility labels, selection polish,
and safe destructive actions. Schedule deletion requires confirmation. History
does not show detail until a row is selected unless it deliberately selects and
visually highlights the first row.

## Onboarding

The three-step sequence remains because it maps to product understanding,
privileged setup, and recovery. It becomes a scroll-safe dark native sheet with
the lid-seam icon, no aurora, no glow, no rounded product font, and no categorical
claim that closed-bag use is proven safe.

Copy distinguishes designed safeguards from live/hardware validation. Long
helper failures use a concise heading plus disclosure for exact recovery text.
Every step supports accessibility text size without clipping.

## Widget

Both families use the same dark container in every state. The widget mirrors
canonical state without gradients or rounded type. A small proof seal and
state line lead; battery and countdown follow. Stale data is red/unknown and
never styled as inactive success. Medium layout may show one restrained blue
battery trace and a safe deep link.

## Motion and accessibility

- Motion exists only for state replacement, progress, and disclosure.
- Interaction feedback is at most 160 ms; no ambient animation.
- Reduce Motion removes transitions rather than merely pausing a background.
- Reduce Transparency replaces material with `surface`.
- Increased Contrast strengthens separators and secondary text.
- Every icon-only button has a contextual label and help text.
- Keyboard traversal reaches every action in visual order.
- Focus rings remain native and visible.
- Contrast is machine-checked for every fixed token pair; semantic colors pair
  with symbols and labels.

## Screenshot and visual QA contract

The renderer must capture real view code for:

- menu: verified normal, confirmation-ok, low-battery warning, below-floor
  refusal, armed, restoring, outside override, unknown, helper setup, long error;
- overview: minimum 840×560, default 900×620, wide 1280×800, with normal,
  armed, outside, and unknown states;
- onboarding: all three steps and long helper failure;
- widget: small/medium, fresh armed, verified normal, stale unknown, empty;
- icon: 16, 32, 128, 512, and 1024 px contact sheets.

The overview evidence must include the actual split-view shell, not only its
inner content. Offscreen renders are followed by a local simulated runtime pass
to inspect native material, popover anchoring, keyboard focus, and window fit.

Visual review is iterative: render, list specific hierarchy/spacing/contrast
differences, fix, and re-render at least twice. A separate reviewer scores
distinctiveness, hierarchy, state truth, accessibility, token fidelity, and
native register.

## Documentation

README, architecture, progress, decisions, screenshots, icon generator, and
widget copy must describe the dark safety instrument and its exact evidence
boundary. Historical design files remain preserved and are explicitly marked
as superseded. No screenshot is described as runtime proof of privileged or
hardware behavior.
