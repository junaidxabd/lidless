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
                Circle()
                    .fill(Theme.armedGradient)
                    .frame(width: 96, height: 96)
                    .shadow(color: Theme.armed.opacity(0.5), radius: 22)
                Image(systemName: "eye.fill")
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
                bullet("battery.25percent", "A battery floor (default 10%) always brings it back to normal sleep.")
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
                Text(state.helperState == .simulated ? "Simulated helper active" : "Helper installed and verified")
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
            default:
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
                Text("Never stranded")
                    .font(.largeTitle.weight(.bold))
                Text("The sleep override can't outlive Lidless. Every failure path restores normal sleep:")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: Theme.s2) {
                bullet("bolt.heart", "Cutoffs, disarm, quit — normal sleep first, always.")
                bullet("ant", "App or helper crash: a watchdog and launchd recovery restore within seconds; a reboot also cleans up.")
                bullet("eye.trianglebadge.exclamationmark", "The menu bar eye warns any time the override is on — even if another tool set it.")
                bullet("trash", "Uninstall lives in Setup & Help: one click removes the helper and every trace. Manual fallback: \(LidlessIDs.manualFallbackCommand)")
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
