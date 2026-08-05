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

    /// Termination is fail-closed: the recovery checkpoint may later restore
    /// and quit in one operation, but this presentation checkpoint permits
    /// termination only from a verified-normal state.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let state = Self.stateProvider?() else {
            return .terminateNow
        }
        guard state.sleepPresentation == .verifiedNormal else {
            state.lastError = "Lidless will quit only after normal sleep is verified. Restore normal sleep, then try again."
            state.requestMainWindow()
            return .terminateCancel
        }
        return .terminateNow
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let state = Self.stateProvider?() else { return }
        for url in urls {
            state.handleURL(url)
        }
    }
}
