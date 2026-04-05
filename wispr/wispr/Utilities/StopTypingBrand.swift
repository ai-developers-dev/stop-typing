//
//  StopTypingBrand.swift
//  wispr
//
//  Obsidian Flux / Stitch palette tokens for menu bar branding.
//

import AppKit

/// Brand colors from the Stitch design spec (`obsidian_flux/DESIGN.md`).
enum StopTypingBrand {

    private static func srgb(_ rgb: UInt32, alpha: CGFloat = 1) -> NSColor {
        NSColor(
            srgbRed: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: alpha
        )
    }

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
