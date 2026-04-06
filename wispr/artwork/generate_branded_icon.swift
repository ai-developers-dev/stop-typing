#!/usr/bin/env swift
/// Generates Stop Typing branded "ST" app icon matching the menu bar lettermark style.
///
/// Usage: swift artwork/generate_branded_icon.swift
///
/// Output: wispr/Assets.xcassets/AppIcon.appiconset/ (PNGs + Contents.json)

import AppKit
import Foundation

// MARK: - Configuration

let scriptDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
let projectRoot = URL(fileURLWithPath: scriptDir).deletingLastPathComponent().path
let outputDir = "\(projectRoot)/wispr/Assets.xcassets/AppIcon.appiconset"

let iconSizes: [(size: String, scale: String, pixels: Int)] = [
    ("16x16",   "1x",  16),
    ("16x16",   "2x",  32),
    ("32x32",   "1x",  32),
    ("32x32",   "2x",  64),
    ("128x128", "1x",  128),
    ("128x128", "2x",  256),
    ("256x256", "1x",  256),
    ("256x256", "2x",  512),
    ("512x512", "1x",  512),
    ("512x512", "2x",  1024),
]

// MARK: - Brand Colors (matching StopTypingBrand)

func color(_ hex: UInt32) -> NSColor {
    let r = CGFloat((hex >> 16) & 0xFF) / 255.0
    let g = CGFloat((hex >> 8) & 0xFF) / 255.0
    let b = CGFloat(hex & 0xFF) / 255.0
    return NSColor(red: r, green: g, blue: b, alpha: 1.0)
}

let canvas    = color(0x0B0E11)
let onSurface = color(0xF8F9FE)
let primary   = color(0x69DAFF)

// MARK: - Icon Rendering (matches StopTypingMenuBarMark style)

func renderIcon(pixelSize: Int) -> NSBitmapImageRep? {
    let size = CGFloat(pixelSize)
    let rect = NSRect(x: 0, y: 0, width: size, height: size)

    guard let bitmapRep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { return nil }

    NSGraphicsContext.saveGraphicsState()
    guard let context = NSGraphicsContext(bitmapImageRep: bitmapRep) else {
        NSGraphicsContext.restoreGraphicsState()
        return nil
    }
    NSGraphicsContext.current = context
    context.cgContext.clear(rect)

    // 1. Rounded rect background (same style as menu bar mark)
    let cornerRadius = size * 0.2237
    let inset = size * 0.04
    let bgRect = rect.insetBy(dx: inset, dy: inset)
    let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: cornerRadius, yRadius: cornerRadius)

    canvas.setFill()
    bgPath.fill()

    // 2. Subtle border stroke
    primary.withAlphaComponent(0.35).setStroke()
    bgPath.lineWidth = max(1, size * 0.006)
    bgPath.stroke()

    // 3. "ST" text — centered, matching menu bar approach
    let fontSize = size * 0.42
    let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
    let text = "ST" as NSString
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: onSurface,
    ]
    let textSize = text.size(withAttributes: attrs)
    let origin = NSPoint(
        x: bgRect.minX + (bgRect.width - textSize.width) / 2,
        y: bgRect.minY + (bgRect.height - textSize.height) / 2
    )
    text.draw(at: origin, withAttributes: attrs)

    NSGraphicsContext.restoreGraphicsState()
    return bitmapRep
}

// MARK: - Generate Icons

try FileManager.default.createDirectory(
    atPath: outputDir,
    withIntermediateDirectories: true,
    attributes: nil
)

var contentsImages: [[String: String]] = []

for icon in iconSizes {
    let filename = "AppIcon-\(icon.size)@\(icon.scale).png"
    let filePath = "\(outputDir)/\(filename)"

    guard let bitmapRep = renderIcon(pixelSize: icon.pixels) else {
        print("Error: Failed to render \(filename)")
        exit(1)
    }

    guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
        print("Error: Failed to create PNG for \(filename)")
        exit(1)
    }

    try pngData.write(to: URL(fileURLWithPath: filePath))
    print("  ✓ \(filename) (\(icon.size) @\(icon.scale))")

    contentsImages.append([
        "filename": filename,
        "idiom": "mac",
        "scale": icon.scale,
        "size": icon.size,
    ])
}

// MARK: - Write Contents.json

let contentsJSON: [String: Any] = [
    "images": contentsImages,
    "info": [
        "author": "xcode",
        "version": 1,
    ] as [String: Any],
]

let jsonData = try JSONSerialization.data(withJSONObject: contentsJSON, options: [.prettyPrinted, .sortedKeys])
let contentsPath = "\(outputDir)/Contents.json"
try jsonData.write(to: URL(fileURLWithPath: contentsPath))

print("\n✓ Generated \(iconSizes.count) icons + Contents.json in \(outputDir)")
