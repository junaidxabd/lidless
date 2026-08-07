# Dark Safety Instrument Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the rejected Lidless visual system with a coherent dark-only native macOS safety instrument across app, widget, icon, screenshots, and documentation.

**Architecture:** A small tokenized SwiftUI foundation supplies fixed dark surfaces, native typography, semantic state styling, proof seals, grouped metrics, banners, and motion-aware transitions. Every surface consumes canonical `SleepPresentationState`; screenshot fixtures exercise the complete state matrix without privileged mutation.

**Tech Stack:** SwiftUI, AppKit, Charts, WidgetKit, SF Symbols/SF Pro, macOS 15, deterministic simulation and `ImageRenderer` plus local runtime inspection.

## Global Constraints

- Dark mode only on app, panel, onboarding, AppKit alerts, and widget.
- No eye, Happy Mac, mascot, aurora, glow, decorative gradient, SF Rounded, or large draggable switch.
- No external assets, network, browser, Figma, plugin, or service.
- State and proof precede brand and telemetry.
- One primary action whose label and availability come from canonical state.
- Use a four-point spacing grid and named tokens; no duplicate magic colors.
- Reduce Motion, Reduce Transparency, Increased Contrast, keyboard focus, VoiceOver, and high contrast are first-class.
- Every fixed text/background token pair meets WCAG AA by calculation.
- Existing product behavior and safety semantics remain intact unless the safety plan explicitly changes them.
- Render and inspect every material state; tests alone are insufficient.

---

### Task 1: Add enforceable design-system and state-copy tests

**Files:**
- Create: `Packages/LidlessCore/Tests/LidlessCoreTests/VisualSystemSourceTests.swift`
- Create: `Packages/LidlessCore/Tests/LidlessCoreTests/ContrastTests.swift`
- Modify: `Packages/LidlessCore/Tests/LidlessCoreTests/SleepStatePresentationTests.swift`

**Interfaces:**
- Tests inspect only stable source/design contracts: forbidden motifs, required state actions, screenshot matrix, and token contrast.

- [ ] **Step 1: Write failing forbidden-system tests**

```swift
@Test func rejectedVisualLanguageIsAbsentFromShippingSources() throws {
    let shipping = try repositoryFiles([
        "App/Sources", "Widget/Sources", "Scripts/make_icon.swift", "README.md"
    ])
    for forbidden in ["AuroraBackground", ".fontDesign(.rounded)", "eye.fill", "eye.slash", "GlassSwitch("] {
        #expect(!shipping.contains(forbidden))
    }
}
```

- [ ] **Step 2: Write failing token contrast tests**

Implement a small test-only sRGB contrast helper and assert primary/canvas,
secondary/canvas, primary/surface, and secondary/surface ratios.

- [ ] **Step 3: Run focused tests and verify RED**

Expected: current rejected names and symbols are present; contrast tokens do not exist.

### Task 2: Replace Theme and shared components

**Files:**
- Rewrite: `App/Sources/Support/Theme.swift`
- Rewrite: `App/Sources/UI/Components.swift`
- Rewrite: `App/Sources/UI/MenuBar/GlassSwitch.swift` as `PrimaryStateAction` implementation (file rename may follow project regeneration)
- Modify: `App/Sources/AppState.swift`
- Test: `Packages/LidlessCore/Tests/LidlessCoreTests/VisualSystemSourceTests.swift`

**Interfaces:**
- Produces: `Theme.canvas`, `surface`, `surfaceRaised`, `separator`, `textPrimary`, `textSecondary`, semantic state colors, spacing, radii, and conditional transition helpers.
- Produces: `ProofSeal`, `VerificationLine`, `StateBadge`, `ActionBanner`, `MetricRow`, `PrimaryStateAction`, and `PanelToolbarButton`.
- Produces: state-specific menu symbol, primary action label, proof label, and semantic role.

- [ ] **Step 1: Implement the token set and contrast-safe components**

Use explicit colors from the design spec and native `.primary`/`.secondary` only where the dark environment is fixed. Remove mood, aurora, glass modifiers, glow, and gradient text.

- [ ] **Step 2: Implement canonical action semantics**

`PrimaryStateAction` is a `Button`; unknown invokes re-check, outside invokes repair, verified normal opens confirmation, armed restores, and transition states are disabled progress. Pending confirmation has its own explicit Cancel/Keep Awake row.

- [ ] **Step 3: Make motion environment-aware**

Only opacity/transform state replacement animates; `accessibilityReduceMotion` returns no animation. Materials fall back to opaque surfaces under Reduce Transparency.

- [ ] **Step 4: Run visual-system and full core tests**

### Task 3: Rebuild the menu panel and full arm confirmation matrix

**Files:**
- Rewrite: `App/Sources/UI/MenuBar/MenuPanelView.swift`
- Modify: `App/Sources/AppState.swift`
- Modify: `App/Sources/Services/ScreenshotRenderer.swift`
- Modify: `App/Sources/Simulation/Simulation.swift`
- Test: `Packages/LidlessCore/Tests/LidlessCoreTests/VisualSystemSourceTests.swift`

**Interfaces:**
- Panel width is 380 pt.
- Screenshot simulation exposes deterministic states without live system access.
- Confirmation variants cover all `ArmAssessment` cases.

- [ ] **Step 1: Add failing screenshot/state-matrix test**

Require filenames for verified normal, confirmation ok, low battery, floor refusal, thermal refusal, armed, restoring, outside, unknown, helper setup, and long error.

- [ ] **Step 2: Verify RED**

- [ ] **Step 3: Rebuild panel structure**

Header toolbar → contextual banner → status/proof → one primary button → presets → metric row. Confirmation replaces the middle. Remove footer and decorative hero.

- [ ] **Step 4: Add deterministic render scenarios**

Create a simulation-only `RenderScenario` seam on `AppState` that can set canonical observed state, helper classification, telemetry, pending assessment, and long error. It must guard `isSimulation` and never persist.

- [ ] **Step 5: Run tests, build the local render harness, and generate first-pass panel images**

Inspect every panel image for hierarchy, clipping, weak contrast, action truth, and stacked-banner height. Record specific differences before Task 7 polish.

### Task 4: Rebuild main overview and native window shell

**Files:**
- Rewrite: `App/Sources/UI/Main/MainWindowView.swift`
- Rewrite: `App/Sources/UI/Main/OverviewPane.swift`
- Modify: `App/Sources/Services/ScreenshotRenderer.swift`
- Test: `Packages/LidlessCore/Tests/LidlessCoreTests/VisualSystemSourceTests.swift`

**Interfaces:**
- Actual `MainWindowView` is renderable at minimum/default/wide sizes.
- Overview consumes the same status summary/action as the panel.
- Lower content stacks below the width threshold.

- [ ] **Step 1: Add failing shell-size screenshot contract tests**

Require 840×560, 900×620, and 1280×800 outputs plus normal/armed/outside/unknown states.

- [ ] **Step 2: Verify RED**

- [ ] **Step 3: Rebuild split view and overview**

Use native sidebar/toolbar. Place proof summary first, then battery ledger and current safeguards, then recap/recovery. No decorative background layer.

- [ ] **Step 4: Render actual shell at all sizes and inspect**

Verify sidebar, toolbar, title, focus, chart axes, stacking, and minimum-size fit.

### Task 5: Polish secondary panes and destructive actions

**Files:**
- Modify: `App/Sources/UI/Main/CutoffsPane.swift`
- Modify: `App/Sources/UI/Main/SchedulesPane.swift`
- Modify: `App/Sources/UI/Main/HistoryPane.swift`
- Modify: `App/Sources/UI/Main/SetupPane.swift`
- Modify: `App/Sources/UI/Main/SimulatorPane.swift`
- Test: `Packages/LidlessCore/Tests/LidlessCoreTests/VisualSystemSourceTests.swift`

**Interfaces:**
- All panes share native grouped form styling and dark background.
- Schedule deletion requires confirmation.
- History selection and detail agree.
- Terminal helper detail uses disclosure.

- [ ] **Step 1: Add failing accessibility/destructive-action source tests**

Require contextual labels for icon-only buttons, schedule delete confirmation,
explicit history selection, and disclosure for terminal helper detail.

- [ ] **Step 2: Verify RED**

- [ ] **Step 3: Update each pane without changing policy behavior**

Keep native controls, remove gradients/rounded type/weak opacity, add concise
summaries, help text, confirmation, and keyboard/default/cancel actions.

- [ ] **Step 4: Render representative empty/populated/error states and inspect**

### Task 6: Rebuild onboarding, widget, and lid-seam icon

**Files:**
- Rewrite: `App/Sources/UI/Onboarding/OnboardingView.swift`
- Rewrite: `Widget/Sources/LidlessWidget.swift`
- Rewrite: `Scripts/make_icon.swift`
- Regenerate: `App/Resources/Assets.xcassets/AppIcon.appiconset/*.png`
- Modify: `App/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Modify: `App/Sources/Services/ScreenshotRenderer.swift`
- Test: `Packages/LidlessCore/Tests/LidlessCoreTests/VisualSystemSourceTests.swift`

**Interfaces:**
- Onboarding is scroll-safe and renders all three steps.
- Widget is dark in every state and mirrors canonical proof.
- Icon generator draws a non-eye lid seam at every required size.

- [ ] **Step 1: Add failing icon/widget/onboarding tests**

Forbid eye geometry/copy and widget gradients; require dark container, stale unknown handling, all onboarding steps, and icon output sizes.

- [ ] **Step 2: Verify RED**

- [ ] **Step 3: Rebuild onboarding and widget**

Use proof seals, short headings, progressive disclosure, explicit evidence boundaries, and no categorical closed-bag safety claim.

- [ ] **Step 4: Draw and generate the lid-seam icon**

The script draws one dark rounded-square mass, a precise clamshell seam, and a small blue wake notch. Inspect 16/32/128/512/1024 px in a contact sheet; simplify until 16 px is unambiguous.

- [ ] **Step 5: Render all onboarding/widget/icon evidence and inspect**

### Task 7: Perform iterative visual and accessibility QA

**Files:**
- Modify as findings require: `App/Sources/Support/Theme.swift`
- Modify as findings require: `App/Sources/UI/**/*.swift`
- Modify as findings require: `Widget/Sources/LidlessWidget.swift`
- Update: `Docs/screenshots/*.png`
- Create: `Docs/verification/visual-qa-2026-08-07.md`

**Interfaces:**
- QA log lists each image, concrete findings, fix, and re-render result.

- [ ] **Step 1: First fresh-eyes critique**

Score distinctiveness, squint hierarchy, state truth, contrast, keyboard/a11y,
token fidelity, and native register. Triage Blocker/High/Medium/Nit.

- [ ] **Step 2: Fix Blocker/High findings and re-render**

Use tests first for behavioral/accessibility defects; token-only visual adjustments keep existing tests green.

- [ ] **Step 3: Second critique at minimum/default/wide and long-copy states**

Compare exact alignment, density, wrapping, metric dominance, button prominence,
and state-color consistency. Fix all credible High/Medium issues.

- [ ] **Step 4: Run contrast, Reduce Motion/Transparency, keyboard, and VoiceOver-oriented inspection**

Record what is machine-verified versus what still needs human runtime judgment.

### Task 8: Reconcile product documentation and historical direction

**Files:**
- Modify: `README.md`
- Modify: `ARCHITECTURE.md`
- Modify: `Docs/orchestration/progress.md`
- Modify: `Docs/orchestration/decisions.md`
- Preserve: `Docs/orchestration/tasks/2026-07-17-design-rethink-brief.md`
- Preserve: `Docs/orchestration/tasks/2026-08-04-design-reset-brief.md`
- Preserve: `Docs/orchestration/design-direction-v4.png`
- Test: `Packages/LidlessCore/Tests/LidlessCoreTests/VisualSystemSourceTests.swift`

**Interfaces:**
- Current docs state dark-only direction and exact local/external evidence.
- Historical files remain intact and marked superseded from current docs.

- [ ] **Step 1: Add failing current-doc contract tests**

Require dark safety instrument language and forbid marketing the eye, aurora,
glow, automatic safe uninstall, or screenshots as privileged runtime proof.

- [ ] **Step 2: Verify RED**

- [ ] **Step 3: Rewrite current docs and image references**

Update test counts only from fresh output. Name signed/helper/hardware gates.

- [ ] **Step 4: Run documentation contracts and full core suite**
