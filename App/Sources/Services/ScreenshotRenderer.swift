import AppKit
import SwiftUI
import LidlessCore

/// `--render-screenshots`: drives the real app in simulation mode into
/// representative states and renders actual views to Docs/screenshots/*.png.
/// The README's images are genuine UI, regenerable with `make screenshots`.
@MainActor
enum ScreenshotRenderer {
    static func renderAndExit(state: AppState) {
        Task { @MainActor in
            let code: Int32
            do {
                try await render(state: state)
                code = 0
            } catch {
                FileHandle.standardError.write(Data("screenshot render failed: \(error)\n".utf8))
                code = 1
            }
            exit(code)
        }
    }

    private static func render(state: AppState) async throws {
        guard let simulation = state.simulation else {
            throw NSError(domain: "Lidless", code: 10, userInfo: [
                NSLocalizedDescriptionKey: "screenshots require --simulate",
            ])
        }
        state.notifications.suppressed = true
        state.config.onboardingComplete = true
        state.start()

        let outputDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Docs/screenshots", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        simulation.batteryPercent = 68
        simulation.onBattery = true
        simulation.drainPerHour = 9
        simulation.lidClosed = false
        // A believable trailing discharge curve so drain rate, projections,
        // and the battery chart render with data.
        let now = Date()
        state.seedRollingSamplesForRendering((0...12).map { index in
            BatterySample(
                time: now.addingTimeInterval(TimeInterval(index - 12) * 900),
                percent: 68 + Double(12 - index) * 2.25, // 9%/hr down to 68%
                isDischarging: true
            )
        })
        try await Task.sleep(for: .milliseconds(200))

        // 1. Disarmed panel.
        try write(panel(state), to: outputDir.appendingPathComponent("menu-disarmed.png"))

        // 2. Confirm card (the arming flow).
        state.beginArmFlow()
        try await Task.sleep(for: .milliseconds(100))
        try write(panel(state), to: outputDir.appendingPathComponent("menu-confirm.png"))

        // 3. Armed panel, lid closed.
        await state.confirmArm()
        simulation.lidClosed = true
        try await Task.sleep(for: .milliseconds(300))
        try write(panel(state), to: outputDir.appendingPathComponent("menu-armed.png"))

        // 4. Main window overview while armed (scroll content directly —
        // ImageRenderer can't rasterize NSScrollView-backed views).
        try write(
            window(
                OverviewContent().environment(state).padding(Theme.s6),
                size: CGSize(width: 900, height: 560)
            ),
            to: outputDir.appendingPathComponent("window-overview.png")
        )

        // 5. Onboarding.
        await state.disarm()
        try write(
            window(OnboardingView().environment(state), size: CGSize(width: 560, height: 560)),
            to: outputDir.appendingPathComponent("onboarding.png")
        )

        print("screenshots written to \(outputDir.path)")
    }

    private static func panel(_ state: AppState) -> NSImage? {
        image(MenuPanelView().environment(state).frame(width: Theme.panelWidth))
    }

    private static func window(_ content: some View, size: CGSize) -> NSImage? {
        image(content.frame(width: size.width, height: size.height))
    }

    private static func image(_ content: some View) -> NSImage? {
        let renderer = ImageRenderer(
            content: content
                .background(Theme.void)
                .environment(\.colorScheme, .dark)
        )
        renderer.scale = 2
        return renderer.nsImage
    }

    private static func write(_ image: NSImage?, to url: URL) throws {
        guard let image,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:])
        else {
            throw NSError(domain: "Lidless", code: 11, userInfo: [
                NSLocalizedDescriptionKey: "could not rasterize \(url.lastPathComponent)",
            ])
        }
        try png.write(to: url)
        print("wrote \(url.lastPathComponent)")
    }
}
