# Contributing to Lidless

Thanks for helping. Two ground rules shape every change here:

1. **The safety invariant is non-negotiable.** The sleep override must never
   outlive supervision. Any change touching the helper, the sentinel, the
   watchdog, launchd config, or restore paths must preserve the failure
   matrix in ARCHITECTURE.md — and say so in the PR description.
2. **Decisions stay pure.** Cutoff/schedule/drain logic lives in
   `Packages/LidlessCore` with no IO and no clocks; everything it needs is a
   parameter. If you're adding policy, add it there, with tests.

## Setup

```bash
make gen      # xcodegen generate (brew install xcodegen)
make build
make test     # LidlessCore suite — must stay green
make simulate # run the app in dry-run mode (no root, simulated inputs)
```

The project builds with ad-hoc signing — no Apple Developer account needed.
The helper approval re-prompts after each rebuild in dev; that's expected.

## Testing expectations

- Engine/parser changes: unit tests in `Packages/LidlessCore/Tests`
  (Swift Testing, deterministic — fixed dates, injected calendars, never `Date()`).
- Behavioral changes: exercise them in `--simulate` mode; the Simulator pane
  drives battery/thermal/lid inputs through the real state machine.
- Helper changes: test the real daemon flow locally (install, arm, kill the
  app, kill the helper, reboot) and note what you verified in the PR.

## Style

- Swift 6, strict concurrency, no warnings.
- 4pt spacing grid in UI code (`Theme.sN` constants only).
- Comments explain constraints and invariants, not what the next line does.

## Releases

`Scripts/release.sh` produces a notarization-ready zip; the cask in
`Casks/lidless.rb` tracks the GitHub release URL. Maintainers bump
`CFBundleShortVersionString` in both Info.plists and `LidlessIDs.helperVersion`
when the XPC surface changes.
