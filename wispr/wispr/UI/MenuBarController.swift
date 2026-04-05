//
//  MenuBarController.swift
//  wispr
//
//  Manages the NSStatusItem menu bar presence, ST lettermark icon, and dropdown menu.
//  Bridges to SwiftUI views for settings, model management, and language selection.
//  Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 14.2, 14.9, 16.7, 16.8
//

import AppKit
import SwiftUI
import Observation
import os

/// Manages the NSStatusItem in the macOS menu bar.
///
/// Creates the status item on init, sets a custom “ST” menu bar mark (brand-colored or template)
/// that reflects the current application state, and builds a dropdown menu with recording,
/// settings, model management, language selection, and quit actions.
///
/// ## Why AppKit? (Modernization blocker)
/// SwiftUI's `MenuBarExtra` doesn't support dynamic icon changes, submenus, or
/// target-action wiring needed here. `NSStatusItem` / `NSMenu` remain the only
/// viable API for a fully custom menu bar presence. Unblocked if Apple extends
/// `MenuBarExtra` with dynamic image binding and nested menu support.
///
/// **Validates Requirements**: 5.1 (NSStatusItem creation), 5.2 (icon state),
/// 5.3 (dropdown menu), 5.4 (start/stop recording), 5.5 (quit with cleanup),
/// 14.2 (menu bar icon), 14.9 (smooth icon transitions), 16.7 (language display),
/// 16.8 (language selection in menu)
@MainActor
final class MenuBarController {

    // MARK: - Properties

    /// The macOS menu bar status item.
    private let statusItem: NSStatusItem

    /// The dropdown menu displayed when the user clicks the status item.
    private let menu: NSMenu

    /// Exposed for unit tests (`wisprTests`).
    var menuForTesting: NSMenu { menu }

    /// Reference to the central state manager for wiring actions.
    private let stateManager: StateManager

    /// Reference to settings for language display.
    private let settingsStore: SettingsStore

    /// Theme engine for SF Symbol helpers.
    private let themeEngine: UIThemeEngine

    /// Hotkey monitor for settings view (suspend/resume during hotkey recording).
    private let hotkeyMonitor: HotkeyMonitor

    /// Audio engine for settings view.
    private let audioEngine: AudioEngine

    /// Transcription engine for settings and model management views.
    private let transcriptionEngine: any TranscriptionEngine

    /// Permission manager for settings view.
    private let permissionManager: PermissionManager

    /// Update checker for surfacing new versions.
    private let updateChecker: UpdateChecker

    /// Observation tracking for state changes.
    private var observationTask: Task<Void, Never>?

    /// Path where the CLI symlink is installed.
    private let cliSymlinkPath = "/usr/local/bin/wispr"

    /// Key used for the Core Animation pulse on the status button during processing.
    private static let processingAnimationKey = "wispr.processing.pulse"

    /// Retained reference to the settings window.
    private var settingsWindow: NSWindow?

    /// Retained reference to the model management window.
    private var modelManagementWindow: NSWindow?

    /// Retained reference to the CLI install window.
    private var cliInstallWindow: NSWindow?

    /// Menu delegate that refreshes dynamic items when the menu opens.
    private lazy var menuDelegate = MenuOpenDelegate(controller: self)

    // MARK: - Menu Items (retained for dynamic updates)

    private let recordingMenuItem = NSMenuItem()
    private let languageMenuItem = NSMenuItem()
    private let languageSubmenu = NSMenu()
    private let updateMenuItem = NSMenuItem()
    private let updateSeparator = NSMenuItem.separator()
    private let cliInstallSeparator = NSMenuItem.separator()
    private var cliInstallMenuItem: NSMenuItem?

    // MARK: - Initialization

    /// Creates the MenuBarController and sets up the status item, icon, and menu.
    ///
    /// - Parameters:
    ///   - stateManager: The central state coordinator.
    ///   - settingsStore: The persistent settings store.
    ///   - themeEngine: The UI theme engine for SF Symbol helpers.
    ///   - audioEngine: The audio engine (needed for SettingsView).
    ///   - whisperService: The transcription engine (needed for SettingsView and ModelManagementView).
    ///   - permissionManager: The permission manager (needed for SettingsView).
    init(
        stateManager: StateManager,
        settingsStore: SettingsStore,
        themeEngine: UIThemeEngine = .shared,
        hotkeyMonitor: HotkeyMonitor,
        audioEngine: AudioEngine,
        whisperService: any TranscriptionEngine,
        permissionManager: PermissionManager,
        updateChecker: UpdateChecker
    ) {
        self.stateManager = stateManager
        self.settingsStore = settingsStore
        self.themeEngine = themeEngine
        self.hotkeyMonitor = hotkeyMonitor
        self.audioEngine = audioEngine
        self.transcriptionEngine = whisperService
        self.permissionManager = permissionManager
        self.updateChecker = updateChecker

        // Requirement 5.1: Create NSStatusItem in the menu bar
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.menu = NSMenu()

        configureStatusButton()
        buildMenu()
        menu.delegate = menuDelegate
        refreshMenuBranding()
        startObservingState()
    }

    // MARK: - Status Button Configuration

    /// Configures the status item button with the initial icon (brand palette or template).
    ///
    /// Requirement 14.2: Image appears sharp at all Retina resolutions.
    /// Custom lettermark is drawn at each backing scale via `StopTypingMenuBarMark`.
    private func configureStatusButton() {
        guard let button = statusItem.button else { return }

        let image = makeStatusItemImage(
            appState: .idle,
            accessibilityDescription: "Stop Typing — Voice Dictation"
        )
        button.image = image
        button.toolTip = "Stop Typing — Voice Dictation"

        statusItem.menu = menu
    }

    /// Builds the menu bar status image: programmatic "ST" mark (Stitch colors), or template when Increase Contrast is on.
    private func makeStatusItemImage(
        appState: AppStateType,
        accessibilityDescription: String
    ) -> NSImage {
        StopTypingMenuBarMark.image(
            for: appState,
            template: themeEngine.increaseContrast,
            accessibilityDescription: accessibilityDescription
        )
    }

    // MARK: - Menu branding (Stop Typing / Stitch palette)

    /// Syncs menu appearance, typography, tinted SF Symbols, and optional attributed titles.
    ///
    /// Call when the menu opens and when observed settings/state change so Increase Contrast and related settings stay correct.
    /// Manual checks: light vs dark *menu bar* (menu panel stays dark), Reduce Transparency, VoiceOver (Phase 1 a11y pass).
    func refreshMenuBranding() {
        syncMenuChrome()
        syncMenuItemPaletteImages()
        applyLanguageSubmenuAttributedTitles()
        refreshUpdateMenuItemPresentation()
        updateRecordingMenuItem()
    }

    private func syncMenuChrome() {
        // Always use dark menu chrome for this status-item menu. Matching `isDarkMode` with `.aqua`
        // produced a light frosted panel while row text/icons use bright Stitch teals — very low contrast
        // on light wallpapers; `.darkAqua` keeps accents legible regardless of system appearance.
        let darkMenuAppearance = NSAppearance(named: .darkAqua)
        menu.appearance = darkMenuAppearance
        languageSubmenu.appearance = darkMenuAppearance
        let bodyFont = NSFont.systemFont(ofSize: 13, weight: .medium)
        menu.font = bodyFont
        languageSubmenu.font = bodyFont
    }

    /// SF Symbol for a menu row: brand palette, or template when Increase Contrast is enabled.
    private func menuPaletteImage(
        symbolName: String,
        accessibilityDescription: String,
        tint: NSColor
    ) -> NSImage? {
        guard let base = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: accessibilityDescription
        ) else { return nil }

        if themeEngine.increaseContrast {
            base.isTemplate = true
            return base
        }

        let config = NSImage.SymbolConfiguration(paletteColors: [tint])
        guard let configured = base.withSymbolConfiguration(config) else {
            base.isTemplate = true
            return base
        }
        configured.isTemplate = false
        return configured
    }

    private func menuBodyAttributes(accent: NSColor) -> [NSAttributedString.Key: Any] {
        let font = menu.font ?? NSFont.menuFont(ofSize: NSFont.systemFontSize)
        if themeEngine.increaseContrast {
            return [.font: font]
        }
        return [
            .font: font,
            .foregroundColor: accent,
        ]
    }

    private func setPlainMenuTitle(_ item: NSMenuItem, plain: String, accent: NSColor) {
        item.title = plain
        if themeEngine.increaseContrast {
            item.attributedTitle = nil
        } else {
            item.attributedTitle = NSAttributedString(string: plain, attributes: menuBodyAttributes(accent: accent))
        }
    }

    private func syncMenuItemPaletteImages() {
        languageMenuItem.image = menuPaletteImage(
            symbolName: themeEngine.actionSymbol(.language),
            accessibilityDescription: "Language",
            tint: StopTypingBrand.primary
        )
        setPlainMenuTitle(languageMenuItem, plain: languageDisplayTitle(), accent: StopTypingBrand.primary)

        for item in menu.items {
            guard let action = item.action else { continue }
            if action == #selector(MenuBarActionHandler.toggleRecording(_:)) {
                continue
            }
            if action == #selector(MenuBarActionHandler.openSettings(_:)) {
                item.image = menuPaletteImage(
                    symbolName: themeEngine.actionSymbol(.settings),
                    accessibilityDescription: "Settings",
                    tint: StopTypingBrand.primary
                )
                setPlainMenuTitle(item, plain: item.title, accent: StopTypingBrand.primary)
            } else if action == #selector(MenuBarActionHandler.openModelManagement(_:)) {
                item.image = menuPaletteImage(
                    symbolName: themeEngine.actionSymbol(.model),
                    accessibilityDescription: "Model Management",
                    tint: StopTypingBrand.primary
                )
                setPlainMenuTitle(item, plain: item.title, accent: StopTypingBrand.primary)
            } else if action == #selector(MenuBarActionHandler.openUpdateDownload(_:)) {
                item.image = menuPaletteImage(
                    symbolName: SFSymbols.download,
                    accessibilityDescription: "Update Available",
                    tint: StopTypingBrand.primaryContainer
                )
            } else if action == #selector(MenuBarActionHandler.showCLIInstallDialog(_:)) {
                item.image = menuPaletteImage(
                    symbolName: SFSymbols.terminal,
                    accessibilityDescription: "Install CLI",
                    tint: StopTypingBrand.primary
                )
                setPlainMenuTitle(item, plain: item.title, accent: StopTypingBrand.primary)
            } else if action == #selector(MenuBarActionHandler.quitApp(_:)) {
                item.image = menuPaletteImage(
                    symbolName: themeEngine.actionSymbol(.quit),
                    accessibilityDescription: "Quit",
                    tint: StopTypingBrand.secondary
                )
                setPlainMenuTitle(item, plain: item.title, accent: StopTypingBrand.secondary)
            }
        }
    }

    private func applyLanguageSubmenuAttributedTitles() {
        for item in languageSubmenu.items where !item.isSeparatorItem {
            setPlainMenuTitle(item, plain: item.title, accent: StopTypingBrand.primary)
        }
    }

    private func refreshUpdateMenuItemPresentation() {
        guard !updateMenuItem.isHidden else { return }
        let plain = updateMenuItem.title
        guard !plain.isEmpty else { return }
        setPlainMenuTitle(updateMenuItem, plain: plain, accent: StopTypingBrand.primaryContainer)
        updateMenuItem.image = menuPaletteImage(
            symbolName: SFSymbols.download,
            accessibilityDescription: "Update Available",
            tint: StopTypingBrand.primaryContainer
        )
    }

    // MARK: - Menu Construction

    /// Builds the dropdown menu with all required items.
    ///
    /// Requirement 5.3: Menu contains Start/Stop Recording, Settings,
    /// Model Management, Language Selection, and Quit.
    private func buildMenu() {
        menu.removeAllItems()

        // Start/Stop Recording
        updateRecordingMenuItem()
        menu.addItem(recordingMenuItem)

        menu.addItem(NSMenuItem.separator())

        // Language Selection
        languageMenuItem.title = languageDisplayTitle()
        languageMenuItem.submenu = languageSubmenu
        buildLanguageSubmenu()
        menu.addItem(languageMenuItem)

        menu.addItem(NSMenuItem.separator())

        // Settings
        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(MenuBarActionHandler.openSettings(_:)),
            keyEquivalent: ","
        )
        menu.addItem(settingsItem)

        // Model Management
        let modelItem = NSMenuItem(
            title: "Model Management…",
            action: #selector(MenuBarActionHandler.openModelManagement(_:)),
            keyEquivalent: ""
        )
        menu.addItem(modelItem)

        // Update Available (shown dynamically)
        updateMenuItem.title = ""
        updateMenuItem.action = #selector(MenuBarActionHandler.openUpdateDownload(_:))
        updateMenuItem.target = MenuBarActionHandler.shared
        updateMenuItem.isHidden = true
        updateSeparator.isHidden = true
        menu.addItem(updateSeparator)
        menu.addItem(updateMenuItem)

        refreshUpdateMenuItem()

        // Install CLI (hidden dynamically when installed)
        menu.addItem(cliInstallSeparator)
        let installCLIItem = NSMenuItem(
            title: "Install Command Line Tool\u{2026}",
            action: #selector(MenuBarActionHandler.showCLIInstallDialog(_:)),
            keyEquivalent: ""
        )
        menu.addItem(installCLIItem)
        cliInstallMenuItem = installCLIItem
        refreshCLIInstallMenuItem()

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(
            title: "Quit Stop Typing",
            action: #selector(MenuBarActionHandler.quitApp(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        // Set the shared action handler as the target for all items
        let handler = MenuBarActionHandler.shared
        handler.menuBarController = self
        for item in menu.items where item.action != nil {
            item.target = handler
        }
    }

    // MARK: - Recording Menu Item

    /// Updates the recording menu item title and action based on current state.
    private func updateRecordingMenuItem() {
        let isRecording = stateManager.appState == .recording
        let shortcut = KeyCodeMapping.shared.hotkeyDisplayString(
            keyCode: settingsStore.hotkeyKeyCode,
            modifiers: settingsStore.hotkeyModifiers
        )
        let label = isRecording ? "Stop Recording" : "Start Recording"
        let plain = "\(label)\t\(shortcut)"
        recordingMenuItem.title = plain
        recordingMenuItem.action = #selector(MenuBarActionHandler.toggleRecording(_:))
        recordingMenuItem.target = MenuBarActionHandler.shared

        let symbolName = isRecording
            ? themeEngine.menuBarSymbol(for: .recording)
            : themeEngine.menuBarSymbol(for: .idle)
        let tint = isRecording ? StopTypingBrand.secondary : StopTypingBrand.primary
        recordingMenuItem.image = menuPaletteImage(
            symbolName: symbolName,
            accessibilityDescription: isRecording ? "Stop Recording" : "Start Recording",
            tint: tint
        )
        if themeEngine.increaseContrast {
            recordingMenuItem.attributedTitle = nil
        } else {
            recordingMenuItem.attributedTitle = NSAttributedString(string: plain, attributes: menuBodyAttributes(accent: tint))
        }

        // Disable during processing
        recordingMenuItem.isEnabled = stateManager.appState != .processing
    }

    // MARK: - CLI Install Menu Item

    /// Hides the CLI install menu item once the symlink is in place.
    func refreshCLIInstallMenuItem() {
        let installed = isCLIInstalled()
        cliInstallMenuItem?.isHidden = installed
        cliInstallSeparator.isHidden = installed
    }

    // MARK: - Update Menu Item

    /// Refreshes the update menu item visibility and title based on `updateChecker.availableUpdate`.
    private func refreshUpdateMenuItem() {
        if let update = updateChecker.availableUpdate {
            Log.updateChecker.info("Menu item shown — update available: \(update.version)")
            updateMenuItem.title = "Update Available: \(update.version)"
            updateMenuItem.isHidden = false
            updateSeparator.isHidden = false
        } else {
            Log.updateChecker.debug("Menu item hidden — no update available")
            updateMenuItem.isHidden = true
            updateSeparator.isHidden = true
        }
    }

    /// Opens the download URL for the available update.
    func openUpdateDownload() {
        guard let update = updateChecker.availableUpdate else {
            Log.updateChecker.error("openUpdateDownload called but no update available")
            return
        }
        Log.updateChecker.info("User opening download URL: \(update.downloadURL.absoluteString)")
        NSWorkspace.shared.open(update.downloadURL)
    }

    // MARK: - Language Display

    /// Returns the display title for the language menu item.
    ///
    /// Requirement 16.7: Display current language or auto-detect indicator.
    private func languageDisplayTitle() -> String {
        switch settingsStore.languageMode {
        case .autoDetect:
            return "Language: Auto-Detect"
        case .specific(let code):
            return "Language: \(languageDisplayName(for: code))"
        case .pinned(let code):
            return "Language: \(languageDisplayName(for: code)) (Pinned)"
        }
    }

    /// Returns a human-readable name for a language code.
    private func languageDisplayName(for code: String) -> String {
        let locale = Locale.current
        return locale.localizedString(forLanguageCode: code)?.capitalized ?? code.uppercased()
    }

    // MARK: - Language Submenu

    /// Builds the language selection submenu.
    ///
    /// Requirement 16.8: Language selection control in the menu bar dropdown.
    private func buildLanguageSubmenu() {
        languageSubmenu.removeAllItems()

        // Auto-Detect option
        let autoItem = NSMenuItem(
            title: "Auto-Detect",
            action: #selector(MenuBarActionHandler.selectAutoDetect(_:)),
            keyEquivalent: ""
        )
        autoItem.target = MenuBarActionHandler.shared
        if settingsStore.languageMode.isAutoDetect {
            autoItem.state = .on
        }
        languageSubmenu.addItem(autoItem)

        languageSubmenu.addItem(NSMenuItem.separator())

        for lang in SupportedLanguage.all {
            let item = NSMenuItem(
                title: lang.name,
                action: #selector(MenuBarActionHandler.selectLanguage(_:)),
                keyEquivalent: ""
            )
            item.target = MenuBarActionHandler.shared
            item.representedObject = lang.id

            // Mark the currently selected language
            if let currentCode = settingsStore.languageMode.languageCode,
               currentCode == lang.id {
                item.state = .on
            }
            languageSubmenu.addItem(item)
        }
    }

    // MARK: - Icon State Updates

    /// Updates the menu bar icon to reflect the current application state.
    ///
    /// Requirement 5.2: Icon reflects idle, recording, or processing state.
    /// Requirement 14.9: Smooth icon transitions on state change.
    private func updateIcon(for state: AppStateType) {
        guard let button = statusItem.button else { return }

        let description: String
        switch state {
        case .loading:
            description = "Stop Typing — Loading"
        case .idle:
            description = "Stop Typing — Idle"
        case .recording:
            description = "Stop Typing — Recording"
        case .processing:
            description = "Stop Typing — Processing"
        case .error:
            description = "Stop Typing — Error"
        }

        let image = makeStatusItemImage(appState: state, accessibilityDescription: description)
        button.image = image
        button.toolTip = description

        // Drive animation via Core Animation (runs on the render server,
        // zero main-thread or Swift Concurrency executor overhead).
        if state == .processing {
            startProcessingAnimation()
        } else {
            stopProcessingAnimation()
        }
    }

    // MARK: - Processing Animation (Core Animation)

    /// Adds a subtle opacity pulse to the status button using Core Animation.
    ///
    /// CA animations run on the macOS render server (a separate process),
    /// so they have zero impact on the main thread or Swift Concurrency
    /// cooperative executor — WhisperKit.transcribe() won't be starved.
    ///
    /// Respects `themeEngine.reduceMotion`.
    private func startProcessingAnimation() {
        guard let button = statusItem.button else { return }
        guard !themeEngine.reduceMotion else { return }
        guard button.layer?.animation(forKey: Self.processingAnimationKey) == nil else { return }

        button.wantsLayer = true
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 1.0
        pulse.toValue = 0.3
        pulse.duration = 0.6
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        button.layer?.add(pulse, forKey: Self.processingAnimationKey)
    }

    /// Removes the processing pulse animation.
    private func stopProcessingAnimation() {
        guard let button = statusItem.button else { return }
        button.layer?.removeAnimation(forKey: Self.processingAnimationKey)
    }

    // MARK: - State Observation

    /// Starts observing StateManager for app state changes to update the icon and menu.
    private func startObservingState() {
        observationTask = Task { [weak self] in
            guard let self else { return }
            // Use withObservationTracking in a loop to react to state changes
            while !Task.isCancelled {
                let currentState = self.stateManager.appState
                _ = self.settingsStore.languageMode

                self.updateIcon(for: currentState)
                self.refreshUpdateMenuItem()
                self.languageMenuItem.title = self.languageDisplayTitle()
                self.buildLanguageSubmenu()
                self.refreshMenuBranding()

                // Wait for the next change using Observation framework
                await withCheckedContinuation { continuation in
                    withObservationTracking {
                        _ = self.stateManager.appState
                        _ = self.settingsStore.languageMode
                        _ = self.settingsStore.hotkeyKeyCode
                        _ = self.settingsStore.hotkeyModifiers
                        _ = self.updateChecker.availableUpdate
                        _ = self.themeEngine.isDarkMode
                        _ = self.themeEngine.increaseContrast
                    } onChange: {
                        continuation.resume()
                    }
                }
            }
        }
    }

    /// Stops observation and cleans up.
    func stopObserving() {
        observationTask?.cancel()
        observationTask = nil
        stopProcessingAnimation()
    }

    // MARK: - Actions (called by MenuBarActionHandler)

    /// Toggles recording on/off.
    ///
    /// Requirement 5.4: Start/Stop Recording from menu.
    func toggleRecording() {
        Task {
            if stateManager.appState == .recording {
                await stateManager.endRecording()
            } else {
                await stateManager.beginRecording()
            }
        }
    }

    /// Opens the Settings window.
    ///
    /// Creates an NSWindow hosting the SwiftUI SettingsView if one doesn't
    /// already exist, or brings the existing one to front.
    func openSettings() {
        NSApp.activate()

        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            return
        }

        let settingsView = SettingsView(
            audioEngine: audioEngine,
            whisperService: transcriptionEngine
        )
        .environment(settingsStore)
        .environment(themeEngine)
        .environment(stateManager)
        .environment(hotkeyMonitor)
        .environment(permissionManager)
        .environment(updateChecker)

        let hostingController = NSHostingController(rootView: settingsView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Stop Typing Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 560, height: 580))
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        settingsWindow = window
    }

    /// Opens the Model Management window.
    ///
    /// Creates an NSWindow hosting the SwiftUI ModelManagementView if one doesn't
    /// already exist, or brings the existing one to front.
    func openModelManagement() {
        NSApp.activate()

        if let window = modelManagementWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            return
        }

        let modelView = ModelManagementView(whisperService: transcriptionEngine)
            .environment(settingsStore)
            .environment(themeEngine)
            .environment(stateManager)

        let hostingController = NSHostingController(rootView: modelView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Model Management"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 620, height: 640))
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        modelManagementWindow = window
    }

    /// Sets language to auto-detect mode.
    ///
    /// Requirement 16.8: Language selection from menu.
    func selectAutoDetect() {
        settingsStore.languageMode = .autoDetect
        stateManager.currentLanguage = .autoDetect
    }

    /// Sets a specific language for transcription.
    ///
    /// Requirement 16.8: Language selection from menu.
    func selectLanguage(_ code: String) {
        let mode = TranscriptionLanguage.specific(code: code)
        settingsStore.languageMode = mode
        stateManager.currentLanguage = mode
    }

    /// Checks whether /usr/local/bin/wispr exists and points to the
    /// wispr-cli binary inside the current app bundle.
    private func isCLIInstalled() -> Bool {
        let fm = FileManager.default
        guard let dest = try? fm.destinationOfSymbolicLink(atPath: cliSymlinkPath) else {
            return false
        }
        let expectedDest = Bundle.main.bundlePath + "/Contents/Resources/bin/wispr-cli"
        return URL(fileURLWithPath: dest).resolvingSymlinksInPath().path
            == URL(fileURLWithPath: expectedDest).resolvingSymlinksInPath().path
    }

    /// Presents the CLI install dialog as a floating window.
    func showCLIInstallDialog() {
        NSApp.activate()

        if let window = cliInstallWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            return
        }

        // Discard any previously closed window to avoid stale hosting controller state.
        cliInstallWindow = nil

        let window = NSWindow()
        window.title = "Install Command Line Tool"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false

        let dialogView = CLIInstallDialogView(
            appBundlePath: Bundle.main.bundlePath,
            symlinkPath: cliSymlinkPath,
            onDismiss: { [weak self, weak window] in
                window?.close()
                self?.cliInstallWindow = nil
            }
        )
        let hostingController = NSHostingController(rootView: dialogView)
        window.contentViewController = hostingController
        window.setContentSize(hostingController.view.fittingSize)
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        cliInstallWindow = window
    }

    /// Quits the application after cleaning up resources.
    ///
    /// Requirement 5.5: Clean up all resources and terminate.
    func quitApp() {
        stopObserving()
        NSApp.terminate(nil)
    }
}

// MARK: - Menu Open Delegate

/// Refreshes filesystem-dependent menu items each time the dropdown opens.
final class MenuOpenDelegate: NSObject, NSMenuDelegate {
    private weak var controller: MenuBarController?

    init(controller: MenuBarController) {
        self.controller = controller
    }

    func menuWillOpen(_ menu: NSMenu) {
        controller?.refreshCLIInstallMenuItem()
        controller?.refreshMenuBranding()
    }
}

// MARK: - Menu Action Handler

/// A helper class that bridges NSMenuItem target-action to MenuBarController.
///
/// NSMenuItem requires an `@objc` target. This is one of the unavoidable
/// AppKit bridging points per Requirement 15.7.
final class MenuBarActionHandler: NSObject {
    static let shared = MenuBarActionHandler()

    /// Weak reference to the MenuBarController to forward actions.
    weak var menuBarController: MenuBarController?

    @MainActor
    @objc func toggleRecording(_ sender: NSMenuItem) {
        menuBarController?.toggleRecording()
    }

    @MainActor
    @objc func openSettings(_ sender: NSMenuItem) {
        menuBarController?.openSettings()
    }

    @MainActor
    @objc func openModelManagement(_ sender: NSMenuItem) {
        menuBarController?.openModelManagement()
    }

    @MainActor
    @objc func selectAutoDetect(_ sender: NSMenuItem) {
        menuBarController?.selectAutoDetect()
    }

    @MainActor
    @objc func selectLanguage(_ sender: NSMenuItem) {
        guard let code = sender.representedObject as? String else { return }
        menuBarController?.selectLanguage(code)
    }

    @MainActor
    @objc func openUpdateDownload(_ sender: NSMenuItem) {
        menuBarController?.openUpdateDownload()
    }

    @MainActor
    @objc func showCLIInstallDialog(_ sender: NSMenuItem) {
        menuBarController?.showCLIInstallDialog()
    }

    @MainActor
    @objc func quitApp(_ sender: NSMenuItem) {
        menuBarController?.quitApp()
    }
}
