import AppKit
import Foundation

private struct Sheet {
    let filename: String
    let width: Int
    let height: Int
    let columns: Int
    let images: [String]
}

private let sheets = [
    Sheet(
        filename: "menu-contact-sheet.png",
        width: 1_290,
        height: 2_500,
        columns: 3,
        images: [
            "menu-verified-normal.png",
            "menu-no-battery.png",
            "menu-charging.png",
            "menu-verifying-arm.png",
            "menu-verified-armed.png",
            "menu-restoring.png",
            "menu-outside-override.png",
            "menu-unknown.png",
            "menu-helper-setup.png",
            "menu-long-error.png",
            "menu-confirmation-ok.png",
            "menu-confirmation-low-battery.png",
            "menu-confirmation-floor-refusal.png",
            "menu-confirmation-thermal-refusal.png",
        ]
    ),
    Sheet(
        filename: "window-contact-sheet.png",
        width: 1_500,
        height: 2_200,
        columns: 3,
        images: [
            "window-minimum-verified-normal.png",
            "window-default-verified-normal.png",
            "window-wide-verified-normal.png",
            "window-minimum-no-battery.png",
            "window-default-no-battery.png",
            "window-wide-no-battery.png",
            "window-minimum-charging.png",
            "window-default-charging.png",
            "window-wide-charging.png",
            "window-minimum-verified-armed.png",
            "window-default-verified-armed.png",
            "window-wide-verified-armed.png",
            "window-minimum-outside-override.png",
            "window-default-outside-override.png",
            "window-wide-outside-override.png",
            "window-minimum-unknown.png",
            "window-default-unknown.png",
            "window-wide-unknown.png",
        ]
    ),
    Sheet(
        filename: "window-transition-contact-sheet.png",
        width: 1_500,
        height: 2_200,
        columns: 3,
        images: [
            "window-minimum-verifying-arm.png",
            "window-default-verifying-arm.png",
            "window-wide-verifying-arm.png",
            "window-minimum-restoring.png",
            "window-default-restoring.png",
            "window-wide-restoring.png",
            "window-minimum-confirmation-ok.png",
            "window-default-confirmation-ok.png",
            "window-wide-confirmation-ok.png",
            "window-minimum-confirmation-low-battery.png",
            "window-default-confirmation-low-battery.png",
            "window-wide-confirmation-low-battery.png",
            "window-minimum-confirmation-floor-refusal.png",
            "window-default-confirmation-floor-refusal.png",
            "window-wide-confirmation-floor-refusal.png",
            "window-minimum-confirmation-thermal-refusal.png",
            "window-default-confirmation-thermal-refusal.png",
            "window-wide-confirmation-thermal-refusal.png",
        ]
    ),
    Sheet(
        filename: "secondary-contact-sheet.png",
        width: 1_500,
        height: 1_850,
        columns: 3,
        images: [
            "secondary-cutoffs-default.png",
            "secondary-schedules-empty.png",
            "secondary-schedules-populated.png",
            "secondary-history-empty-minimum.png",
            "secondary-history-empty-default.png",
            "secondary-history-empty-wide.png",
            "secondary-history-selected-minimum.png",
            "secondary-history-selected-default.png",
            "secondary-history-selected-wide.png",
            "secondary-setup-simulated.png",
            "secondary-simulator-default.png",
            "secondary-simulator-charging.png",
            "secondary-simulator-no-battery.png",
        ]
    ),
    Sheet(
        filename: "onboarding-contact-sheet.png",
        width: 1_440,
        height: 430,
        columns: 4,
        images: [
            "onboarding-intro.png",
            "onboarding-helper.png",
            "onboarding-recovery.png",
            "onboarding-helper-failure.png",
        ]
    ),
    Sheet(
        filename: "accessibility-contact-sheet.png",
        width: 1_500,
        height: 1_200,
        columns: 2,
        images: [
            "accessibility-menu-long-error.png",
            "accessibility-window-minimum-confirmation.png",
            "accessibility-onboarding-recovery.png",
            "accessibility-schedule-editor.png",
        ]
    ),
    Sheet(
        filename: "widget-contact-sheet.png",
        width: 960,
        height: 540,
        columns: 2,
        images: [
            "widget-small-verified-normal.png",
            "widget-medium-verified-armed.png",
            "widget-small-stale-unknown.png",
            "widget-medium-empty.png",
        ]
    ),
]

private enum ContactSheetError: LocalizedError {
    case missingImage(String)
    case bitmapCreation
    case pngEncoding

    var errorDescription: String? {
        switch self {
        case .missingImage(let filename): "Missing screenshot: \(filename)"
        case .bitmapCreation: "Could not create contact-sheet bitmap"
        case .pngEncoding: "Could not encode contact-sheet PNG"
        }
    }
}

@main
struct ContactSheetMain {
    @MainActor
    static func main() throws {
        _ = NSApplication.shared
        let root = URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath,
            isDirectory: true
        )
        let screenshotDirectory = root.appendingPathComponent(
            "Docs/screenshots",
            isDirectory: true
        )

        for sheet in sheets {
            try render(sheet, in: screenshotDirectory)
            print("wrote \(sheet.filename)")
        }
    }

    @MainActor
    private static func render(_ sheet: Sheet, in directory: URL) throws {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: sheet.width,
            pixelsHigh: sheet.height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            throw ContactSheetError.bitmapCreation
        }

        let rows = Int(ceil(Double(sheet.images.count) / Double(sheet.columns)))
        let cellWidth = CGFloat(sheet.width) / CGFloat(sheet.columns)
        let cellHeight = CGFloat(sheet.height) / CGFloat(rows)
        let inset: CGFloat = 18
        let labelHeight: CGFloat = 38

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        NSColor(srgbRed: 0.025, green: 0.029, blue: 0.036, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: sheet.width, height: sheet.height).fill()

        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
            .foregroundColor: NSColor(srgbRed: 0.84, green: 0.87, blue: 0.92, alpha: 1),
        ]

        for (index, filename) in sheet.images.enumerated() {
            let column = index % sheet.columns
            let row = index / sheet.columns
            let originX = CGFloat(column) * cellWidth
            let originY = CGFloat(sheet.height) - CGFloat(row + 1) * cellHeight
            let imageURL = directory.appendingPathComponent(filename)
            guard let image = NSImage(contentsOf: imageURL),
                  image.size.width > 0,
                  image.size.height > 0 else {
                NSGraphicsContext.restoreGraphicsState()
                throw ContactSheetError.missingImage(filename)
            }

            let availableWidth = cellWidth - (2 * inset)
            let availableHeight = cellHeight - labelHeight - (2 * inset)
            let scale = min(
                availableWidth / image.size.width,
                availableHeight / image.size.height
            )
            let drawnSize = NSSize(
                width: floor(image.size.width * scale),
                height: floor(image.size.height * scale)
            )
            let imageRect = NSRect(
                x: originX + floor((cellWidth - drawnSize.width) / 2),
                y: originY + labelHeight + inset,
                width: drawnSize.width,
                height: drawnSize.height
            )
            image.draw(
                in: imageRect,
                from: .zero,
                operation: .sourceOver,
                fraction: 1,
                respectFlipped: false,
                hints: [.interpolation: NSImageInterpolation.high]
            )

            let labelRect = NSRect(
                x: originX + inset,
                y: originY + 5,
                width: availableWidth,
                height: labelHeight
            )
            (filename as NSString).draw(in: labelRect, withAttributes: labelAttributes)
        }

        NSGraphicsContext.restoreGraphicsState()
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            throw ContactSheetError.pngEncoding
        }
        try png.write(
            to: directory.appendingPathComponent(sheet.filename),
            options: .atomic
        )
    }
}
