//
//  MenuBarController.swift
//  wispr
//
//  Manages the NSStatusItem menu bar presence, ST lettermark icon, and popover panel.
//  Bridges to SwiftUI views for settings, model management, and language selection.
//  Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 14.2, 14.9, 16.7, 16.8
//

import AppKit
import SwiftUI
import Observation
import os

/// Manages the NSStatusItem in the macOS menu bar.
///
/// Creates the status item on init, sets a custom "ST" menu bar mark (brand-colored or template)
/// that reflects the current application state, and shows an NSPopover with a SwiftUI
/// `StopTypingPopoverView` for recording, settings, model management, language selection,
/// and quit actions.
///
/// ## Why AppKit? (Modernization blocker)
/// SwiftUI's `MenuBarExtra` doesn't support dynamic icon changes, submenus, or
/// target-action wiring needed here. `NSStatusItem` / `NSPopover` remain the only
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

    /// The popover panel shown when the user clicks the status item.
    private let popover: NSPopover

    /// Exposed for unit tests.
    var popoverForTesting: NSPopover { popover }

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

    /// Event monitor for closing the popover on outside clicks.
    private var eventMonitor: Any?

    // MARK: - Initialization

    /// Creates the MenuBarController and sets up the status item, icon, and popover.
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
        self.popover = NSPopover()

        configureStatusButton()
        configurePopover()
        startObservingState()
    }

    // MARK: - Status Button Configuration

    /// Configures the status item button with the initial icon and click action.
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

        button.action = #selector(PopoverToggleTarget.togglePopover(_:))
        button.target = PopoverToggleTarget.shared
        PopoverToggleTarget.shared.controller = self
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

    // MARK: - Popover Configuration

    private func configurePopover() {
        popover.behavior = .transient
        popover.appearance = NSAppearance(named: .darkAqua)
        popover.animates = !themeEngine.reduceMotion
        popover.contentSize = NSSize(width: 500, height: 10)
        rebuildPopoverContent()
    }

    /// Cached list of audio input devices, refreshed each time the popover is rebuilt.
    private var cachedAudioDevices: [AudioInputDevice] = []

    /// Rebuilds the popover's content view controller with current state.
    private func rebuildPopoverContent() {
        let actions = PopoverActions(
            toggleRecording: { [weak self] in self?.toggleRecording() },
            openSettings: { [weak self] in self?.openSettings() },
            openModelManagement: { [weak self] in self?.openModelManagement() },
            selectAutoDetect: { [weak self] in self?.selectAutoDetect() },
            selectLanguage: { [weak self] code in self?.selectLanguage(code) },
            selectAudioDevice: { [weak self] device in self?.selectAudioDevice(device) },
            openUpdateDownload: { [weak self] in self?.openUpdateDownload() },
            showCLIInstallDialog: { [weak self] in self?.showCLIInstallDialog() },
            quitApp: { [weak self] in self?.quitApp() },
            dismiss: { [weak self] in self?.closePopover() }
        )

        let shortcut = KeyCodeMapping.shared.hotkeyDisplayString(
            keyCode: settingsStore.hotkeyKeyCode,
            modifiers: settingsStore.hotkeyModifiers
        )

        let popoverView = StopTypingPopoverView(
            appState: stateManager.appState,
            languageMode: settingsStore.languageMode,
            hotkeyDisplayString: shortcut,
            activeModelName: settingsStore.activeModelName,
            audioDevices: cachedAudioDevices,
            selectedDeviceUID: settingsStore.selectedAudioDeviceUID,
            availableUpdate: updateChecker.availableUpdate,
            isCLIInstalled: isCLIInstalled(),
            actions: actions
        )
        .environment(themeEngine)

        let hostingController = NSHostingController(rootView: popoverView)
        hostingController.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hostingController
    }

    // MARK: - Popover Toggle

    /// Toggles the popover visibility when the status bar button is clicked.
    func togglePopoverVisibility() {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        Task {
            cachedAudioDevices = await audioEngine.availableInputDevices()
            rebuildPopoverContent()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            installEventMonitor()
        }
    }

    private func closePopover() {
        popover.performClose(nil)
        removeEventMonitor()
    }

    /// Installs a global event monitor to close the popover on outside clicks,
    /// supplementing NSPopover's `.transient` behavior.
    private func installEventMonitor() {
        removeEventMonitor()
        eventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            guard let self, self.popover.isShown else { return }
            self.closePopover()
        }
    }

    private func removeEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
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

    /// Starts observing StateManager for app state changes to update the icon and popover.
    private func startObservingState() {
        observationTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                let currentState = self.stateManager.appState
                _ = self.settingsStore.languageMode

                self.updateIcon(for: currentState)

                if self.popover.isShown {
                    self.rebuildPopoverContent()
                }

                await withCheckedContinuation { continuation in
                    withObservationTracking {
                        _ = self.stateManager.appState
                        _ = self.settingsStore.languageMode
                        _ = self.settingsStore.hotkeyKeyCode
                        _ = self.settingsStore.hotkeyModifiers
                        _ = self.settingsStore.activeModelName
                        _ = self.settingsStore.selectedAudioDeviceUID
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
        removeEventMonitor()
    }

    // MARK: - Actions (called by PopoverActions closures)

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
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = StopTypingBrand.canvas
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
        window.title = "Stop Typing — Model Management"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = StopTypingBrand.canvas
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

    /// Selects an audio input device for recording.
    func selectAudioDevice(_ device: AudioInputDevice) {
        settingsStore.selectedAudioDeviceUID = device.uid
        Task {
            try? await audioEngine.setInputDevice(device.id)
        }
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

        cliInstallWindow = nil

        let window = NSWindow()
        window.title = "Stop Typing — CLI Tool"
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = StopTypingBrand.canvas
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

    /// Opens the download URL for the available update.
    func openUpdateDownload() {
        guard let update = updateChecker.availableUpdate else {
            Log.updateChecker.error("openUpdateDownload called but no update available")
            return
        }
        Log.updateChecker.info("User opening download URL: \(update.downloadURL.absoluteString)")
        NSWorkspace.shared.open(update.downloadURL)
    }

    /// Quits the application after cleaning up resources.
    ///
    /// Requirement 5.5: Clean up all resources and terminate.
    func quitApp() {
        stopObserving()
        NSApp.terminate(nil)
    }
}

// MARK: - Popover Toggle Target

/// Bridges the NSStatusBarButton action to MenuBarController (requires @objc).
final class PopoverToggleTarget: NSObject {
    static let shared = PopoverToggleTarget()

    weak var controller: MenuBarController?

    @MainActor
    @objc func togglePopover(_ sender: Any?) {
        controller?.togglePopoverVisibility()
    }
}
