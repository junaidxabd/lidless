import AppKit
import SwiftUI
import LidlessCore

/// Helper status, evidence, and recovery guidance. Public helper cleanup is
/// deliberately absent until removal can be enabled under a reviewed policy.
struct SetupPane: View {
    @Environment(AppState.self) private var state
    @State private var busy = false
    @State private var helperLog = ""

    var body: some View {
        Form {
            helperSection
            behaviorSection
            verifySection
            logSection
            aboutSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .navigationTitle("Setup & Help")
        .background(Theme.canvas)
        .task {
            await state.refreshHelperState()
        }
    }

    // MARK: - Helper status

    private var helperSection: some View {
        Section {
            HStack(spacing: Theme.s3) {
                statusIcon
                VStack(alignment: .leading, spacing: 2) {
                    Text(statusTitle)
                        .font(.body.weight(.medium))
                    Text(statusDetail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                statusActions
            }
            .padding(.vertical, Theme.s1)

            if let error = state.lastError {
                DisclosureGroup("Latest error") {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(Theme.critical)
                        .textSelection(.enabled)
                }
            }

            if let terminalRecoveryDetail {
                DisclosureGroup("Recovery details") {
                    Text(terminalRecoveryDetail)
                        .font(.callout)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }
        } header: {
            Text("Privileged helper")
        } footer: {
            Text("The helper is a narrow root daemon that runs pmset on Lidless's behalf. Disarm, watchdog, and connection-loss paths request normal sleep; only fresh registry evidence can verify the result.")
        }
    }

    private var statusIcon: some View {
        Group {
            switch state.helperState {
            case .ready, .simulated:
                Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
            case .requiresApproval:
                Image(systemName: "person.badge.clock.fill").foregroundStyle(.orange)
            case .stale:
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            case .notResponding:
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
            case .unknown:
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            case .checking:
                Image(systemName: "circle.dashed").foregroundStyle(.secondary)
            case .notInstalled:
                Image(systemName: "circle.dashed").foregroundStyle(.secondary)
            }
        }
        .font(.title2)
        .frame(width: 32)
    }

    private var statusTitle: String {
        switch state.helperState {
        case .ready(let version): "Installed and responding (v\(version))"
        case .simulated: "Simulated helper (dry-run mode)"
        case .requiresApproval: "Waiting for your approval"
        case .stale(let version, let revision):
            "Helper protocol v\(version), revision \(revisionLabel(revision)), requires a reviewed removal procedure"
        case .notResponding: "Installed but not responding"
        case .notInstalled: "Not installed"
        case .unknown: "Helper status unverified"
        case .checking: "Checking…"
        }
    }

    private var statusDetail: String {
        switch state.helperState {
        case .ready: "The helper is responding; every action remains proof-gated."
        case .simulated: "No system changes are made in this mode."
        case .requiresApproval: "Open System Settings → General → Login Items & Extensions, and allow “Lidless”."
        case .stale:
            "Public cleanup and replacement are disabled. Keep the helper registered and follow the reviewed recovery procedure below."
        case .notResponding:
            "The installed helper could not be classified, so replacement is disabled."
        case .notInstalled: "One-time install; macOS asks for your password."
        case .unknown:
            "Lidless will not assume the helper is absent or safe to replace."
        case .checking:
            "Lidless has not classified the installed helper yet."
        }
    }

    private var terminalRecoveryDetail: String? {
        switch state.helperState {
        case .stale(let version, let revision):
            return "Protocol v\(version), revision \(revisionLabel(revision)), has no reviewed public cleanup path. Run \(LidlessIDs.manualFallbackCommand) only for emergency sleep recovery, then independently verify normal sleep. That command does not remove the helper, cancel helper-managed wakes, restore other settings, or delete helper data. Keep the helper registered and contact support for a revision-specific reviewed procedure."
        case .notResponding(let error):
            return "\(error) Run \(LidlessIDs.manualFallbackCommand) only for emergency sleep recovery, then independently verify normal sleep. The command does not remove the helper or establish its registration state. Keep the helper registered and contact support for a reviewed procedure."
        case .unknown:
            return "Helper classification is unavailable. Run \(LidlessIDs.manualFallbackCommand) only for emergency sleep recovery, then independently verify normal sleep. The command does not remove a helper or establish registration state. Keep any helper registered and contact support if Re-check cannot classify it."
        default:
            return nil
        }
    }

    @ViewBuilder
    private var statusActions: some View {
        switch state.helperState {
        case .notInstalled:
            Button("Install Helper…") {
                Task {
                    busy = true
                    await state.installHelper()
                    busy = false
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(busy)
        case .stale, .notResponding:
            Text("Public replacement disabled")
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.caution)
        case .requiresApproval:
            Button("Open Login Items…") {
                state.openApprovalSettings()
            }
            .buttonStyle(.borderedProminent)
            Button("Re-check") {
                Task { await state.refreshHelperState() }
            }
        case .ready, .simulated:
            Button("Re-check") {
                Task { await state.refreshHelperState() }
            }
        case .unknown:
            Button("Re-check") {
                Task { await state.refreshHelperState() }
            }
        // Progress is truthful only before the first classification lands.
        // A concluded-but-unverifiable helper is `.unknown` above and keeps
        // its terminal copy and Re-check action instead of a spinner.
        case .checking:
            ProgressView().controlSize(.small)
        }
    }

    private func revisionLabel(_ revision: Int?) -> String {
        revision.map(String.init) ?? "missing"
    }

    // MARK: - App behavior

    private var behaviorSection: some View {
        Section("App") {
            Toggle(
                "Launch at login",
                isOn: Binding(
                    get: { state.launchAtLogin },
                    set: { state.setLaunchAtLogin($0) }
                )
            )
            .disabled(state.isSimulation)
            LabeledContent("Menu bar") {
                Text("Moon means normal sleep was verified; bolt means a Lidless keep-awake session was verified. Warning and question symbols require attention.")
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    // MARK: - Verify / fallback

    private var verifySection: some View {
        Section {
            VStack(alignment: .leading, spacing: Theme.s2) {
                Text("Verify the override is off")
                    .font(.body.weight(.medium))
                Text("A green normal-sleep proof in Lidless is based on a fresh registry read. To verify independently, run this in Terminal; it must print “SleepDisabled = No”:")
                    .font(.callout)
                    .foregroundStyle(Theme.textSecondary)
                CommandField(
                    command: "ioreg -r -d1 -c IOPMrootDomain | grep SleepDisabled",
                    accessibilityLabel: "Copy registry verification command"
                )
            }
            .padding(.vertical, Theme.s1)

            VStack(alignment: .leading, spacing: Theme.s2) {
                Text("Emergency sleep recovery")
                    .font(.body.weight(.medium))
                Text("If normal sleep cannot be verified, this command requests only the main normal-sleep flag. It does not remove the helper, cancel helper-managed wakes, restore other settings, or delete helper data:")
                    .font(.callout)
                    .foregroundStyle(Theme.textSecondary)
                CommandField(
                    command: LidlessIDs.manualFallbackCommand,
                    accessibilityLabel: "Copy emergency recovery command"
                )
            }
            .padding(.vertical, Theme.s1)
        } header: {
            Text("Trust, but verify")
        }
    }

    // MARK: - Helper log

    private var logSection: some View {
        Section("Helper log") {
            DisclosureGroup("Show the helper's audit trail") {
                ScrollView {
                    Text(helperLog.isEmpty ? "No log yet — it appears after the first arm." : helperLog)
                        .font(.caption.monospaced())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(height: 180)
                Button("Refresh") {
                    helperLog = state.helperLogText()
                }
            }
            .onAppear {
                helperLog = state.helperLogText()
            }
        }
    }

    private var aboutSection: some View {
        Section {
            LabeledContent("Version", value: Bundle.main.shortVersion)
            Link(destination: URL(string: "https://github.com/junaidxabd/lidless")!) {
                Label("Lidless on GitHub", systemImage: "arrow.up.right.square")
            }
        } header: {
            Text("About")
        }
    }
}

// MARK: - Command field with copy

struct CommandField: View {
    let command: String
    let accessibilityLabel: String
    @State private var copied = false

    init(command: String, accessibilityLabel: String = "Copy command") {
        self.command = command
        self.accessibilityLabel = accessibilityLabel
    }

    var body: some View {
        HStack(spacing: Theme.s2) {
            Text(command)
                .font(.callout.monospaced())
                .textSelection(.enabled)
                .padding(.horizontal, Theme.s3)
                .padding(.vertical, Theme.s2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: Theme.s2, style: .continuous))
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(command, forType: .string)
                copied = true
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    copied = false
                }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint("Copies this Terminal command to the clipboard")
        }
    }
}

extension Bundle {
    var shortVersion: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
