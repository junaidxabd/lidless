import AppKit
import SwiftUI

@main
struct LidlessApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var state: AppState

    init() {
        let state = AppState.bootstrap()
        _state = State(initialValue: state)
        AppDelegate.stateProvider = { state }

        if CommandLine.arguments.contains("--render-screenshots") {
            // Synchronously, before any scene mounts: the label's onAppear
            // must never race a window open during rendering. The store is
            // ephemeral in this mode, so nothing is persisted.
            state.config.onboardingComplete = true
            ScreenshotRenderer.renderAndExit(state: state)
        } else {
            state.start()
        }
    }

    var body: some Scene {
        // Locked to dark: the interface is built around glow-on-void; light
        // mode would wash the state language out.
        MenuBarExtra {
            MenuPanelView()
                .environment(state)
                .preferredColorScheme(.dark)
        } label: {
            MenuBarLabel()
                .environment(state)
        }
        .menuBarExtraStyle(.window)

        Window("Lidless", id: "main") {
            MainWindowView()
                .environment(state)
                .frame(minWidth: 840, minHeight: 560)
                .preferredColorScheme(.dark)
        }
        .defaultSize(width: 900, height: 620)
        .defaultLaunchBehavior(.suppressed)
    }
}

// MARK: - Menu bar label (the always-present indicator)

/// The one UI element that is always on screen. Its icon states are the
/// "never silently on" contract: filled eye = override active via a session,
/// slashed eye = normal sleep, warning eye = override on outside Lidless.
/// It also hosts the openWindow bridge, since it's the only view guaranteed
/// to be alive for the app's whole lifetime.
private struct MenuBarLabel: View {
    @Environment(AppState.self) private var state
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: state.menuBarSystemImage)
            if let countdown = state.menuBarText {
                Text(countdown)
                    .monospacedDigit()
            }
        }
        .accessibilityLabel(accessibilityText)
        .onChange(of: state.mainWindowRequestToken) {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        .onAppear {
            // First launch for a stranger: the window with onboarding must
            // present itself. This label is the first view alive at launch.
            if !state.config.onboardingComplete {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    private var accessibilityText: String {
        switch state.sleepPresentation {
        case .verifiedNormal: "Lidless: sleeping normally"
        case .verifyingArm: "Lidless: verifying the sleep override"
        case .verifiedArmed: "Lidless: staying awake"
        case .restoring: "Lidless: restoring normal sleep"
        case .outsideOverride: "Lidless: sleep override active outside Lidless"
        case .unknown: "Lidless: system sleep state unknown"
        }
    }
}

// MARK: - App delegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static var stateProvider: (@MainActor () -> AppState)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // The dark lock must also cover AppKit surfaces (alerts, dialogs).
        NSApp.appearance = NSAppearance(named: .darkAqua)
    }

    /// Termination is fail-closed. Immediate quit is allowed only from a fresh,
    /// verified-normal state after queued arm intent has been fenced. An armed
    /// quit remains pending until the same restore generation proves safe.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let state = Self.stateProvider?() else {
            return .terminateCancel
        }

        if state.prepareForImmediateTermination() {
            return .terminateNow
        }

        // Every refusal below states its reason in `lastError`, which the
        // default Overview pane does not render — so each one names the pane
        // that does. A quit the user cannot complete and cannot see a reason
        // for is the failure mode these messages exist to prevent.

        // Never quit through an in-flight arm: its XPC outcome is not known
        // yet. Keep the app alive until that operation either proves the arm
        // or enters the visible restore path.
        if state.phase == .arming {
            state.lastError = "Lidless is still verifying the sleep override. Try quitting again in a moment."
            state.requestMainWindow(pane: .setup)
            return .terminateCancel
        }

        if state.phase == .disarming {
            // `.disarming` alone no longer implies work is in progress: an
            // unsupported-wire generation is fenced and will not retry. Quit
            // still stays blocked because normal sleep is unverified, but the
            // copy must not promise a verification Lidless has stopped
            // attempting — or a retry that will not clear this state.
            state.lastError = state.automaticRecoveryStopped
                ? "Lidless stopped automatic recovery because the helper uses an unsupported wire protocol, so it cannot verify normal sleep and will not report restoration. Use the emergency sleep recovery command in Setup & Help and verify normal sleep. Lidless cannot clear this state itself, so quitting from the menu stays blocked. Force-quitting cannot make the sleep setting worse — Lidless has already stopped changing it — and ending the app's connection is a signal a Lidless helper treats as a reason to restore normal sleep. Contact Lidless support."
                : "Lidless is still restoring normal sleep. Keep the app open until restoration is verified."
            // Overview renders neither `lastError` nor anything but the
            // `.restoring` hero, so open the pane that shows the message and
            // the emergency command it points at.
            state.requestMainWindow(pane: .setup)
            return .terminateCancel
        }

        guard state.phase == .armed else {
            state.lastError = "Lidless will quit only after normal sleep is verified. Restore normal sleep, then try again."
            state.requestMainWindow(pane: .setup)
            return .terminateCancel
        }

        let alert = NSAlert()
        if state.sleepPresentation == .verifiedArmed {
            alert.messageText = "Lidless is keeping your Mac awake"
            alert.informativeText = "Normal macOS sleep behavior will be restored before Lidless quits."
        } else {
            alert.messageText = "System sleep state must be verified before quitting"
            alert.informativeText = "Lidless will restore normal sleep and quit only after the helper proves restoration."
        }
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Disarm & Quit")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            Task { @MainActor in
                let restored = await state.disarmForQuit()
                if !restored {
                    state.requestMainWindow(pane: .setup)
                }
                // Keep AppKit's terminate-later request open for the entire
                // recovery. A false reply is sent only when that exact restore
                // was superseded or cancelled, never merely because it needed
                // another verification attempt.
                NSApp.reply(toApplicationShouldTerminate: restored)
            }
            return .terminateLater
        }
        return .terminateCancel
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let state = Self.stateProvider?() else { return }
        for url in urls {
            state.handleURL(url)
        }
    }
}
