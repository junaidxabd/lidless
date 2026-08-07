# Local Release Candidate Verification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce reproducible evidence that the Lidless branch is the strongest possible local release candidate without crossing signing, live-system, or release boundaries.

**Architecture:** Verification is layered: source integrity, core behavior, complete unsigned target compilation, static analysis, deterministic simulation, rendered visual evidence, independent adversarial review, and durable handoff. Each claim maps to a fresh command or inspected artifact.

**Tech Stack:** Git read-only status, Swift Testing, Xcode/xcodebuild or a documented local Swift compiler harness when the outer sandbox blocks Xcode package manifests, XcodeGen, shell syntax checks, AppKit/SwiftUI deterministic rendering.

## Global Constraints

- Never sign, notarize, staple, install, deploy, publish, merge, push main, or invoke live `pmset`.
- Do not authenticate, access external services, or change system settings.
- All caches, derived data, logs, screenshots, and reports stay inside this repository.
- A blocked check is reported as blocked; it is never converted into success.
- Completion requires fresh evidence after the final code change.

---

### Task 1: Establish reproducible source and project integrity

**Files:**
- Create: `Docs/verification/local-rc-2026-08-07.md`
- Modify as needed: `project.yml`
- Regenerate as needed: `Lidless.xcodeproj`

- [ ] **Step 1: Record exact branch, starting commit, final tree status, and tool versions**

- [ ] **Step 2: Regenerate the Xcode project and require zero unexplained drift**

Run `xcodegen generate`, inspect the complete project diff, and retain only intended generated changes.

- [ ] **Step 3: Run whitespace, conflict-marker, forbidden-motif, placeholder, and secret-pattern scans**

Record exact commands and counts without printing credential values.

### Task 2: Run complete behavioral and policy verification

- [ ] **Step 1: Run every new focused test from RED/GREEN cycles**

- [ ] **Step 2: Run the full core suite from a clean repository-local scratch path**

- [ ] **Step 3: Run the suite a second time after deleting only ignored build outputs**

- [ ] **Step 4: Run shell syntax and release-policy checks**

Record suite/test counts, exit codes, warnings, and any quarantined external gates.

### Task 3: Compile and analyze every local target

- [ ] **Step 1: Build Debug unsigned**

- [ ] **Step 2: Build Release unsigned**

- [ ] **Step 3: Run static analysis**

- [ ] **Step 4: Inspect the built app graph**

Confirm app, helper, widget, launchd plist, Info plists, icon assets, deployment
target, bundle IDs, and architecture. Unsigned build evidence is never called a
runnable privileged candidate.

If the managed outer sandbox rejects Xcode's nested package-manifest sandbox,
use the repository-local compiler harness to compile app/helper/widget sources
and render simulation, retain the exact Xcode failure, and mark full Xcode graph
compilation as environment-blocked rather than passed.

### Task 4: Run and inspect deterministic UI and safety simulation

- [ ] **Step 1: Generate the complete screenshot matrix from final sources**

- [ ] **Step 2: Inspect every rendered image at original resolution**

- [ ] **Step 3: Run the local simulation executable without privileged helper access**

Exercise arm, cancel, disarm, battery floor, telemetry loss, critical thermal,
outside override, unknown state, helper failure, and recovery presentation.

- [ ] **Step 4: Verify screenshot determinism and documentation freshness**

Re-run generation and compare hashes; document any intentionally dynamic field.

### Task 5: Independent adversarial review and fix loop

- [ ] **Step 1: Dispatch separate safety, engineering, accessibility, and visual reviewers**

Give reviewers the specs, plans, starting commit, final diff, and exact evidence—not session history.

- [ ] **Step 2: Reproduce every Critical/Important finding independently**

- [ ] **Step 3: Fix valid findings with RED/GREEN tests and re-run affected verification**

- [ ] **Step 4: Repeat review until no unresolved Critical/Important local finding remains**

Preserve dissent and explicitly disposition rejected findings with evidence.

### Task 6: Finalize durable handoff

**Files:**
- Update: `Docs/orchestration/progress.md`
- Update: `Docs/orchestration/decisions.md`
- Finalize: `Docs/verification/local-rc-2026-08-07.md`
- Create: `Docs/orchestration/LIDLESS-LOCAL-RC-HANDOFF-2026-08-07.md`

- [ ] **Step 1: Create a line-by-line requirement/evidence matrix**

- [ ] **Step 2: Record local verified claims separately from external gates**

- [ ] **Step 3: Record exact remaining founder/release actions**

Signing/notarization/release and any live helper/hardware matrix remain explicit fresh-approval gates.

- [ ] **Step 4: Run one final clean verification sweep after documentation changes**

- [ ] **Step 5: Record final diff/tree status and commit limitation**

This corrected checkout is a linked worktree whose Git metadata is outside the
authorized task root. If staging/commit remains sandbox-blocked, preserve every
change and exact patch in the task root and state that limitation; do not request
outside permission.
