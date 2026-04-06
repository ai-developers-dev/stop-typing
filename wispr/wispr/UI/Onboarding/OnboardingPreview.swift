//
//  OnboardingPreview.swift
//  wispr
//
//  Preview helpers for the onboarding flow.
//

import SwiftUI

#if DEBUG
struct OnboardingPreview: View {
    @State private var settingsStore: SettingsStore
    @State private var permissionManager = PreviewMocks.makePermissionManager()
    @State private var theme = PreviewMocks.makeTheme()
    @State private var stateManager: StateManager

    let step: OnboardingStep

    init(step: OnboardingStep = .welcome) {
        self.step = step
        let store = PreviewMocks.makeSettingsStore()
        _settingsStore = State(initialValue: store)
        _stateManager = State(initialValue: PreviewMocks.makeStateManager(settingsStore: store))
    }

    var body: some View {
        OnboardingFlow(whisperService: PreviewMocks.makeWhisperService(), hotkeyMonitor: PreviewMocks.makeHotkeyMonitor(), initialStep: step)
            .environment(permissionManager)
            .environment(settingsStore)
            .environment(theme)
            .environment(stateManager)
            .frame(width: 620, height: 580)
    }
}

#Preview("Welcome") {
    OnboardingPreview(step: .welcome)
}

#Preview("Microphone Permission") {
    OnboardingPreview(step: .microphonePermission)
}

#Preview("Accessibility Permission") {
    OnboardingPreview(step: .accessibilityPermission)
}

#Preview("Hotkey Setup") {
    OnboardingPreview(step: .hotkeySetup)
}

#Preview("Test Dictation") {
    OnboardingPreview(step: .testDictation)
}

#Preview("Completion") {
    OnboardingPreview(step: .completion)
}
#endif
