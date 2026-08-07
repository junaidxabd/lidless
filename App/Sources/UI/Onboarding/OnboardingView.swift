import SwiftUI
import LidlessCore

enum OnboardingRenderScenario: String, CaseIterable {
    case intro
    case helper
    case recovery
    case helperFailure

    var step: Int {
        switch self {
        case .intro: 0
        case .helper, .helperFailure: 1
        case .recovery: 2
        }
    }

    var filename: String {
        "onboarding-\(rawValue.replacingOccurrences(of: "Failure", with: "-failure")).png"
    }
}

/// Three concise first-run steps: understand the state model, authorize the
/// narrow helper, and know how to verify recovery independently.
struct OnboardingView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let renderScenario: OnboardingRenderScenario?
    @State private var step: Int

    private let stepCount = 3

    init(renderScenario: OnboardingRenderScenario? = nil) {
        self.renderScenario = renderScenario
        _step = State(initialValue: renderScenario?.step ?? 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                Group {
                    switch displayedStep {
                    case 0: intro
                    case 1: helperStep
                    default: recoveryStep
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Theme.s8)
                .padding(.vertical, Theme.s6)
            }
            .scrollIndicators(.automatic)

            Divider()
                .overlay(Theme.separator)

            footer
                .padding(Theme.s5)
                .background(Theme.surface)
        }
        .frame(width: 600, height: 640)
        .background(Theme.canvas)
        .preferredColorScheme(.dark)
        .animation(reduceMotion ? nil : Theme.gentleTransition, value: displayedStep)
    }

    private var displayedStep: Int {
        renderScenario?.step ?? step
    }

    // MARK: - Step 1: understand the instrument

    private var intro: some View {
        VStack(alignment: .leading, spacing: Theme.s5) {
            HStack(alignment: .center, spacing: Theme.s4) {
                LidSeamMark()
                    .frame(width: 76, height: 76)
                    .accessibilityLabel("Lidless lid seam mark")

                VStack(alignment: .leading, spacing: Theme.s2) {
                    StatusPill(presentation: .verifiedNormal)
                    Text("Know what the Mac will do")
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                }
            }

            Text("Lidless can request a system-wide keep-awake override for closed-lid work. It reports success only when helper ownership and the macOS registry agree.")
                .font(.title3)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            onboardingCard {
                onboardingRow(
                    "bolt",
                    "Keep-awake",
                    "Arming pauses at a confirmation and completes only after current proof is available."
                )
                onboardingRow(
                    "battery.25percent",
                    "Cutoffs",
                    "Battery, time, and schedule limits end keep-awake and request normal sleep."
                )
                onboardingRow(
                    "thermometer.medium",
                    "Thermal evidence",
                    "The guard reacts to supported macOS readings; it does not certify closed-bag or hardware safety."
                )
            }

            Text("Use Lidless only after validating your own Mac, workload, ventilation, power, and recovery procedure.")
                .font(.callout)
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Step 2: authorize the helper

    private var helperStep: some View {
        VStack(alignment: .leading, spacing: Theme.s5) {
            HStack(spacing: Theme.s3) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 38, weight: .medium))
                    .foregroundStyle(Theme.verifiedActive)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Theme.s1) {
                    Text("Authorize the narrow helper")
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("One macOS approval")
                        .font(.callout)
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            Text("The app itself is unprivileged. Its helper performs the limited power-management requests and returns evidence that Lidless evaluates before claiming a state.")
                .font(.title3)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            helperStatusCard

            Text("Installing or approving the helper is not proof that normal sleep or keep-awake is active. The status seal always reflects the latest admitted evidence.")
                .font(.callout)
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var helperStatusCard: some View {
        if renderScenario == .helperFailure {
            VStack(alignment: .leading, spacing: Theme.s3) {
                Label("Helper response is unverified", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(Theme.critical)
                Text("Lidless will not assume the helper is absent, current, or safe to replace.")
                    .font(.callout)
                    .foregroundStyle(Theme.textSecondary)
                DisclosureGroup("Recovery details", isExpanded: alwaysExpanded) {
                    VStack(alignment: .leading, spacing: Theme.s3) {
                        Text("Keep any helper registered. Use the emergency command only to request the main normal-sleep flag, then independently verify the registry result. The command does not remove a helper, cancel helper-managed wakes, restore other settings, or establish registration state.")
                            .font(.callout)
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        CommandField(
                            command: LidlessIDs.manualFallbackCommand,
                            accessibilityLabel: "Copy emergency recovery command"
                        )
                    }
                    .padding(.top, Theme.s2)
                }
            }
            .padding(Theme.s4)
            .card(tint: Theme.critical)
        } else {
            liveHelperStatus
        }
    }

    private var alwaysExpanded: Binding<Bool> {
        Binding(get: { true }, set: { _ in })
    }

    private var liveHelperStatus: some View {
        VStack(alignment: .leading, spacing: Theme.s3) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.s3) {
                Image(systemName: helperSymbol)
                    .foregroundStyle(helperTint)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Theme.s1) {
                    Text(helperTitle)
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Text(helperSummary)
                        .font(.callout)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Theme.s2)
                helperAction
            }

            if let detail = helperRecoveryDetail {
                DisclosureGroup("Recovery details") {
                    Text(detail)
                        .font(.callout)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                        .padding(.top, Theme.s2)
                }
            }
        }
        .padding(Theme.s4)
        .card(tint: helperTint)
    }

    private var helperSymbol: String {
        switch state.helperState {
        case .ready, .simulated: "checkmark.shield.fill"
        case .requiresApproval: "person.badge.clock.fill"
        case .checking, .notInstalled: "circle.dashed"
        case .stale, .notResponding, .unknown: "exclamationmark.triangle.fill"
        }
    }

    private var helperTint: Color {
        switch state.helperState {
        case .ready, .simulated: Theme.verifiedNormal
        case .checking, .notInstalled: Theme.transition
        case .requiresApproval, .stale: Theme.caution
        case .notResponding, .unknown: Theme.critical
        }
    }

    private var helperTitle: String {
        switch state.helperState {
        case .ready: "Helper installed and responding"
        case .simulated: "Simulated helper active"
        case .requiresApproval: "Approval required"
        case .checking: "Checking helper"
        case .notInstalled: "Helper not installed"
        case .stale: "Helper revision does not match"
        case .notResponding: "Helper is not responding"
        case .unknown: "Helper status is unverified"
        }
    }

    private var helperSummary: String {
        switch state.helperState {
        case .ready: "Current replies are available; actions remain proof-gated."
        case .simulated: "No system power settings are changed in simulation."
        case .requiresApproval: "Allow Lidless under Login Items & Extensions, then re-check."
        case .checking: "Lidless has not classified the installed helper yet."
        case .notInstalled: "macOS will request authorization for a one-time install."
        case .stale: "Public cleanup and replacement are disabled."
        case .notResponding: "Replacement is disabled until the helper can be classified."
        case .unknown: "Lidless will not assume the helper is absent or safe to replace."
        }
    }

    @ViewBuilder
    private var helperAction: some View {
        switch state.helperState {
        case .notInstalled:
            Button("Install Helper…") {
                guard renderScenario == nil else { return }
                Task { await state.installHelper() }
            }
            .buttonStyle(.borderedProminent)
        case .requiresApproval:
            VStack(alignment: .trailing, spacing: Theme.s2) {
                Button("Open Login Items…") {
                    guard renderScenario == nil else { return }
                    state.openApprovalSettings()
                }
                .buttonStyle(.borderedProminent)
                Button("Re-check") {
                    guard renderScenario == nil else { return }
                    Task { await state.refreshHelperState() }
                }
            }
        case .checking:
            ProgressView()
                .controlSize(.small)
        case .ready, .simulated:
            EmptyView()
        case .stale, .notResponding, .unknown:
            Text("No public replacement")
                .font(.caption.weight(.medium))
                .foregroundStyle(helperTint)
        }
    }

    private var helperRecoveryDetail: String? {
        switch state.helperState {
        case .stale(let version, let revision):
            return "Protocol v\(version), revision \(revision.map(String.init) ?? "missing"), does not have a public cleanup path. Keep the helper registered, use emergency recovery only to request normal sleep, verify independently, and contact support for a reviewed procedure."
        case .notResponding(let detail):
            return "\(detail) Keep the helper registered. Emergency recovery does not remove it or establish registration state."
        case .unknown:
            return "Keep any helper registered. Emergency recovery does not remove a helper or establish registration state."
        default:
            return nil
        }
    }

    // MARK: - Step 3: verify recovery

    private var recoveryStep: some View {
        VStack(alignment: .leading, spacing: Theme.s5) {
            HStack(spacing: Theme.s3) {
                StatusPill(presentation: .verifiedNormal)
                Text("Recovery requires proof")
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
            }

            Text("Cutoffs, manual disarm, quit, connection loss, and watchdog paths can request normal sleep. Lidless reports recovery only after current registry evidence verifies it.")
                .font(.title3)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            onboardingCard {
                onboardingRow(
                    "checkmark.shield",
                    "Verified normal",
                    "A green proof seal means the current registry reading shows the override off."
                )
                onboardingRow(
                    "exclamationmark.triangle",
                    "Outside override",
                    "An orange warning means the override is active without a verified Lidless owner."
                )
                onboardingRow(
                    "questionmark.circle",
                    "Unverified",
                    "A red state means Lidless cannot claim what the Mac will do when the lid closes."
                )
            }

            VStack(alignment: .leading, spacing: Theme.s2) {
                Text("Independent registry check")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Text("The result must include SleepDisabled = No before you treat normal sleep as verified.")
                    .font(.callout)
                    .foregroundStyle(Theme.textSecondary)
                CommandField(
                    command: "ioreg -r -d1 -c IOPMrootDomain | grep SleepDisabled",
                    accessibilityLabel: "Copy registry verification command"
                )
            }

            Toggle(
                "Launch Lidless at login for schedule supervision",
                isOn: Binding(
                    get: { state.launchAtLogin },
                    set: { value in
                        guard renderScenario == nil else { return }
                        state.setLaunchAtLogin(value)
                    }
                )
            )
            .toggleStyle(.checkbox)
            .disabled(state.isSimulation)
        }
    }

    private func onboardingCard<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.s4) {
            content()
        }
        .padding(Theme.s4)
        .card()
    }

    private func onboardingRow(
        _ symbol: String,
        _ title: String,
        _ detail: String
    ) -> some View {
        HStack(alignment: .top, spacing: Theme.s3) {
            Image(systemName: symbol)
                .foregroundStyle(Theme.verifiedActive)
                .frame(width: Theme.s5)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Theme.s1) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.textPrimary)
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            if displayedStep == 0 {
                Button("Set Up Later") { finish() }
                    .foregroundStyle(Theme.textSecondary)
            } else {
                Button("Back") {
                    guard renderScenario == nil else { return }
                    step -= 1
                }
                .keyboardShortcut(.cancelAction)
            }

            Spacer()

            HStack(spacing: Theme.s2) {
                ForEach(0..<stepCount, id: \.self) { index in
                    Circle()
                        .fill(index == displayedStep ? Theme.verifiedActive : Theme.separatorStrong)
                        .frame(width: 7, height: 7)
                        .accessibilityHidden(true)
                }
            }

            Spacer()

            Button(displayedStep == stepCount - 1 ? "Start Using Lidless" : "Continue") {
                guard renderScenario == nil else { return }
                if step == stepCount - 1 {
                    finish()
                } else {
                    step += 1
                }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .accessibilityHint(
                displayedStep == stepCount - 1
                    ? "Completes onboarding"
                    : "Shows onboarding step \(displayedStep + 2) of \(stepCount)"
            )
        }
    }

    private func finish() {
        guard renderScenario == nil else { return }
        state.config.onboardingComplete = true
        dismiss()
    }
}

/// Rectilinear closed-lid mark: device mass, horizontal seam, and one blue
/// wake notch. Its geometry deliberately avoids mascot or face geometry.
private struct LidSeamMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.surfaceElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Theme.separatorStrong, lineWidth: 1)
                )

            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(Theme.textSecondary, lineWidth: 2)
                    .frame(width: 42, height: 28)
                Rectangle()
                    .fill(Theme.textPrimary)
                    .frame(width: 48, height: 2)
            }

            Capsule()
                .fill(Theme.verifiedActive)
                .frame(width: 12, height: 4)
                .offset(y: 15)
        }
    }
}
