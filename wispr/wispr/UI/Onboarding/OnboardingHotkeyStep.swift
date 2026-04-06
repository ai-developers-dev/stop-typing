//
//  OnboardingHotkeyStep.swift
//  wispr
//
//  Hotkey configuration step for the onboarding flow.
//  Reuses the existing HotkeyRecorderView from Settings.
//

import SwiftUI

/// Onboarding step where the user configures their dictation hotkey.
///
/// Shows the current hotkey (default: Fn/Globe) and lets the user
/// record a new one. Reuses `HotkeyRecorderView` and re-registers
/// the hotkey via `HotkeyMonitor` when recording finishes.
struct OnboardingHotkeyStep: View {
    @Environment(SettingsStore.self) private var settingsStore: SettingsStore
    @Environment(UIThemeEngine.self) private var theme: UIThemeEngine

    /// The hotkey monitor used to register/unregister during recording.
    let hotkeyMonitor: HotkeyMonitor

    @State private var isRecordingHotkey = false
    @State private var hotkeyError: String?

    var body: some View {
        VStack(spacing: 20) {
            OnboardingIconBadge(
                systemName: SFSymbols.keyboard,
                color: theme.accentColor
            )

            Text("Set Your Hotkey")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(theme.primaryTextColor)

            Text("Choose a keyboard shortcut to start and stop dictation. The default is 🌐 Fn (Globe key). You can change this anytime in Settings.")
                .font(.body)
                .foregroundStyle(theme.secondaryTextColor)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
                .lineSpacing(5)

            // Hotkey recorder
            HotkeyRecorderView(
                keyCode: Bindable(settingsStore).hotkeyKeyCode,
                modifiers: Bindable(settingsStore).hotkeyModifiers,
                isRecording: $isRecordingHotkey,
                errorMessage: $hotkeyError
            )
            .padding(.top, 8)

            // Error message
            if let error = hotkeyError {
                Label(error, systemImage: theme.actionSymbol(.warning))
                    .foregroundStyle(theme.errorColor)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Fn key info note
            if settingsStore.hotkeyKeyCode == HotkeyMonitor.fnKeyCode
                && settingsStore.hotkeyModifiers == 0 {
                Label {
                    Text("The Globe key may conflict with the emoji picker. If dictation doesn't start, go to System Settings → Keyboard → \"Press 🌐 key to\" and select \"Do Nothing\".")
                } icon: {
                    Image(systemName: SFSymbols.info)
                        .foregroundStyle(.blue)
                }
                .font(.caption)
                .foregroundStyle(theme.secondaryTextColor)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: 420)
                .padding(.top, 4)
            }
        }
        .onChange(of: isRecordingHotkey) { _, recording in
            if recording {
                hotkeyMonitor.unregister()
            } else {
                do {
                    try hotkeyMonitor.register(
                        keyCode: settingsStore.hotkeyKeyCode,
                        modifiers: settingsStore.hotkeyModifiers
                    )
                    hotkeyError = nil
                } catch WisprError.accessibilityPermissionDenied {
                    hotkeyError = "The 🌐 Fn key requires Accessibility permission. Grant access in System Settings → Privacy & Security → Accessibility."
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                } catch {
                    hotkeyError = error.localizedDescription
                }
            }
        }
        .motionRespectingAnimation(value: hotkeyError)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Hotkey Setup step")
    }
}
