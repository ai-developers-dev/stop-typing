//
//  OnboardingWelcomeStep.swift
//  wispr
//
//  Welcome step content for the onboarding flow.
//

import SwiftUI

/// Welcome step that introduces the user to Stop Typing.
struct OnboardingWelcomeStep: View {
    @Environment(UIThemeEngine.self) private var theme: UIThemeEngine

    var body: some View {
        VStack(spacing: 20) {
            OnboardingIconBadge(
                systemName: SFSymbols.onboardingWelcome,
                color: theme.accentColor,
                isLarge: true
            )

            Text("Welcome to Stop Typing")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(theme.primaryTextColor)

            Text("Stop Typing lets you dictate text anywhere on your Mac using a global hotkey. Transcription happens on-device or via our secure cloud API for Pro users.")
                .font(.body)
                .foregroundStyle(theme.secondaryTextColor)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
                .lineSpacing(5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Welcome to Stop Typing. Dictate text anywhere on your Mac. Transcription happens on-device or via secure cloud.")
    }
}
