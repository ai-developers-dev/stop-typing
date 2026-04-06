//
//  GroqCloudService.swift
//  wispr
//
//  Cloud transcription engine using the Groq Whisper API.
//  Conforms to TranscriptionEngine so it plugs into the
//  existing CompositeTranscriptionEngine alongside local models.
//
//  Audio is converted to WAV in-memory and uploaded via
//  multipart/form-data POST. No audio is persisted to disk.
//

import Foundation
import os

/// Cloud-based transcription via Groq's Whisper API.
///
/// This actor conforms to the same `TranscriptionEngine` protocol used by
/// WhisperService and ParakeetService, so it slots into the
/// `CompositeTranscriptionEngine` with zero changes to StateManager or
/// AudioEngine.
///
/// Cloud models have no local download or memory footprint — model lifecycle
/// methods are no-ops. The only network traffic is the audio upload for
/// transcription.
actor GroqCloudService: TranscriptionEngine {

    // MARK: - Configuration

    private static let baseURL = URL(string: "https://api.groq.com/openai/v1/audio/transcriptions")!
    private static let maxRetries = 2
    private static let log = Logger(subsystem: "com.stopTyping", category: "GroqCloud")

    /// Closure that returns the current API key, typically reading from KeychainHelper.
    private let apiKeyProvider: @Sendable () -> String?

    /// Context prompt sent with every transcription request (max 224 tokens).
    /// Guides vocabulary, spelling, and style without changing the model itself.
    private let contextPrompt: String

    /// The currently "active" cloud model ID. Cloud models don't need loading,
    /// but the composite engine tracks which engine owns the active model.
    private var activeModelId: String?

    // MARK: - Init

    /// - Parameters:
    ///   - apiKeyProvider: Closure returning the Groq API key from Keychain.
    ///   - contextPrompt: Vocabulary/style hints for the Whisper model (max 224 tokens).
    init(
        apiKeyProvider: @escaping @Sendable () -> String?,
        contextPrompt: String = GroqCloudService.defaultContextPrompt
    ) {
        self.apiKeyProvider = apiKeyProvider
        self.contextPrompt = contextPrompt
    }

    /// Default context prompt optimized for voice dictation with proper punctuation.
    /// Whisper treats the prompt as prior transcript context and mimics its style,
    /// so including well-punctuated examples teaches the model to add commas, periods, etc.
    nonisolated static let defaultContextPrompt = """
    Hello, this is a voice dictation session. I'll be speaking naturally, and I'd like \
    proper punctuation including commas, periods, question marks, and exclamation points. \
    Please capitalize the first word of each sentence. Here's an example of the style I want: \
    "The quick brown fox jumps over the lazy dog. It was a beautiful day, wasn't it? \
    I can't believe how fast that was!" Known terms: Stop Typing, SwiftUI, AppKit, Xcode, \
    GitHub, Convex, Clerk, Stripe, JavaScript, TypeScript, React, Next.js, Tailwind.
    """

    // MARK: - Available Models

    func availableModels() async -> [ModelInfo] {
        [
            ModelInfo(
                id: ModelInfo.KnownID.groqWhisperTurbo,
                displayName: "Groq Whisper Turbo",
                sizeDescription: "Cloud",
                qualityDescription: "Fast cloud transcription, 262× real-time",
                estimatedSize: 0,
                status: .downloaded
            ),
            ModelInfo(
                id: ModelInfo.KnownID.groqWhisperV3,
                displayName: "Groq Whisper Large v3",
                sizeDescription: "Cloud",
                qualityDescription: "Highest accuracy cloud transcription",
                estimatedSize: 0,
                status: .downloaded
            )
        ]
    }

    // MARK: - Model Lifecycle (no-ops for cloud)

    func downloadModel(_ model: ModelInfo) async -> AsyncThrowingStream<DownloadProgress, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(DownloadProgress(
                phase: .downloading,
                fractionCompleted: 1.0,
                bytesDownloaded: 0,
                totalBytes: 0
            ))
            continuation.finish()
        }
    }

    func deleteModel(_ modelName: String) async throws {
        // No local files to delete for cloud models.
    }

    func loadModel(_ modelName: String) async throws {
        guard apiKeyProvider() != nil else {
            throw WisprError.cloudAPIKeyMissing
        }
        activeModelId = modelName
    }

    func switchModel(to modelName: String) async throws {
        try await loadModel(modelName)
    }

    func unloadCurrentModel() async {
        activeModelId = nil
    }

    func validateModelIntegrity(_ modelName: String) async throws -> Bool {
        true
    }

    func modelStatus(_ modelName: String) async -> ModelStatus {
        if activeModelId == modelName { return .active }
        return .downloaded
    }

    func activeModel() async -> String? {
        activeModelId
    }

    func reloadModelWithRetry(maxAttempts: Int) async throws {
        // Cloud models don't need reloading.
    }

    // MARK: - Batch Transcription

    func transcribe(
        _ audioSamples: [Float],
        language: TranscriptionLanguage
    ) async throws -> TranscriptionResult {
        guard let apiKey = apiKeyProvider() else {
            throw WisprError.cloudAPIKeyMissing
        }

        let langCode = await MainActor.run { language.languageCode }
        let groqModel = groqModelName(for: activeModelId)
        let wavData = AudioConverter.wavData(from: audioSamples)
        let startTime = CFAbsoluteTimeGetCurrent()

        let text = try await sendTranscriptionRequest(
            wavData: wavData,
            model: groqModel,
            langCode: langCode,
            apiKey: apiKey
        )

        let duration = CFAbsoluteTimeGetCurrent() - startTime
        Self.log.info("Cloud transcription completed in \(String(format: "%.2f", duration))s (\(audioSamples.count / 16000)s audio)")

        return TranscriptionResult(
            text: text,
            detectedLanguage: langCode,
            duration: duration
        )
    }

    // MARK: - Streaming Transcription

    func transcribeStream(
        _ audioStream: AsyncStream<[Float]>,
        language: TranscriptionLanguage
    ) async -> AsyncThrowingStream<TranscriptionResult, Error> {
        // Groq doesn't support streaming file uploads, so we accumulate
        // all audio chunks and do a single batch transcription.
        let lang = language
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    var allSamples: [Float] = []
                    for await chunk in audioStream {
                        allSamples.append(contentsOf: chunk)
                    }

                    guard !allSamples.isEmpty else {
                        continuation.finish()
                        return
                    }

                    let result = try await self.transcribe(allSamples, language: lang)
                    continuation.yield(result)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func supportsEndOfUtteranceDetection() async -> Bool {
        false
    }

    // MARK: - Groq API

    /// Maps our internal model IDs to the Groq API model parameter.
    private func groqModelName(for modelId: String?) -> String {
        switch modelId {
        case ModelInfo.KnownID.groqWhisperTurbo:
            return "whisper-large-v3-turbo"
        default:
            // Default to highest accuracy model
            return "whisper-large-v3"
        }
    }

    /// Sends a multipart/form-data transcription request to Groq.
    private func sendTranscriptionRequest(
        wavData: Data,
        model: String,
        langCode: String?,
        apiKey: String,
        attempt: Int = 0
    ) async throws -> String {
        let boundary = UUID().uuidString
        var body = Data()

        // model field
        MultipartEncoder.appendFormField(to: &body, name: "model", value: model, boundary: boundary)

        // language field (optional)
        if let code = langCode {
            MultipartEncoder.appendFormField(to: &body, name: "language", value: code, boundary: boundary)
        }

        // context prompt (vocabulary hints, style guidance)
        if !contextPrompt.isEmpty {
            MultipartEncoder.appendFormField(to: &body, name: "prompt", value: contextPrompt, boundary: boundary)
        }

        // temperature 0 for most deterministic output
        MultipartEncoder.appendFormField(to: &body, name: "temperature", value: "0", boundary: boundary)

        // response_format field
        MultipartEncoder.appendFormField(to: &body, name: "response_format", value: "json", boundary: boundary)

        // audio file
        MultipartEncoder.appendFormFile(to: &body, name: "file", fileName: "recording.wav", contentType: "audio/wav", fileData: wavData, boundary: boundary)

        // closing boundary
        MultipartEncoder.closeBoundary(to: &body, boundary: boundary)

        var request = URLRequest(url: Self.baseURL)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WisprError.cloudAPIRequestFailed("Invalid response")
        }

        switch httpResponse.statusCode {
        case 200:
            let decoded = try JSONDecoder().decode(GroqTranscriptionResponse.self, from: data)
            return decoded.text

        case 429:
            // Rate limited — retry with backoff
            if attempt < Self.maxRetries {
                let delay = Double(attempt + 1) * 1.0
                Self.log.warning("Rate limited, retrying in \(delay)s (attempt \(attempt + 1))")
                try await Task.sleep(for: .seconds(delay))
                return try await sendTranscriptionRequest(
                    wavData: wavData,
                    model: model,
                    langCode: langCode,
                    apiKey: apiKey,
                    attempt: attempt + 1
                )
            }
            throw WisprError.cloudAPIRateLimited

        case 401:
            throw WisprError.cloudAPIKeyMissing

        default:
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            Self.log.error("Groq API error \(httpResponse.statusCode): \(errorBody)")
            throw WisprError.cloudAPIRequestFailed("HTTP \(httpResponse.statusCode): \(errorBody)")
        }
    }
}

// MARK: - Response Model

nonisolated private struct GroqTranscriptionResponse: Decodable, Sendable {
    let text: String
}

// MARK: - Multipart Helpers

private enum MultipartEncoder: Sendable {
    nonisolated static func appendFormField(to data: inout Data, name: String, value: String, boundary: String) {
        data.append(Data("--\(boundary)\r\n".utf8))
        data.append(Data("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".utf8))
        data.append(Data(value.utf8))
        data.append(Data("\r\n".utf8))
    }

    nonisolated static func appendFormFile(to data: inout Data, name: String, fileName: String, contentType: String, fileData: Data, boundary: String) {
        data.append(Data("--\(boundary)\r\n".utf8))
        data.append(Data("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(fileName)\"\r\n".utf8))
        data.append(Data("Content-Type: \(contentType)\r\n\r\n".utf8))
        data.append(fileData)
        data.append(Data("\r\n".utf8))
    }

    nonisolated static func closeBoundary(to data: inout Data, boundary: String) {
        data.append(Data("--\(boundary)--\r\n".utf8))
    }
}
