//
//  StopTypingMenuRowView.swift
//  wispr
//
//  Custom NSMenuItem content (Phase 2 branding). Per Apple, items with a `view`
//  do not draw title/image/state — this view owns presentation; key equivalents
//  and type-select still use NSMenuItem.title and keyEquivalent.
//  https://developer.apple.com/documentation/appkit/nsmenuitem/view
//

import AppKit

/// A single menu row: optional SF Symbol, title, optional trailing text (shortcut), optional checkmark.
@MainActor
final class StopTypingMenuRowView: NSView {

    weak var menuItem: NSMenuItem?

    /// Set in `configure` for unit tests (Increase Contrast template symbols).
    private(set) var isUsingTemplateSymbol = false

    private let stack = NSStackView()
    private let imageView = NSImageView()
    private let checkmarkView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let trailingLabel = NSTextField(labelWithString: "")

    private var trackingArea: NSTrackingArea?
    private var highlightTimer: Timer?
    private var mouseInside = false

    private var keyboardHighlighted = false

    static let rowWidth: CGFloat = 280
    static let rowHeight: CGFloat = 26

    override var intrinsicContentSize: NSSize {
        NSSize(width: Self.rowWidth, height: Self.rowHeight)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.masksToBounds = true

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyDown
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 18),
            imageView.heightAnchor.constraint(equalToConstant: 18),
        ])

        checkmarkView.translatesAutoresizingMaskIntoConstraints = false
        checkmarkView.imageScaling = .scaleProportionallyDown
        checkmarkView.isHidden = true
        NSLayoutConstraint.activate([
            checkmarkView.widthAnchor.constraint(equalToConstant: 14),
            checkmarkView.heightAnchor.constraint(equalToConstant: 14),
        ])

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        trailingLabel.translatesAutoresizingMaskIntoConstraints = false
        trailingLabel.alignment = .right
        trailingLabel.lineBreakMode = .byTruncatingTail
        trailingLabel.maximumNumberOfLines = 1
        trailingLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 2, left: 12, bottom: 2, right: 12)
        stack.addArrangedSubview(imageView)
        stack.addArrangedSubview(checkmarkView)
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(trailingLabel)

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        updateHighlightAppearance()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(
        menuItem: NSMenuItem,
        symbolImage: NSImage?,
        title: String,
        trailingText: String?,
        checkmarkSelected: Bool,
        titleColor: NSColor,
        trailingColor: NSColor,
        templateSymbol: Bool
    ) {
        self.menuItem = menuItem
        isUsingTemplateSymbol = templateSymbol

        if let img = symbolImage {
            imageView.image = img
            imageView.isHidden = false
        } else {
            imageView.image = nil
            imageView.isHidden = true
        }

        if checkmarkSelected {
            let mark = NSImage(
                systemSymbolName: SFSymbols.checkmarkPlain,
                accessibilityDescription: "Selected"
            )
            mark?.isTemplate = true
            checkmarkView.image = mark
            checkmarkView.contentTintColor = templateSymbol ? .labelColor : StopTypingBrand.primary
            checkmarkView.isHidden = false
        } else {
            checkmarkView.image = nil
            checkmarkView.contentTintColor = nil
            checkmarkView.isHidden = true
        }

        titleLabel.stringValue = title
        titleLabel.textColor = titleColor
        titleLabel.font = menuItem.menu?.font ?? NSFont.systemFont(ofSize: 13, weight: .medium)

        if let t = trailingText, !t.isEmpty {
            trailingLabel.stringValue = t
            trailingLabel.textColor = trailingColor
            trailingLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
            trailingLabel.isHidden = false
        } else {
            trailingLabel.stringValue = ""
            trailingLabel.isHidden = true
        }

        toolTip = menuItem.toolTip
        setAccessibilityElement(true)
        setAccessibilityLabel(trailingText.map { "\(title), \($0)" } ?? title)
        setAccessibilityRole(.button)
        setAccessibilityTitle(title)

        updateHighlightAppearance()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        highlightTimer?.invalidate()
        highlightTimer = nil
        guard window != nil else { return }
        highlightTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.pollKeyboardHighlight()
            }
        }
        if let t = highlightTimer {
            RunLoop.main.add(t, forMode: .common)
        }
    }

    private func pollKeyboardHighlight() {
        guard let item = menuItem, let m = item.menu else { return }
        let on = m.highlightedItem === item
        if on != keyboardHighlighted {
            keyboardHighlighted = on
            updateHighlightAppearance()
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let ta = trackingArea {
            removeTrackingArea(ta)
        }
        let ta = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        trackingArea = ta
        addTrackingArea(ta)
    }

    override func mouseEntered(with event: NSEvent) {
        mouseInside = true
        updateHighlightAppearance()
    }

    override func mouseExited(with event: NSEvent) {
        mouseInside = false
        updateHighlightAppearance()
    }

    override func mouseDown(with event: NSEvent) {
        guard let item = menuItem, item.isEnabled, let m = item.menu else { return }
        let idx = m.index(of: item)
        guard idx >= 0 else { return }
        m.performActionForItem(at: idx)
    }

    private var showsHighlightBackground: Bool {
        guard let item = menuItem, item.isEnabled else { return false }
        return mouseInside || keyboardHighlighted
    }

    private func updateHighlightAppearance() {
        if showsHighlightBackground {
            layer?.backgroundColor = StopTypingBrand.primary.withAlphaComponent(0.22).cgColor
        } else {
            layer?.backgroundColor = NSColor.clear.cgColor
        }
    }
}
