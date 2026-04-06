//
//  KeyboardView.swift
//  StopTypingKeyboard
//
//  SwiftUI keyboard layout with dictation mic button.
//

import SwiftUI
import AVFAudio

struct KeyboardView: View {
    let insertText: (String) -> Void
    let deleteBackward: () -> Void
    let nextKeyboard: () -> Void
    let hasFullAccess: Bool

    @State private var isRecording = false
    @State private var isProcessing = false
    @State private var errorText = ""
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
            if !errorText.isEmpty {
                Text(errorText).font(.system(size: 10)).foregroundStyle(.red).frame(height: 24)
            } else if isRecording || isProcessing {
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
        errorText = ""
        guard audioEngine != nil else {
            errorText = "No audio engine"
            return
        }
        guard hasFullAccess else {
            errorText = "Enable Allow Full Access in Settings"
            return
        }
        // Set recording state immediately to prevent double-tap issues
        isRecording = true
        Task {
            do {
                _ = try await audioEngine!.startCapture()
            } catch {
                isRecording = false
                errorText = "Mic: \(error)"
            }
        }
    }

    private func stopRecording() {
        guard let engine = audioEngine else {
            errorText = "No engine"
            return
        }
        guard isRecording else { return }
        isRecording = false
        isProcessing = true

        Task {
            // Get raw WAV data directly (skip double conversion)
            guard let wavData = await engine.stopCaptureAsWavData(), wavData.count > 100 else {
                isProcessing = false
                errorText = "No audio captured"
                return
            }

            do {
                // Call Groq API directly with WAV data
                let text = try await transcribeWavDirectly(wavData: wavData)

                var finalText = text
                if let processor = postProcessor {
                    finalText = await processor.process(finalText)
                }

                insertText(finalText)
            } catch {
                errorText = "API: \(error)"
            }
            isProcessing = false
        }
    }

    /// Calls Groq Whisper API directly with WAV data (no double conversion).
    private func transcribeWavDirectly(wavData: Data) async throws -> String {
        let boundary = UUID().uuidString
        var body = Data()

        // model
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"model\"\r\n\r\n".utf8))
        body.append(Data("whisper-large-v3\r\n".utf8))

        // temperature
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"temperature\"\r\n\r\n".utf8))
        body.append(Data("0\r\n".utf8))

        // response_format
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".utf8))
        body.append(Data("json\r\n".utf8))

        // prompt
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n".utf8))
        body.append(Data("Hello, this is a voice dictation. Use proper punctuation including commas, periods, and question marks. Capitalize sentences.\r\n".utf8))

        // audio file
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"file\"; filename=\"recording.wav\"\r\n".utf8))
        body.append(Data("Content-Type: audio/wav\r\n\r\n".utf8))
        body.append(wavData)
        body.append(Data("\r\n".utf8))

        // close
        body.append(Data("--\(boundary)--\r\n".utf8))

        var request = URLRequest(url: URL(string: "https://api.groq.com/openai/v1/audio/transcriptions")!)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("Bearer \(Self.groqKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown"
            throw NSError(domain: "Groq", code: (response as? HTTPURLResponse)?.statusCode ?? 0, userInfo: [NSLocalizedDescriptionKey: errorBody])
        }

        struct GroqResponse: Decodable { let text: String }
        let decoded = try JSONDecoder().decode(GroqResponse.self, from: data)
        return decoded.text
    }
}
