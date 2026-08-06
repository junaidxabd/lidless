import SwiftUI
import LidlessCore

/// First-run flow written for a total stranger from GitHub: what the app
/// does, exactly what the one-time authorization is, why it's safe, and —
/// up front — how to leave.
struct OnboardingView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var step = 0

    private let stepCount = 3

    var body: some View {
        ZStack {
            AuroraBackground(mood: .vigil)
                .opacity(0.5)

            VStack(spacing: 0) {
                Group {
                    switch step {
                    case 0: intro
                    case 1: helperStep
                    default: safetyStep
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, Theme.s8)
                .padding(.top, Theme.s8)

                footer
                    .padding(Theme.s6)
            }
        }
        .frame(width: 560, height: 560)
        .fontDesign(.rounded)
        .preferredColorScheme(.dark)
        .animation(Theme.springGentle, value: step)
    }

    // MARK: - Step 1: what it does

    private var intro: some View {
        VStack(spacing: Theme.s5) {
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Theme.armedGradient)
                    .frame(width: 96, height: 96)
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .strokeBorder(.white.opacity(0.5), lineWidth: 1)
                    )
                    .shadow(color: Theme.armed.opacity(0.5), radius: 22)
                Image(systemName: "bolt.fill")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(.white)
            }

            VStack(spacing: Theme.s2) {
                Text("Awake with the lid closed")
                    .font(.largeTitle.weight(.bold))
                Text("Lidless keeps your MacBook fully running while closed — on battery, no external display needed. For overnight agents and long jobs, or for SSH and screen sharing into a Mac that's closed in a bag or another room.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: Theme.s2) {
                bullet("thermometer.medium", "Thermal protection puts it to sleep if it runs hot — the reason this is safe where a raw pmset hack is not.")
                bullet("battery.25percent", "A battery floor (default 10%) starts verified restoration at the limit or if its reading becomes unavailable; Lidless stays in recovery until normal sleep is proven.")
                bullet("clock", "Duration limits, off-times, and recurring schedules end sessions automatically.")
            }
            .frame(maxWidth: 440)
        }
    }

    // MARK: - Step 2: the helper

    private var helperStep: some View {
        VStack(spacing: Theme.s5) {
            Image(systemName: "lock.shield")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Theme.armedGradient)

            VStack(spacing: Theme.s2) {
                Text("One-time authorization")
                    .font(.largeTitle.weight(.bold))
                Text("Overriding lid-close sleep requires a privileged helper (it runs `pmset` as root). You approve it once in System Settings — never again after that.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: Theme.s3) {
                helperStatusRow

                if let error = state.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .textSelection(.enabled)
                }

                if state.helperState == .requiresApproval {
                    Text("macOS added Lidless under Login Items & Extensions — flip the switch there, then come back.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: 420)
        }
    }

    private var helperStatusRow: some View {
        HStack(spacing: Theme.s3) {
            switch state.helperState {
            case .ready, .simulated:
                Image(systemName: "checkmark.seal.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                Text(state.helperState == .simulated ? "Simulated helper active" : "Helper installed and responding")
                    .font(.body.weight(.medium))
            case .requiresApproval:
                Image(systemName: "person.badge.clock.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                Text("Waiting for approval")
                    .font(.body.weight(.medium))
                Spacer()
                Button("Open Login Items…") { state.openApprovalSettings() }
                    .buttonStyle(.borderedProminent)
                Button("Re-check") { Task { await state.refreshHelperState() } }
            case .stale(let version, let revision)
                where SleepOverrideSafety.isReviewedStaleReplacementCompatible(
                    helperVersion: version,
                    helperSafetyRevision: revision
                ):
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.title2)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Helper safety update required")
                        .font(.body.weight(.medium))
                    Text("Replacing removes the current helper first: it cancels its scheduled wakes, restores the other settings it manages, deletes its data, and deregisters it. A new helper is registered only after normal sleep is independently verified; if that registration fails you will be left with no helper registered until you install one again.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Replace Helper…") {
                    Task { await state.installHelper() }
                }
                .buttonStyle(.borderedProminent)
            case .stale(let version, let revision):
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reviewed removal required")
                        .font(.body.weight(.medium))
                    Text("Protocol v\(version), revision \(revisionLabel(revision)), has no reviewed automatic cleanup path. Emergency sleep recovery only: run \(LidlessIDs.manualFallbackCommand) and verify normal sleep. That command does not remove the helper. Keep the helper registered and contact Lidless support for a separately reviewed, revision-specific removal procedure.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            case .notResponding(let detail):
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reviewed removal required")
                        .font(.body.weight(.medium))
                    Text("\(detail) Emergency sleep recovery only: run \(LidlessIDs.manualFallbackCommand) and verify normal sleep. That command does not remove the helper. Keep the helper registered and contact Lidless support for a separately reviewed removal procedure for the installed helper.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            case .notInstalled:
                Image(systemName: "circle.dashed")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Not installed yet")
                    .font(.body.weight(.medium))
                Spacer()
                Button("Install Helper…") {
                    Task { await state.installHelper() }
                }
                .buttonStyle(.borderedProminent)
            case .unknown:
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Helper status unverified")
                        .font(.body.weight(.medium))
                    Text("Helper classification is unavailable, so Lidless will not assume the helper is absent or safe to replace. Emergency sleep recovery only: run \(LidlessIDs.manualFallbackCommand) and verify normal sleep. That command does not remove a helper or establish registration state. Keep any helper registered and contact Lidless support if Re-check cannot classify it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Re-check") {
                    Task { await state.refreshHelperState() }
                }
            // Only the pre-classification value shows progress. A concluded
            // `.unknown` verdict keeps its terminal copy and Re-check above.
            case .checking:
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 24)
                Text("Checking helper…")
                    .font(.body.weight(.medium))
            }
        }
        .padding(Theme.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    // MARK: - Step 3: safety & the exit

    private var safetyStep: some View {
        VStack(spacing: Theme.s5) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.green)

            VStack(spacing: Theme.s2) {
                Text("Layered recovery")
                    .font(.largeTitle.weight(.bold))
                Text("Lidless requests and retries normal-sleep restoration across cutoffs, shutdown, connection loss, and watchdog events; verify the result whenever recovery is reported:")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: Theme.s2) {
                bullet("bolt.heart", "Cutoffs, disarm, and quit request normal sleep before completion is reported.")
                bullet("ant", "App or helper loss triggers watchdog and launchd recovery attempts; verify normal sleep in Setup & Help.")
                bullet("eye.trianglebadge.exclamationmark", "The menu bar eye shows verified Lidless state and warns when it detects an outside override.")
                bullet("trash", "Uninstall lives in Setup & Help. Emergency sleep recovery only: \(LidlessIDs.manualFallbackCommand). That command does not uninstall the helper.")
            }
            .frame(maxWidth: 460)

            Toggle("Launch Lidless at login (recommended for schedules)", isOn: Binding(
                get: { state.launchAtLogin },
                set: { state.setLaunchAtLogin($0) }
            ))
            .toggleStyle(.checkbox)
            .disabled(state.isSimulation)
        }
    }

    private func bullet(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.s3) {
            Image(systemName: symbol)
                .frame(width: 20)
                .foregroundStyle(Theme.armedDeep)
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func revisionLabel(_ revision: Int?) -> String {
        revision.map(String.init) ?? "missing"
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            if step == 0 {
                Button("Set Up Later") { finish() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            } else {
                Button("Back") { step -= 1 }
            }

            Spacer()

            HStack(spacing: Theme.s1) {
                ForEach(0..<stepCount, id: \.self) { index in
                    Circle()
                        .fill(index == step ? AnyShapeStyle(Theme.armedDeep) : AnyShapeStyle(.quaternary))
                        .frame(width: 7, height: 7)
                }
            }

            Spacer()

            Button(step == stepCount - 1 ? "Start Using Lidless" : "Continue") {
                if step == stepCount - 1 {
                    finish()
                } else {
                    step += 1
                }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
    }

    private func finish() {
        state.config.onboardingComplete = true
        dismiss()
    }
}
