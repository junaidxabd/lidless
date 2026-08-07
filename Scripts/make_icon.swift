#!/usr/bin/env swift
//
// make_icon.swift — renders the Lidless dark safety-instrument app icon.
//
// Usage:
//   swift Scripts/make_icon.swift [appicon-directory] [contact-sheet.png]
//
// The mark is deliberately rectilinear: a Mac lid, its clamshell seam, and a
// small blue wake notch. It uses flat sRGB colors so every shipping size is
// deterministic and remains readable without decorative lighting effects.

import AppKit
import CoreGraphics
import Foundation

private let designSize: CGFloat = 1024

private enum IconPalette {
    static let plate = srgb(0x10141B)
    static let plateBorder = srgb(0x293140)
    static let device = srgb(0x171C26)
    static let deviceBorder = srgb(0x778296)
    static let display = srgb(0x0B0E14)
    static let displayBorder = srgb(0x343D4C)
    static let base = srgb(0x667184)
    static let seam = srgb(0xBAC2CE)
    static let wake = srgb(0x3B8CFF)
    static let contactCanvas = srgb(0x080A0F)
    static let contactLabel = srgb(0xD7DCE5)
}

private struct IconVariant {
    let filename: String
    let pixels: Int
}

private let variants = [
    IconVariant(filename: "icon_16x16.png", pixels: 16),
    IconVariant(filename: "icon_16x16@2x.png", pixels: 32),
    IconVariant(filename: "icon_32x32.png", pixels: 32),
    IconVariant(filename: "icon_32x32@2x.png", pixels: 64),
    IconVariant(filename: "icon_128x128.png", pixels: 128),
    IconVariant(filename: "icon_128x128@2x.png", pixels: 256),
    IconVariant(filename: "icon_256x256.png", pixels: 256),
    IconVariant(filename: "icon_256x256@2x.png", pixels: 512),
    IconVariant(filename: "icon_512x512.png", pixels: 512),
    IconVariant(filename: "icon_512x512@2x.png", pixels: 1024),
]

private func srgb(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(
        red: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

private func makeContext(width: Int, height: Int) -> CGContext? {
    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
    return CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )
}

private func fillRoundedRect(
    _ rect: CGRect,
    radius: CGFloat,
    color: CGColor,
    in context: CGContext
) {
    context.addPath(
        CGPath(
            roundedRect: rect,
            cornerWidth: radius,
            cornerHeight: radius,
            transform: nil
        )
    )
    context.setFillColor(color)
    context.fillPath()
}

private func strokeRoundedRect(
    _ rect: CGRect,
    radius: CGFloat,
    color: CGColor,
    width: CGFloat,
    in context: CGContext
) {
    context.addPath(
        CGPath(
            roundedRect: rect,
            cornerWidth: radius,
            cornerHeight: radius,
            transform: nil
        )
    )
    context.setStrokeColor(color)
    context.setLineWidth(width)
    context.strokePath()
}

/// Draws the uninterrupted clamshell boundary. It is the dominant proof mark
/// at menu-bar scale, so it uses a single flat stroke with rounded endpoints.
private func drawLidSeam(in context: CGContext) {
    context.setStrokeColor(IconPalette.seam)
    context.setLineWidth(22)
    context.setLineCap(.round)
    context.move(to: CGPoint(x: 258, y: 346))
    context.addLine(to: CGPoint(x: 766, y: 346))
    context.strokePath()
}

/// Draws the small blue status notch centered on the physical lid boundary.
private func drawWakeNotch(in context: CGContext) {
    fillRoundedRect(
        CGRect(x: 474, y: 327, width: 76, height: 22),
        radius: 11,
        color: IconPalette.wake,
        in: context
    )
}

private func drawIcon(in context: CGContext) {
    let plate = CGRect(x: 100, y: 100, width: 824, height: 824)
    fillRoundedRect(plate, radius: 185, color: IconPalette.plate, in: context)
    strokeRoundedRect(
        plate.insetBy(dx: 3, dy: 3),
        radius: 182,
        color: IconPalette.plateBorder,
        width: 6,
        in: context
    )

    let lid = CGRect(x: 232, y: 350, width: 560, height: 390)
    fillRoundedRect(lid, radius: 58, color: IconPalette.device, in: context)
    strokeRoundedRect(
        lid.insetBy(dx: 8, dy: 8),
        radius: 50,
        color: IconPalette.deviceBorder,
        width: 16,
        in: context
    )

    let display = CGRect(x: 282, y: 414, width: 460, height: 262)
    fillRoundedRect(display, radius: 27, color: IconPalette.display, in: context)
    strokeRoundedRect(
        display,
        radius: 27,
        color: IconPalette.displayBorder,
        width: 8,
        in: context
    )

    let base = CGMutablePath()
    base.move(to: CGPoint(x: 220, y: 320))
    base.addLine(to: CGPoint(x: 804, y: 320))
    base.addLine(to: CGPoint(x: 752, y: 278))
    base.addLine(to: CGPoint(x: 272, y: 278))
    base.closeSubpath()
    context.addPath(base)
    context.setFillColor(IconPalette.base)
    context.fillPath()

    drawLidSeam(in: context)
    drawWakeNotch(in: context)
}

private func renderIcon(pixels: Int) -> CGImage? {
    guard let context = makeContext(width: pixels, height: pixels) else { return nil }
    context.setShouldAntialias(true)
    context.interpolationQuality = .high
    let scale = CGFloat(pixels) / designSize
    context.scaleBy(x: scale, y: scale)
    drawIcon(in: context)
    return context.makeImage()
}

private func pngData(for image: CGImage) -> Data? {
    NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
}

private func writeIconSet(to directory: URL) throws {
    try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
    )

    for variant in variants {
        guard let image = renderIcon(pixels: variant.pixels),
              let data = pngData(for: image) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try data.write(to: directory.appendingPathComponent(variant.filename), options: .atomic)
        print("wrote \(variant.filename) (\(variant.pixels) px)")
    }
}

private func drawContactLabel(_ text: String, at point: CGPoint) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 19, weight: .medium),
        .foregroundColor: NSColor(cgColor: IconPalette.contactLabel) ?? .white,
    ]
    NSAttributedString(string: text, attributes: attributes).draw(at: point)
}

private func writeContactSheet(to url: URL) throws {
    let width = 1280
    let height = 760
    guard let context = makeContext(width: width, height: height) else {
        throw CocoaError(.fileWriteUnknown)
    }
    context.setFillColor(IconPalette.contactCanvas)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))

    let priorContext = NSGraphicsContext.current
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    defer { NSGraphicsContext.current = priorContext }

    let samples: [(pixels: Int, display: CGFloat, origin: CGPoint)] = [
        (1024, 420, CGPoint(x: 70, y: 230)),
        (256, 240, CGPoint(x: 555, y: 350)),
        (64, 144, CGPoint(x: 855, y: 420)),
        (32, 112, CGPoint(x: 1045, y: 436)),
        (16, 80, CGPoint(x: 1080, y: 230)),
    ]

    for sample in samples {
        guard let image = renderIcon(pixels: sample.pixels) else { continue }
        context.interpolationQuality = sample.pixels <= 64 ? .none : .high
        context.draw(
            image,
            in: CGRect(
                x: sample.origin.x,
                y: sample.origin.y,
                width: sample.display,
                height: sample.display
            )
        )
        drawContactLabel(
            "\(sample.pixels) px",
            at: CGPoint(x: sample.origin.x, y: sample.origin.y - 34)
        )
    }

    drawContactLabel("Lidless — dark safety instrument", at: CGPoint(x: 70, y: 690))

    guard let image = context.makeImage(), let data = pngData(for: image) else {
        throw CocoaError(.fileWriteUnknown)
    }
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try data.write(to: url, options: .atomic)
    print("wrote \(url.lastPathComponent)")
}

let scriptURL = URL(fileURLWithPath: #filePath)
let repositoryRoot = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let defaultIconDirectory = repositoryRoot
    .appendingPathComponent("App/Resources/Assets.xcassets/AppIcon.appiconset")
let iconDirectory = CommandLine.arguments.dropFirst().first
    .map { URL(fileURLWithPath: $0) }
    ?? defaultIconDirectory

do {
    try writeIconSet(to: iconDirectory)
    if CommandLine.arguments.count > 2 {
        try writeContactSheet(to: URL(fileURLWithPath: CommandLine.arguments[2]))
    }
} catch {
    fputs("error: \(error.localizedDescription)\n", stderr)
    exit(1)
}
