//
//  StopTypingMenuBarMark.swift
//  wispr
//
//  Programmatic "ST" lettermark for the menu bar status item (Stitch colors).
//

import AppKit

/// Renders the Stop Typing menu bar monogram at any backing scale.
enum StopTypingMenuBarMark {

    private static let baseDimension: CGFloat = 18
    private static let baseFontSize: CGFloat = 8.5
    private static let baseCornerRadius: CGFloat = 4
    private static let baseInset: CGFloat = 1

    /// Menu bar status image: full-color lettermark, or monochrome template when `template` is true.
    static func image(
        for state: AppStateType,
        template: Bool,
        accessibilityDescription: String?
    ) -> NSImage {
        let image = NSImage(size: NSSize(width: baseDimension, height: baseDimension), flipped: false) { dst in
            let scale = dst.width / baseDimension
            if template {
                drawTemplate(in: dst, scale: scale)
            } else {
                drawColored(in: dst, state: state, scale: scale)
            }
            return true
        }
        image.isTemplate = template
        image.accessibilityDescription = accessibilityDescription
        return image
    }

    private static func drawTemplate(in dst: NSRect, scale: CGFloat) {
        NSColor.clear.setFill()
        NSBezierPath(rect: dst).fill()

        let fontSize = baseFontSize * scale
        let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
        let text = "ST" as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black,
        ]
        let textSize = text.size(withAttributes: attrs)
        let origin = NSPoint(
            x: dst.minX + (dst.width - textSize.width) / 2,
            y: dst.minY + (dst.height - textSize.height) / 2
        )
        text.draw(at: origin, withAttributes: attrs)
    }

    private static func drawColored(in dst: NSRect, state: AppStateType, scale: CGFloat) {
        NSColor.clear.setFill()
        NSBezierPath(rect: dst).fill()

        let inset = baseInset * scale
        let corner = baseCornerRadius * scale
        let inner = dst.insetBy(dx: inset, dy: inset)
        let path = NSBezierPath(roundedRect: inner, xRadius: corner, yRadius: corner)

        StopTypingBrand.canvas.setFill()
        path.fill()

        let strokeColor = accentStroke(for: state)
        strokeColor.setStroke()
        path.lineWidth = max(1, scale)
        path.stroke()

        let fontSize = baseFontSize * scale
        let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
        let text = "ST" as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: StopTypingBrand.onSurface,
        ]
        let textSize = text.size(withAttributes: attrs)
        let origin = NSPoint(
            x: dst.minX + (dst.width - textSize.width) / 2,
            y: dst.minY + (dst.height - textSize.height) / 2
        )
        text.draw(at: origin, withAttributes: attrs)
    }

    private static func accentStroke(for state: AppStateType) -> NSColor {
        switch state {
        case .idle:
            return StopTypingBrand.primary
        case .recording:
            return StopTypingBrand.secondary
        case .loading, .processing:
            return StopTypingBrand.primaryContainer
        case .error:
            return .systemRed
        }
    }
}
