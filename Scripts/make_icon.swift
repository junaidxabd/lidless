#!/usr/bin/env swift
//
//  make_icon.swift — renders the Lidless macOS app icon offscreen.
//
//  Usage:   swift Scripts/make_icon.swift [output.png]
//           (default output: icon_1024.png in the current directory)
//
//  Produces a 1024x1024 master PNG following Apple's macOS Big Sur+ icon
//  grid: transparent canvas, centered 824x824 rounded-rect plate, and a
//  minimal open-eye glyph — the lidless eye that never sleeps.
//
//  AppKit + CoreGraphics only. No external dependencies, no SF Symbols;
//  the eye is drawn entirely with NSBezierPath.

import AppKit
import CoreGraphics
import Foundation

// MARK: - Helpers

/// NSColor from a 0xRRGGBB hex value, in sRGB.
func srgb(_ hex: UInt32, alpha: CGFloat = 1.0) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: alpha)
}

/// Angle in degrees of the vector from `center` to `point` (unflipped coords).
func angleDeg(from center: CGPoint, to point: CGPoint) -> CGFloat {
    atan2(point.y - center.y, point.x - center.x) * 180.0 / .pi
}

// MARK: - Canvas (1024 x 1024 px, transparent, sRGB)

let canvas: CGFloat = 1024

guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
      let cg = CGContext(data: nil,
                         width: Int(canvas), height: Int(canvas),
                         bitsPerComponent: 8, bytesPerRow: 0,
                         space: colorSpace,
                         bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
else {
    fputs("error: could not create CGContext\n", stderr)
    exit(1)
}
cg.setShouldAntialias(true)
cg.interpolationQuality = .high

let previousContext = NSGraphicsContext.current
NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: false)

// MARK: - Plate: Big Sur rounded rect, 824 x 824, corner radius ~185

let plateSize: CGFloat = 824
let plateOrigin = (canvas - plateSize) / 2.0 // 100
let plateRect = NSRect(x: plateOrigin, y: plateOrigin, width: plateSize, height: plateSize)
let cornerRadius: CGFloat = 185
let platePath = NSBezierPath(roundedRect: plateRect, xRadius: cornerRadius, yRadius: cornerRadius)

// Vertical gradient: deep indigo (#1B1E3C) at top -> near-black blue (#0B0C1E)
// at bottom. With angle 90 the gradient's first color sits at the bottom edge.
NSGradient(starting: srgb(0x0B0C1E), ending: srgb(0x1B1E3C))?
    .draw(in: platePath, angle: 90)

// Faint inner highlight along the top edge and a very subtle darker bottom
// edge, both clipped to the plate for depth.
cg.saveGState()
platePath.addClip()

let white = { (a: CGFloat) in NSColor(srgbRed: 1, green: 1, blue: 1, alpha: a) }
let black = { (a: CGFloat) in NSColor(srgbRed: 0, green: 0, blue: 0, alpha: a) }

// Top highlight: fades downward from the inside of the top edge.
NSGradient(starting: white(0.10), ending: white(0.0))?
    .draw(in: NSRect(x: plateRect.minX, y: plateRect.maxY - 110,
                     width: plateRect.width, height: 110),
          angle: -90)

// Bottom shade: fades upward from the inside of the bottom edge.
NSGradient(starting: black(0.20), ending: black(0.0))?
    .draw(in: NSRect(x: plateRect.minX, y: plateRect.minY,
                     width: plateRect.width, height: 95),
          angle: 90)
cg.restoreGState()

// Hairline inner border for crisp edge definition (very subtle).
let borderPath = NSBezierPath(roundedRect: plateRect.insetBy(dx: 1, dy: 1),
                              xRadius: cornerRadius - 1, yRadius: cornerRadius - 1)
borderPath.lineWidth = 2
white(0.06).setStroke()
borderPath.stroke()

// MARK: - Eye glyph geometry
//
// Almond/lens outline built from two symmetric circular arcs that meet at the
// eye corners. For a chord of half-width w and arc height (sagitta) h, the
// circle radius is R = (w^2 + h^2) / (2h).

let eyeCenter = CGPoint(x: canvas / 2, y: 492) // nudged slightly below center to balance the rays above
let eyeHalfWidth: CGFloat = 250                // lens is 500 pt wide
let lidSagitta: CGFloat = 150                  // lens opening is 300 pt tall
let lidStroke: CGFloat = 34

let lidRadius = (eyeHalfWidth * eyeHalfWidth + lidSagitta * lidSagitta) / (2 * lidSagitta)
let upperLidCenter = CGPoint(x: eyeCenter.x, y: eyeCenter.y - (lidRadius - lidSagitta))
let lowerLidCenter = CGPoint(x: eyeCenter.x, y: eyeCenter.y + (lidRadius - lidSagitta))
let leftCorner = CGPoint(x: eyeCenter.x - eyeHalfWidth, y: eyeCenter.y)
let rightCorner = CGPoint(x: eyeCenter.x + eyeHalfWidth, y: eyeCenter.y)

// MARK: - "Awake" rays (drawn first so the lid stroke stays on top)
//
// Three short rounded strokes fanned above the eye at -45 / 0 / +45 degrees
// from vertical, radiating from the upper lid's arc center so each sits at an
// even gap above the lid curve. Low-opacity white; calm, not cartoonish.

let rayGap: CGFloat = 36
let rayLength: CGFloat = 60
let rayWidth: CGFloat = 18
let rayInnerRadius = lidRadius + lidStroke / 2 + rayGap

for degrees: CGFloat in [45, 90, 135] {
    let radians = degrees * .pi / 180
    let dir = CGPoint(x: cos(radians), y: sin(radians))
    let ray = NSBezierPath()
    ray.move(to: NSPoint(x: upperLidCenter.x + dir.x * rayInnerRadius,
                         y: upperLidCenter.y + dir.y * rayInnerRadius))
    ray.line(to: NSPoint(x: upperLidCenter.x + dir.x * (rayInnerRadius + rayLength),
                         y: upperLidCenter.y + dir.y * (rayInnerRadius + rayLength)))
    ray.lineWidth = rayWidth
    ray.lineCapStyle = .round
    white(0.30).setStroke()
    ray.stroke()
}

// MARK: - Iris: soft cyan-to-white radial gradient, plus pupil highlight

let irisRadius: CGFloat = 110
let irisPath = NSBezierPath(ovalIn: NSRect(x: eyeCenter.x - irisRadius,
                                           y: eyeCenter.y - irisRadius,
                                           width: irisRadius * 2,
                                           height: irisRadius * 2))
let irisLocations: [CGFloat] = [0.0, 0.55, 1.0]
NSGradient(colors: [srgb(0x3EC6F0), srgb(0xA5E8FB), srgb(0xF2FDFF)],
           atLocations: irisLocations,
           colorSpace: .sRGB)?
    .draw(in: irisPath, relativeCenterPosition: NSPoint(x: -0.18, y: 0.22))

// Small offset pupil-highlight dot (upper-left, toward the light).
let dotRadius: CGFloat = 25
let dotCenter = CGPoint(x: eyeCenter.x - 40, y: eyeCenter.y + 42)
white(0.95).setFill()
NSBezierPath(ovalIn: NSRect(x: dotCenter.x - dotRadius, y: dotCenter.y - dotRadius,
                            width: dotRadius * 2, height: dotRadius * 2)).fill()

// MARK: - Lens outline: two symmetric arcs, stroked white with rounded caps

let lens = NSBezierPath()
lens.appendArc(withCenter: upperLidCenter, radius: lidRadius,
               startAngle: angleDeg(from: upperLidCenter, to: leftCorner),
               endAngle: angleDeg(from: upperLidCenter, to: rightCorner),
               clockwise: true) // sweeps over the top (through 90 degrees)
lens.appendArc(withCenter: lowerLidCenter, radius: lidRadius,
               startAngle: angleDeg(from: lowerLidCenter, to: rightCorner),
               endAngle: angleDeg(from: lowerLidCenter, to: leftCorner),
               clockwise: true) // sweeps under the bottom (through -90 degrees)
lens.close()
lens.lineWidth = lidStroke
lens.lineCapStyle = .round
lens.lineJoinStyle = .round
srgb(0xFFFFFF).setStroke()
lens.stroke()

// MARK: - Export PNG

NSGraphicsContext.current = previousContext

guard let cgImage = cg.makeImage() else {
    fputs("error: could not create CGImage\n", stderr)
    exit(1)
}
let rep = NSBitmapImageRep(cgImage: cgImage)
rep.size = NSSize(width: canvas, height: canvas) // 72 dpi
guard let png = rep.representation(using: .png, properties: [:]) else {
    fputs("error: could not encode PNG\n", stderr)
    exit(1)
}

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
let outputURL = URL(fileURLWithPath: outputPath)
do {
    try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(),
                                            withIntermediateDirectories: true)
    try png.write(to: outputURL)
} catch {
    fputs("error: \(error.localizedDescription)\n", stderr)
    exit(1)
}
print("wrote \(outputURL.path) (\(Int(canvas))x\(Int(canvas)))")
