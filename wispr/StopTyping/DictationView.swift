//
//  DictationView.swift
//  StopTyping (iOS)
//
//  Standalone dictation screen with mic button and transcription display.
//

import SwiftUI
import AVFAudio

struct DictationView: View {
    @State private var isRecording = false
    @State private var isProcessing = false
    @State private var transcriptionResult = ""
    @State private var audioEngine: iOSAudioEngine?
    @State private var groqService: GroqCloudService?

    private let brand = Color(red: 0.41, green: 0.855, blue: 1.0) // #69DAFF
    private let canvas = Color(red: 0.043, green: 0.055, blue: 0.067) // #0B0E11

    var body: some View {
        NavigationStack {
            ZStack {
                canvas.ignoresSafeArea()

                VStack(spacing: 32) {
                    Spacer()

                    // Status text
                    Text(statusText)
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundStyle(isRecording ? .red : brand)

                    // Mic button
                    Button {
                        if isRecording {
                            stopRecording()
                        } else {
                            startRecording()
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(isRecording ? Color.red.opacity(0.15) : brand.opacity(0.1))
                                .frame(width: 120, height: 120)

                            Circle()
                                .fill(isRecording ? Color.red : brand)
                                .frame(width: 80, height: 80)

                            Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                                .font(.system(size: 32, weight: .medium))
                                .foregroundStyle(.white)
                        }
                    }
                    .disabled(isProcessing)
                    .opacity(isProcessing ? 0.5 : 1)

                    if isProcessing {
                        ProgressView()
                            .tint(brand)
                    }

                    // Transcription result
                    if !transcriptionResult.isEmpty {
                        VStack(spacing: 12) {
                            Text(transcriptionResult)
                                .font(.body)
                                .foregroundStyle(.white)
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.white.opacity(0.05))
                                )

                            Button {
                                UIPasteboard.general.string = transcriptionResult
                            } label: {
                                Label("Copy to Clipboard", systemImage: "doc.on.doc")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(canvas)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(brand, in: Capsule())
                            }
                        }
                        .padding(.horizontal)
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Stop Typing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(canvas, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            setupServices()
        }
    }

    private var statusText: String {
        if isProcessing { return "Transcribing..." }
        if isRecording { return "Listening..." }
        if transcriptionResult.isEmpty { return "Tap to dictate" }
        return "Done"
    }

    private static var groqKey: String { KeychainHelper.load(key: KeychainHelper.groqAPIKey) ?? "" }

    private func setupServices() {
        audioEngine = iOSAudioEngine()
        groqService = GroqCloudService(apiKeyProvider: { Self.groqKey })
    }

    private func startRecording() {
        Task {
            guard let engine = audioEngine else { return }
            do {
                _ = try await engine.startCapture()
                isRecording = true
            } catch {
                print("Recording failed: \(error)")
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
                transcriptionResult = result.text
            } catch {
                transcriptionResult = "Error: \(error)"
            }
            isProcessing = false
        }
    }
}
