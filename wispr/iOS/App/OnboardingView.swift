//
//  OnboardingView.swift
//  StopTyping (iOS)
//
//  Simplified iOS onboarding: mic permission → keyboard setup → done.
//

import SwiftUI
import AVFAudio

struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var step = 0
    @State private var micGranted = false

    private let brand = Color(red: 0.41, green: 0.855, blue: 1.0)
    private let canvas = Color(red: 0.043, green: 0.055, blue: 0.067)

    var body: some View {
        ZStack {
            canvas.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(brand.opacity(0.1))
                        .frame(width: 120, height: 120)

                    Image(systemName: stepIcon)
                        .font(.system(size: 48, weight: .medium))
                        .foregroundStyle(brand)
                }

                // Title
                Text(stepTitle)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                // Description
                Text(stepDescription)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()

                // Action button
                Button {
                    handleAction()
                } label: {
                    Text(stepButtonLabel)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(canvas)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(brand, in: RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 24)

                // Step indicator
                HStack(spacing: 8) {
                    ForEach(0..<3) { i in
                        Circle()
                            .fill(i == step ? brand : Color.white.opacity(0.2))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            checkMicPermission()
        }
    }

    private var stepIcon: String {
        switch step {
        case 0: return "mic.badge.plus"
        case 1: return "keyboard"
        case 2: return "checkmark.seal.fill"
        default: return "checkmark"
        }
    }

    private var stepTitle: String {
        switch step {
        case 0: return "Microphone Access"
        case 1: return "Enable Keyboard"
        case 2: return "You're All Set!"
        default: return ""
        }
    }

    private var stepDescription: String {
        switch step {
        case 0: return "Stop Typing needs microphone access to transcribe your voice into text."
        case 1: return "Add the Stop Typing keyboard in Settings → Keyboards → Add New Keyboard. Enable \"Allow Full Access\" for dictation to work."
        case 2: return "Switch to the Stop Typing keyboard in any app, tap the mic button, and start dictating."
        default: return ""
        }
    }

    private var stepButtonLabel: String {
        switch step {
        case 0: return micGranted ? "Continue" : "Grant Microphone Access"
        case 1: return "Open Settings"
        case 2: return "Get Started"
        default: return "Continue"
        }
    }

    private func handleAction() {
        switch step {
        case 0:
            if micGranted {
                step = 1
            } else {
                Task {
                    micGranted = await AVAudioApplication.requestRecordPermission()
                    if micGranted { step = 1 }
                }
            }
        case 1:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
            // Advance after opening settings
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                step = 2
            }
        case 2:
            onComplete()
        default:
            break
        }
    }

    private func checkMicPermission() {
        let status = AVAudioApplication.shared.recordPermission
        micGranted = status == .granted
    }
}
