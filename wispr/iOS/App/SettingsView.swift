//
//  SettingsView.swift
//  StopTyping (iOS)
//
//  Settings screen for the iOS app.
//

import SwiftUI

struct iOSSettingsView: View {
    @AppStorage("subscriptionTier", store: UserDefaults(suiteName: "group.com.stormacq.wispr"))
    private var subscriptionTier = "free"

    @AppStorage("smartPostProcessing", store: UserDefaults(suiteName: "group.com.stormacq.wispr"))
    private var smartPostProcessing = false

    private let brand = Color(red: 0.41, green: 0.855, blue: 1.0)
    private let canvas = Color(red: 0.043, green: 0.055, blue: 0.067)

    var body: some View {
        NavigationStack {
            ZStack {
                canvas.ignoresSafeArea()

                List {
                    // Subscription
                    Section {
                        HStack {
                            Text("Plan")
                            Spacer()
                            Text(subscriptionTier == "pro" ? "Pro" : "Free")
                                .foregroundStyle(subscriptionTier == "pro" ? brand : .secondary)
                                .fontWeight(.medium)
                        }

                        if subscriptionTier != "pro" {
                            Button {
                                if let url = URL(string: "https://stoptyping.app/dashboard") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                Text("Upgrade to Pro")
                                    .foregroundStyle(brand)
                            }
                        }
                    } header: {
                        Text("Subscription")
                    }

                    // Transcription
                    Section {
                        Toggle("Smart Post-Processing", isOn: $smartPostProcessing)
                            .tint(brand)
                            .disabled(subscriptionTier != "pro")

                        if subscriptionTier != "pro" {
                            Text("Smart post-processing requires Pro subscription")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("Transcription")
                    }

                    // Keyboard
                    Section {
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            HStack {
                                Text("Enable Keyboard")
                                Spacer()
                                Image(systemName: "arrow.up.forward")
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Text("Go to Settings → Keyboards → Add New Keyboard → Stop Typing. Then enable \"Allow Full Access\" for dictation.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } header: {
                        Text("Keyboard Extension")
                    }

                    // About
                    Section {
                        HStack {
                            Text("Version")
                            Spacer()
                            Text("1.0.0")
                                .foregroundStyle(.secondary)
                        }

                        Link("Website", destination: URL(string: "https://stoptyping.app")!)
                        Link("Privacy Policy", destination: URL(string: "https://stoptyping.app")!)
                    } header: {
                        Text("About")
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(canvas, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }
}
