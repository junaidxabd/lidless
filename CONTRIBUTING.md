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
make test     # LidlessCore suite — must stay green
xcodebuild -project Lidless.xcodeproj -scheme Lidless \
  -configuration Debug -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO build  # compile verification only
```

Runtime builds require one Apple signing team across the app, widget, and root
helper. Account-free contributors can run the core tests and the same unsigned
compile verification as CI with `CODE_SIGNING_ALLOWED=NO`; unsigned builds must
not be used with the privileged helper.

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

`Scripts/release.sh prepare` packages a policy-checked app as a notarization-
submission zip, not a verified or publishable artifact. After separately
authorized notarization and stapling, `Scripts/release.sh finalize` validates
the app and hashes the resulting final zip. The
cask in `Casks/lidless.rb` tracks the published release URL. Maintainers bump
`CFBundleShortVersionString` in both Info.plists and `LidlessIDs.helperVersion`
when the XPC surface changes. A safety-critical helper behavior change also
requires an explicit, independently reviewed bump of both the app-required
revision and the daemon's producer-owned implemented revision; do not derive
the latter automatically from the former.
