import AppKit
import SwiftUI
import LidlessCore

/// Helper lifecycle, transparency, and the exit door. People trust a
/// system-level tool more when leaving it is easy and verifiable.
struct SetupPane: View {
    @Environment(AppState.self) private var state
    @State private var confirmingUninstall = false
    @State private var uninstallResult: UninstallResult?
    @State private var busy = false
    @State private var helperLog = ""

    enum UninstallResult: Identifiable {
        case success
        case failure(String)
        var id: String {
            switch self {
            case .success: "success"
            case .failure(let message): message
            }
        }
    }

    var body: some View {
        Form {
            helperSection
            behaviorSection
            verifySection
            logSection
            uninstallSection
            aboutSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .navigationTitle("Setup & Help")
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
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }
        } header: {
            Text("Privileged helper")
        } footer: {
            Text("The helper is a tiny root daemon that runs `pmset` on Lidless's behalf. Its disarm, watchdog, and connection-loss layers request and retry restoration. Recovery or removal is reported complete only after verified normal sleep; use the checks below whenever recovery is uncertain.")
        }
    }

    private var statusIcon: some View {
        Group {
            switch state.helperState {
            case .ready, .simulated:
                Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
            case .requiresApproval:
                Image(systemName: "person.badge.clock.fill").foregroundStyle(.orange)
            // The circular-arrows glyph reads as "retryable update in
            // progress". Only the reviewed-predecessor case has an automatic
            // path; every other stale revision is terminal.
            case .stale(let version, let revision)
                where SleepOverrideSafety.isReviewedStaleReplacementCompatible(
                    helperVersion: version,
                    helperSafetyRevision: revision
                ):
                Image(systemName: "arrow.triangle.2.circlepath").foregroundStyle(.orange)
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
            if SleepOverrideSafety.isReviewedStaleReplacementCompatible(
                helperVersion: version,
                helperSafetyRevision: revision
            ) {
                "Helper safety update required"
            } else {
                "Helper protocol v\(version), revision \(revisionLabel(revision)), requires a reviewed removal procedure"
            }
        case .notResponding: "Installed but not responding"
        case .notInstalled: "Not installed"
        case .unknown: "Helper status unverified"
        case .checking: "Checking…"
        }
    }

    private var statusDetail: String {
        switch state.helperState {
        case .ready: "Keep-awake is fully operational."
        case .simulated: "No system changes are made in this mode."
        case .requiresApproval: "Open System Settings → General → Login Items & Extensions, and allow “Lidless”."
        case .stale(let version, let revision):
            if SleepOverrideSafety.isReviewedStaleReplacementCompatible(
                helperVersion: version,
                helperSafetyRevision: revision
            ) {
                "This responder uses the current wire protocol but not this app's exact safety behavior revision. Replacing removes the current helper first: it cancels its scheduled wakes, restores the other settings it manages, deletes its data, and deregisters it. The new helper will not be registered until that cleanup and normal sleep are independently verified, and if that registration then fails you will be left with no helper registered until you install one again."
            } else {
                "Automatic cleanup is unavailable because this helper's complete removal behavior is not reviewed by this app. Emergency sleep recovery only: run \(LidlessIDs.manualFallbackCommand) and verify normal sleep. That command does not remove the helper, cancel its wakes, restore other settings, or delete its data. Keep the helper registered and contact Lidless support for a separately reviewed, revision-specific removal procedure."
            }
        case .notResponding(let error):
            "\(error) Automatic replacement is unavailable without a compatible live reply. Emergency sleep recovery only: run \(LidlessIDs.manualFallbackCommand) and verify normal sleep. That command does not remove the helper or complete replacement. Keep the helper registered and contact Lidless support for a separately reviewed removal procedure for the installed helper."
        case .notInstalled: "One-time install; macOS asks for your password."
        case .unknown:
            "Helper classification is unavailable, so Lidless will not assume the helper is absent or safe to replace. Emergency sleep recovery only: run \(LidlessIDs.manualFallbackCommand) and verify normal sleep. That command does not remove a helper or establish registration state. Keep any helper registered and contact Lidless support if Re-check cannot classify it."
        case .checking:
            "Lidless has not classified the installed helper yet."
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
        case .stale(let version, let revision)
            where SleepOverrideSafety.isReviewedStaleReplacementCompatible(
                helperVersion: version,
                helperSafetyRevision: revision
            ):
            Button("Replace Helper…") {
                Task {
                    busy = true
                    await state.installHelper()
                    busy = false
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(busy)
        case .stale, .notResponding:
            Text("Reviewed removal procedure required")
                .font(.caption.weight(.medium))
                .foregroundStyle(.orange)
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
                Text("Lidless always lives in the menu bar — the eye is filled whenever your Mac is being kept awake.")
                    .foregroundStyle(.secondary)
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
                Text("The menu bar eye is slashed when sleep is normal. To verify independently, run this in Terminal — it must print “SleepDisabled = No”:")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                CommandField(command: "ioreg -r -d1 -c IOPMrootDomain | grep SleepDisabled")
            }
            .padding(.vertical, Theme.s1)

            VStack(alignment: .leading, spacing: Theme.s2) {
                Text("Emergency sleep recovery")
                    .font(.body.weight(.medium))
                Text("If normal sleep cannot be verified, this command restores only the main system sleep flag. It does not remove the helper, cancel helper-managed wakes, restore other settings, or delete helper data:")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                CommandField(command: LidlessIDs.manualFallbackCommand)
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

    // MARK: - Uninstall

    private var uninstallSection: some View {
        Section {
            Button(role: .destructive) {
                confirmingUninstall = true
            } label: {
                Label("Uninstall Lidless…", systemImage: "trash")
            }
            .confirmationDialog(
                "Uninstall Lidless?",
                isPresented: $confirmingUninstall,
                titleVisibility: .visible
            ) {
                Button("Uninstall", role: .destructive) {
                    Task {
                        busy = true
                        let error = await state.uninstall()
                        uninstallResult = error.map { .failure($0) } ?? .success
                        busy = false
                    }
                }
            } message: {
                Text("Removal is reported successful only after Lidless verifies normal sleep and confirms the helper is not registered.")
            }
            .disabled(busy || state.isSimulation)
            .alert(item: $uninstallResult) { result in
                switch result {
                case .success:
                    Alert(
                        title: Text("Helper registration inactive"),
                        message: Text("Normal sleep was verified and the helper is not registered. Quit and drag Lidless.app to the Trash to finish."),
                        primaryButton: .default(Text("Quit Now")) {
                            NSApp.terminate(nil)
                        },
                        secondaryButton: .cancel(Text("Later"))
                    )
                case .failure(let message):
                    Alert(
                        title: Text("Uninstall didn't finish"),
                        // The guidance is composed alongside the failure so it
                        // can match what that code path actually proved.
                        message: Text(message),
                        dismissButton: .default(Text("OK"))
                    )
                }
            }
        } header: {
            Text("Uninstall")
        } footer: {
            Text(state.isSimulation
                ? "Exit simulation to remove the installed helper."
                : "Success requires inactive helper registration and a fresh normal-sleep reading.")
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
    @State private var copied = false

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
            .accessibilityLabel("Copy command")
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
