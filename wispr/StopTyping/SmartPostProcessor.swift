//
//  SmartPostProcessor.swift
//  wispr
//
//  LLM-based post-processing for transcribed text.
//  Uses Groq's Llama model to fix punctuation, apply self-corrections,
//  and remove filler words. Falls back to basic cleanup if the LLM call fails.
//

import Foundation
import os

actor SmartPostProcessor {

    private static let log = Logger(subsystem: "com.stopTyping", category: "SmartPostProcessor")

    /// Groq chat completions endpoint (same API key as Whisper).
    private static let chatURL = URL(string: "https://api.groq.com/openai/v1/chat/completions")!

    /// Fast, high-quality model for text cleanup.
    private static let model = "llama-3.3-70b-versatile"

    /// System prompt that teaches the LLM how to clean up dictated text.
    private static let systemPrompt = """
    You are a voice dictation post-processor. Clean up the following spoken text:
    1. If the speaker corrects themselves (e.g. "2 pairs, no I mean 3 pairs"), apply the correction and output only the corrected version ("3 pairs"). Remove the original wrong part entirely.
    2. Detect correction phrases like: "no, I mean", "actually", "sorry, I meant", "wait", "scratch that", "I meant to say", "correction", "let me rephrase".
    3. Add proper punctuation: commas, periods, question marks, exclamation points.
    4. Fix capitalization at the start of sentences.
    5. Remove filler words like "um", "uh", "like", "you know", "so basically" (unless they add meaning to the sentence).
    6. Do NOT change the meaning or add words that weren't spoken.
    7. Do NOT add any explanations, notes, or commentary.
    8. Return ONLY the cleaned text.
    """

    private let apiKeyProvider: @Sendable () -> String?

    init(apiKeyProvider: @escaping @Sendable () -> String?) {
        self.apiKeyProvider = apiKeyProvider
    }

    /// Processes raw transcription through the LLM for cleanup.
    /// Falls back to basic post-processing if the LLM call fails.
    func process(_ rawText: String) async -> String {
        // Skip LLM for very short text (not worth the latency)
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count < 5 {
            return basicCleanup(trimmed)
        }

        guard let apiKey = apiKeyProvider() else {
            Self.log.warning("No API key available, falling back to basic cleanup")
            return basicCleanup(trimmed)
        }

        do {
            let cleaned = try await callLLM(text: trimmed, apiKey: apiKey)
            Self.log.info("Smart post-processing: \(trimmed.count) chars → \(cleaned.count) chars")
            return cleaned
        } catch {
            Self.log.error("LLM post-processing failed: \(error.localizedDescription), using basic cleanup")
            return basicCleanup(trimmed)
        }
    }

    // MARK: - LLM Call

    private func callLLM(text: String, apiKey: String) async throws -> String {
        let requestBody: [String: Any] = [
            "model": Self.model,
            "messages": [
                ["role": "system", "content": Self.systemPrompt],
                ["role": "user", "content": text],
            ],
            "temperature": 0.1,
            "max_tokens": 1024,
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)

        var request = URLRequest(url: Self.chatURL)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw PostProcessingError.apiError
        }

        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content else {
            throw PostProcessingError.emptyResponse
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Basic Cleanup (fallback)

    nonisolated func basicCleanup(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.isEmpty { return result }

        // Collapse multiple spaces
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }

        // Capitalize first letter
        if let first = result.first, first.isLowercase {
            result = first.uppercased() + result.dropFirst()
        }

        // Ensure ending punctuation
        if let last = result.last, !".!?".contains(last) {
            result += "."
        }

        return result
    }

    // MARK: - Types

    enum PostProcessingError: Error {
        case apiError
        case emptyResponse
    }
}

// MARK: - Response Models

nonisolated private struct ChatResponse: Decodable, Sendable {
    let choices: [Choice]
}

nonisolated private struct Choice: Decodable, Sendable {
    let message: Message
}

nonisolated private struct Message: Decodable, Sendable {
    let content: String
}
