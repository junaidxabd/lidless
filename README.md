<p align="center">
  <img src="App/Resources/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" width="128" alt="Lidless icon">
</p>

<h1 align="center">Lidless</h1>
<p align="center"><b>Awake with the lid closed.</b><br>
A native macOS menu bar app that keeps your MacBook fully running while closed — on battery, no external display — with layered restoration safeguards.</p>

<p align="center">
  <img src="Docs/screenshots/menu-armed.png" width="330" alt="Lidless menu panel while armed">
</p>

---

macOS force-sleeps a MacBook the moment the lid closes on battery. `caffeinate` can't stop that — it only blocks *idle* sleep. The only real lever is the system-wide override `pmset disablesleep`, which is root-only, system-wide, and dangerous to leave behind. Lidless is an engineering effort to mediate that lever with layered safeguards; the remaining live and hardware gates in this document are part of its safety boundary.

Built for two kinds of people:

- **Devs running agents & long jobs overnight** on a closed MacBook — you get battery floors, thermal cutoffs, session history with drain curves, and redundant supervision of the override.
- **Remote-access users** who SSH / screen-share into a MacBook closed in a bag or another room — you get "keep network alive" (tcpkeepalive enforcement) and thermal protection as a headline feature, because a closed laptop in a backpack is the worst-case thermal environment. These controls are intended to reduce risks that a raw `sudo pmset -a disablesleep 1` command does not address; they are not a substitute for the uncompleted live and hardware validation.

## Features

- **One deliberate control.** A power-style arming button in the menu bar panel. Arming on battery always shows the projected runtime at your current drain rate; below 30% you get an explicit warning; at/under the floor it refuses.
- **Cutoffs** (each optional, sensible defaults): battery floor (default 10%, suspended while charging), thermal protection (`pmset -g therm` warning level / CPU throttling, debounced), duration limit, wall-clock off-time.
- **Quick-arm presets**: *Until 7 AM* · *4 hours* · *Until 20%*.
- **Schedules**: recurring windows (weeknights 11 PM–7 AM), automatic arm/disarm, RTC wake registered before each window so a sleeping Mac can wake itself and arm (best effort).
- **Low Power Mode & network keep-alive** while armed, both restored to their prior values on disarm.
- **Intended cutoff sequence**: prove normal-sleep restoration, then notify and request `sleepnow` only with the lid closed. Terminal completion and duplicate-sleep suppression remain under safety review.
- **Session history** with a battery-drain sparkline per session and full curves in detail view.
- **Widget surface** designed to mirror armed state and battery projection with a Disarm link; signed app-group behavior remains a live gate.
- **State clarity is a design goal.** The menu bar and main window distinguish normal and armed states, but unknown/out-of-band presentation is still under safety review and must not be inferred as complete from screenshots.
- **Dry-run mode**: `Lidless --simulate` runs the entire app — arming flow, cutoff engine, notifications — against simulated battery/thermal inputs, with a Simulator pane. No root, no system changes.
- **A living interface.** Locked to dark mode by design: a drifting aurora carries the app's mood, and the arming control is a literal eye — drowsy and blinking while dormant, wide open, glowing, and *unblinking* while on watch. Every state change springs; Reduce Motion is fully respected.

<p align="center">
  <img src="Docs/screenshots/menu-confirm.png" width="300" alt="Arming confirmation with projection">
  <img src="Docs/screenshots/onboarding.png" width="300" alt="Onboarding">
</p>

## How it works

Overriding lid-close sleep requires root, so Lidless splits in two:

- **The app** (what you see): monitors battery via IOKit power-source events, polls thermals, runs the pure decision engine, and holds zero privileges.
- **The helper** (`LidlessHelper`, ~700 lines you can audit): a launchd daemon managed through `SMAppService`. Its narrow root surface manages `disablesleep`, optional `sleepnow`, Low Power Mode, `tcpkeepalive`, scheduled wakes, and recovery. It makes **no** cutoff decisions; it actuates, reads the power-management registry back, and is designed around one invariant:

> **The sleep override must never outlive supervision.**

The checkpointed helper keeps recovery pending until an exact registry readback
proves normal sleep. These are the mechanisms under review, not claims of
signed-runtime, crash, reboot, sleep/wake, or hardware validation:

| Trigger | Mechanism and current evidence boundary |
|---|---|
| Cutoff, disarm, or quit | The app requests restoration; terminal completion and app/helper reconciliation remain under safety review |
| App crash or hang | Helper invalidation and watchdog paths request restoration; real XPC failure behavior remains a live gate |
| Helper crash while armed | The sentinel configures `KeepAlive.PathState`; actual launchd relaunch behavior remains a live gate |
| Power loss or reboot | The sentinel and `RunAtLoad` provide a recovery path; reboot recovery remains a hardware gate |
| Sleep transition while armed | The helper's sleep observer requests restoration; sleep/wake behavior remains a hardware gate |
| `pmset` failure | The sentinel and retry state remain pending; live command-failure recovery is not established offline |

The keystone is a **sentinel file** (`/var/db/lidless/override-active`) written *before* the override is enabled and deleted only *after* a verified restore. It records the prior power-mode and `tcpkeepalive` values. A legacy `disablesleep` field remains decodable, but current recovery deliberately restores ordinary sleep (`disablesleep 0`) rather than preserving an outside override.

### Verify it's off

Trust, but verify — Setup & Help shows this too:

```bash
ioreg -r -d1 -c IOPMrootDomain | grep SleepDisabled   # must say: "SleepDisabled" = No
```

### Manual fallback

If the observed system state does not match the app, one command restores ordinary sleep:

```bash
sudo pmset -a disablesleep 0
```

## Install

**Core tests or unsigned compile verification** (no Apple Developer account needed):

```bash
git clone https://github.com/junaidxabd/lidless && cd lidless
make test
xcodebuild -project Lidless.xcodeproj -scheme Lidless \
  -configuration Debug -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO build
```

Unsigned output is compile evidence only: do not run it with the privileged helper. Runtime candidates require one real Apple signing team with the app, widget, helper identifiers, and app-group capability configured. Helper approval, signed XPC trust, and app-group behavior still require separate live validation.

Useful targets: `make test` (the deterministic core suite), `make simulate` (signed dry-run mode), and `make screenshots` (signed simulation-driven documentation renders).

## Uninstall

The current **Setup & Help → Uninstall Lidless…** path is still under fail-closed safety review. Do not treat it as proof that normal sleep was restored or helper supervision was retained. Verify the registry state independently before removing supervision; if state is uncertain, use the manual fallback above. Live `SMAppService` uninstall behavior remains a separate gate.

## Signing & notarization

Release policy requires one signing team across the app, widget, and privileged helper. The helper's client requirement is designed to reject ad-hoc or identifier-only impostors, and app-group entitlements are configured for the app and widget. Actual signed XPC acceptance and widget sharing remain live validation gates.

Account-free CI is configured to compile the graph with `CODE_SIGNING_ALLOWED=NO`, but that unsigned artifact is not runnable against the privileged helper. Forks using another Apple team must provision or rename the identifiers and app group consistently, update `project.yml` and the release policy, then run `make gen`.

For distribution:

1. Confirm the configured team has the three identifiers and `group.com.lidless.shared` capability available.
2. `Scripts/release.sh prepare` archives and Developer-ID exports, then requires the repository verifier and macOS notarization-submission policy check before creating a submission zip. A positive signed export has not been established by the offline safety repair.
3. Under a separate credentialed release gate, notarize and staple the app, then run `Scripts/release.sh finalize`. Finalization requires the stapled-ticket, execution-policy, repository, and macOS distribution checks before creating the Homebrew-cask-friendly zip and printing its SHA-256.

## Architecture

The interesting parts — app ↔ helper split, XPC hardening (peer code-signing requirements), the exact arming flow, failure-recovery design, and what's tested — are documented in [ARCHITECTURE.md](ARCHITECTURE.md).

## License

[MIT](LICENSE). Contributions welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).
