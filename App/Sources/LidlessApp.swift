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
        if state.isArmed { return "Lidless: staying awake" }
        if state.overrideLeaked { return "Lidless: sleep override active outside Lidless" }
        return "Lidless: sleeping normally"
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

    /// Feature 10: quitting while armed must ask, and can never strand the
    /// override. (Even a SIGKILL can't: the helper restores on connection
    /// invalidation, and the watchdog + sentinel back that up.)
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let state = Self.stateProvider?(), state.isArmed else {
            return .terminateNow
        }

        let alert = NSAlert()
        alert.messageText = "Lidless is keeping your Mac awake"
        alert.informativeText = "Quitting restores normal sleep first. With the lid closed, your Mac will go to sleep shortly after."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Disarm & Quit")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            Task { @MainActor in
                await state.disarmForQuit()
                NSApp.reply(toApplicationShouldTerminate: true)
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
