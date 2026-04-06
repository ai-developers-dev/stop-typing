//
//  StopTypingApp.swift
//  StopTyping (iOS)
//
//  Main entry point for the iOS app.
//

import SwiftUI

@main
struct StopTypingApp: App {
    @State private var hasCompletedOnboarding = UserDefaults(suiteName: "group.com.stormacq.wispr")?.bool(forKey: "onboardingCompleted") ?? false

    init() {
        // Seed the Groq API key into Keychain (same as macOS app)
        KeychainHelper.seedGroqKeyIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ContentView()
            } else {
                OnboardingView(onComplete: {
                    hasCompletedOnboarding = true
                    UserDefaults(suiteName: "group.com.stormacq.wispr")?.set(true, forKey: "onboardingCompleted")
                })
            }
        }
    }
}
