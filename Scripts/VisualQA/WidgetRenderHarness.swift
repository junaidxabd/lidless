import AppKit
import Foundation
import SwiftUI

/// Repository-local renderer for the deterministic WidgetRenderScenario matrix.
/// Compile this together with Widget/Sources/LidlessWidget.swift while defining
/// LIDLESS_WIDGET_RENDER_HARNESS so the shipping WidgetBundle entry point is
/// excluded. The harness performs no app-group reads or system mutations.
@main
struct WidgetRenderHarnessMain {
    @MainActor
    static func main() throws {
        _ = NSApplication.shared

        let root = URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath,
            isDirectory: true
        )
        let outputDirectory = root.appendingPathComponent(
            "Docs/screenshots",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )

        for scenario in WidgetRenderScenario.allCases {
            try render(
                scenario,
                to: outputDirectory.appendingPathComponent(scenario.filename)
            )
            print("wrote \(scenario.filename)")
        }
    }

    @MainActor
    private static func render(
        _ scenario: WidgetRenderScenario,
        to url: URL
    ) throws {
        let content = LidlessWidgetView(
            entry: scenario.entry,
            renderFamily: scenario.family
        )
        .padding(16)
        .frame(width: scenario.size.width, height: scenario.size.height)
        .background(Color(red: 0.055, green: 0.059, blue: 0.071))
        .environment(\.colorScheme, .dark)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

        let renderer = ImageRenderer(content: content)
        renderer.proposedSize = ProposedViewSize(scenario.size)
        renderer.scale = 2

        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try png.write(to: url, options: .atomic)
    }
}
