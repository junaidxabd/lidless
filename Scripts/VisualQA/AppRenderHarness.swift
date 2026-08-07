import AppKit

/// Repository-local entry point for the complete deterministic app screenshot
/// matrix. It is compiled with every app source while the shipping `LidlessApp`
/// entry point is excluded. `--render-screenshots` makes `AppState.bootstrap()`
/// select ephemeral simulation stores and simulated monitors, so this harness
/// cannot install a helper or mutate system power settings.
@main
struct AppRenderHarnessMain {
    @MainActor
    static func main() async throws {
        _ = NSApplication.shared
        let state = AppState.bootstrap()
        guard state.isSimulation else {
            throw CocoaError(.featureUnsupported)
        }
        try await ScreenshotRenderer.render(state: state)
    }
}
