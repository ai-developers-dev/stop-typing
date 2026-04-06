//
//  KeyboardView.swift
//  StopTypingKeyboard
//
//  SwiftUI keyboard layout with dictation mic button.
//

import SwiftUI

struct KeyboardView: View {
    let insertText: (String) -> Void
    let deleteBackward: () -> Void
    let nextKeyboard: () -> Void
    let hasFullAccess: Bool

    @State private var isRecording = false
    @State private var isProcessing = false
    @State private var audioEngine: iOSAudioEngine?
    @State private var groqService: GroqCloudService?
    @State private var postProcessor: SmartPostProcessor?
    @State private var isUppercase = false

    private let brand = Color(red: 0.41, green: 0.855, blue: 1.0)
    private let keyBg = Color.white.opacity(0.12)
    private let keyText = Color.white

    private let topRow = ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"]
    private let middleRow = ["a", "s", "d", "f", "g", "h", "j", "k", "l"]
    private let bottomRow = ["z", "x", "c", "v", "b", "n", "m"]

    var body: some View {
        VStack(spacing: 6) {
            // Status bar
            if isRecording || isProcessing {
                HStack {
                    if isRecording {
                        Circle().fill(.red).frame(width: 8, height: 8)
                        Text("Listening...").font(.caption).foregroundStyle(.white)
                    } else {
                        ProgressView().controlSize(.mini).tint(brand)
                        Text("Transcribing...").font(.caption).foregroundStyle(.white)
                    }
                }
                .frame(height: 24)
            }

            // Letter rows
            keyRow(topRow)
            keyRow(middleRow)

            HStack(spacing: 4) {
                // Shift
                Button { isUppercase.toggle() } label: {
                    Image(systemName: isUppercase ? "shift.fill" : "shift")
                        .frame(width: 40, height: 42)
                        .foregroundStyle(keyText)
                        .background(keyBg, in: RoundedRectangle(cornerRadius: 6))
                }

                keyRow(bottomRow)

                // Backspace
                Button { deleteBackward() } label: {
                    Image(systemName: "delete.backward")
                        .frame(width: 40, height: 42)
                        .foregroundStyle(keyText)
                        .background(keyBg, in: RoundedRectangle(cornerRadius: 6))
                }
            }

            // Bottom row: globe, mic/dictate, space, return
            HStack(spacing: 4) {
                // Globe (switch keyboard)
                Button { nextKeyboard() } label: {
                    Image(systemName: "globe")
                        .frame(width: 40, height: 42)
                        .foregroundStyle(keyText)
                        .background(keyBg, in: RoundedRectangle(cornerRadius: 6))
                }

                // Mic / Dictate button
                Button {
                    if isRecording {
                        stopRecording()
                    } else {
                        startRecording()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 14, weight: .semibold))
                        if !isRecording && !isProcessing {
                            Text("Dictate").font(.caption.weight(.semibold))
                        }
                    }
                    .foregroundStyle(isRecording ? .white : .black)
                    .frame(width: 90, height: 42)
                    .background(isRecording ? Color.red : brand, in: RoundedRectangle(cornerRadius: 6))
                }
                .disabled(isProcessing || !hasFullAccess)

                // Space
                Button { insertText(" ") } label: {
                    Text("space")
                        .font(.caption)
                        .foregroundStyle(keyText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(keyBg, in: RoundedRectangle(cornerRadius: 6))
                }

                // Return
                Button { insertText("\n") } label: {
                    Image(systemName: "return")
                        .frame(width: 60, height: 42)
                        .foregroundStyle(keyText)
                        .background(keyBg, in: RoundedRectangle(cornerRadius: 6))
                }
            }

            if !hasFullAccess {
                Text("Enable \"Allow Full Access\" in Settings to use dictation")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 2)
            }
        }
        .padding(.horizontal, 3)
        .padding(.vertical, 4)
        .background(Color(red: 0.043, green: 0.055, blue: 0.067))
        .onAppear { setupServices() }
    }

    // MARK: - Key Row

    private func keyRow(_ keys: [String]) -> some View {
        HStack(spacing: 4) {
            ForEach(keys, id: \.self) { key in
                Button {
                    insertText(isUppercase ? key.uppercased() : key)
                    if isUppercase { isUppercase = false }
                } label: {
                    Text(isUppercase ? key.uppercased() : key)
                        .font(.system(size: 18))
                        .foregroundStyle(keyText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(keyBg, in: RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }

    // MARK: - Recording

    private static var groqKey: String { KeychainHelper.load(key: KeychainHelper.groqAPIKey) ?? "" }

    private func setupServices() {
        audioEngine = iOSAudioEngine()
        groqService = GroqCloudService(apiKeyProvider: { Self.groqKey })
        postProcessor = SmartPostProcessor(apiKeyProvider: { Self.groqKey })
    }

    private func startRecording() {
        guard let engine = audioEngine else { return }
        Task {
            do {
                _ = try await engine.startCapture()
                isRecording = true
            } catch {
                print("Keyboard recording failed: \(error)")
            }
        }
    }

    private func stopRecording() {
        guard let engine = audioEngine, let service = groqService else { return }
        isRecording = false
        isProcessing = true

        Task {
            let samples = await engine.stopCapture()
            guard !samples.isEmpty else {
                isProcessing = false
                return
            }

            do {
                let result = try await service.transcribe(samples, language: .autoDetect)
                var text = result.text

                // Smart post-processing if available
                if let processor = postProcessor {
                    text = await processor.process(text)
                }

                insertText(text)
            } catch {
                print("Keyboard transcription failed: \(error)")
            }
            isProcessing = false
        }
    }
}
