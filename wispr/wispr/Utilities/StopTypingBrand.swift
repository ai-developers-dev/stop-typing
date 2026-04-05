//
//  StopTypingBrand.swift
//  wispr
//
//  Obsidian Flux / Stitch palette tokens for the Stop Typing brand.
//  NSColor constants for AppKit surfaces, plus SwiftUI Color accessors
//  and the full surface-hierarchy from DESIGN.md section 2.
//

import AppKit
import SwiftUI

/// Brand colors from the Stitch design spec (`obsidian_flux/DESIGN.md`).
enum StopTypingBrand {

    // MARK: - NSColor helpers

    private static func srgb(_ rgb: UInt32, alpha: CGFloat = 1) -> NSColor {
        NSColor(
            srgbRed: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: alpha
        )
    }

    // MARK: - Core palette (NSColor)

    /// Primary accent `#69DAFF`
    static let primary = srgb(0x69DAFF)

    /// Primary container / gradient end `#00CFFC`
    static let primaryContainer = srgb(0x00CFFC)

    /// Secondary LED accent `#00F4FE`
    static let secondary = srgb(0x00F4FE)

    /// Deep canvas `#0B0E11`
    static let canvas = srgb(0x0B0E11)

    /// On-surface text `#F8F9FE`
    static let onSurface = srgb(0xF8F9FE)

    // MARK: - Surface hierarchy (NSColor)

    /// Slightly darker than canvas, for inset areas `#080A0D`
    static let surfaceDim = srgb(0x080A0D)

    /// Secondary layer `#111519`
    static let surfaceContainerLow = srgb(0x111519)

    /// Elevated layer / card backgrounds `#1A1F25`
    static let surfaceContainer = srgb(0x1A1F25)

    /// Interactive cards, hover states `#232930`
    static let surfaceContainerHigh = srgb(0x232930)

    /// Secondary text / icons on dark surfaces `#A0A8B4`
    static let onSurfaceVariant = srgb(0xA0A8B4)

    // MARK: - SwiftUI Color accessors

    static var swiftPrimary: Color { Color(nsColor: primary) }
    static var swiftPrimaryContainer: Color { Color(nsColor: primaryContainer) }
    static var swiftSecondary: Color { Color(nsColor: secondary) }
    static var swiftCanvas: Color { Color(nsColor: canvas) }
    static var swiftOnSurface: Color { Color(nsColor: onSurface) }
    static var swiftSurfaceDim: Color { Color(nsColor: surfaceDim) }
    static var swiftSurfaceContainerLow: Color { Color(nsColor: surfaceContainerLow) }
    static var swiftSurfaceContainer: Color { Color(nsColor: surfaceContainer) }
    static var swiftSurfaceContainerHigh: Color { Color(nsColor: surfaceContainerHigh) }
    static var swiftOnSurfaceVariant: Color { Color(nsColor: onSurfaceVariant) }

    // MARK: - Menu bar palette

    /// Palette colors for menu bar SF Symbols (single-layer glyphs use the first entry).
    static func menuBarPaletteColors(for state: AppStateType) -> [NSColor] {
        switch state {
        case .loading, .processing:
            return [primaryContainer]
        case .idle:
            return [primary]
        case .recording:
            return [secondary]
        case .error:
            return [.systemRed]
        }
    }
}
