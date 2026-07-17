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
        } header: {
            Text("Privileged helper")
        } footer: {
            Text("The helper is a tiny root daemon that runs `pmset` on Lidless's behalf. You authorize it once; every code path it has — including crash recovery and a watchdog — restores normal sleep.")
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
                Image(systemName: "arrow.triangle.2.circlepath").foregroundStyle(.orange)
            case .notResponding:
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
            case .notInstalled, .unknown:
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
        case .stale(let version): "Helper v\(version) is outdated"
        case .notResponding: "Installed but not responding"
        case .notInstalled: "Not installed"
        case .unknown: "Checking…"
        }
    }

    private var statusDetail: String {
        switch state.helperState {
        case .ready: "Keep-awake is fully operational."
        case .simulated: "No system changes are made in this mode."
        case .requiresApproval: "Open System Settings → General → Login Items & Extensions, and allow “Lidless”."
        case .stale: "Reinstall to update the helper."
        case .notResponding(let error): error
        case .notInstalled: "One-time install; macOS asks for your password."
        case .unknown: ""
        }
    }

    @ViewBuilder
    private var statusActions: some View {
        switch state.helperState {
        case .notInstalled, .stale, .notResponding:
            Button(state.helperState == .notInstalled ? "Install Helper…" : "Reinstall…") {
                Task {
                    busy = true
                    await state.installHelper()
                    busy = false
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(busy)
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
            ProgressView().controlSize(.small)
        }
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
                Text("Manual fallback")
                    .font(.body.weight(.medium))
                Text("If Lidless is ever gone but sleep stays disabled (it shouldn't be possible), one command undoes everything:")
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
                Text("This restores normal sleep, removes the privileged helper and its data, removes the login item, and deletes settings & history. The app itself is left for you to drag to the Trash.")
            }
            .alert(item: $uninstallResult) { result in
                switch result {
                case .success:
                    Alert(
                        title: Text("Lidless is uninstalled"),
                        message: Text("Normal sleep is restored and all components are removed. Quit and drag Lidless.app to the Trash to finish."),
                        primaryButton: .default(Text("Quit Now")) {
                            NSApp.terminate(nil)
                        },
                        secondaryButton: .cancel(Text("Later"))
                    )
                case .failure(let message):
                    Alert(
                        title: Text("Uninstall didn't finish"),
                        message: Text("\(message)\n\nNothing dangerous remains: if in doubt, run \(LidlessIDs.manualFallbackCommand) in Terminal."),
                        dismissButton: .default(Text("OK"))
                    )
                }
            }
        } header: {
            Text("Uninstall")
        } footer: {
            Text("Leaving should be easy: one click removes every trace except the app bundle.")
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
