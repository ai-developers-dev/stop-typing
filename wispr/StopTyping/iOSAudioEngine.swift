//
//  iOSAudioEngine.swift
//  StopTyping (iOS)
//
//  Audio capture for iOS using AVAudioRecorder (works in keyboard extensions).
//  AVAudioEngine doesn't work in keyboard extensions due to IO restrictions.
//  Records to a temp file, then reads samples back as [Float].
//

import AVFAudio
import Foundation

actor iOSAudioEngine {

    private var recorder: AVAudioRecorder?
    private var tempFileURL: URL?
    private var isCapturing = false

    /// Starts audio capture using AVAudioRecorder (keyboard-extension compatible).
    func startCapture() async throws -> AsyncStream<Float> {
        guard !isCapturing else {
            throw iOSAudioError.alreadyCapturing
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        // Create temp file for recording
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("st_recording_\(UUID().uuidString).wav")
        tempFileURL = fileURL

        // Record at 16kHz mono (matches Groq/Whisper expectations)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]

        let audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
        audioRecorder.isMeteringEnabled = true
        audioRecorder.record()

        self.recorder = audioRecorder
        isCapturing = true

        // Return a stream of audio levels for UI
        let (stream, continuation) = AsyncStream.makeStream(of: Float.self)

        // Poll meters on a timer
        Task {
            while self.isCapturing {
                audioRecorder.updateMeters()
                let level = audioRecorder.averagePower(forChannel: 0)
                // Convert dB to 0-1 range
                let normalizedLevel = max(0, (level + 50) / 50)
                continuation.yield(normalizedLevel)
                try? await Task.sleep(for: .milliseconds(100))
            }
            continuation.finish()
        }

        return stream
    }

    /// Stops capture and returns all accumulated audio samples as Float32 at 16kHz.
    func stopCapture() -> [Float] {
        recorder?.stop()
        recorder = nil
        isCapturing = false

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        guard let fileURL = tempFileURL else { return [] }
        defer {
            try? FileManager.default.removeItem(at: fileURL)
            tempFileURL = nil
        }

        // Read the WAV file and convert Int16 samples to Float32
        guard let data = try? Data(contentsOf: fileURL) else { return [] }

        // Skip 44-byte WAV header
        guard data.count > 44 else { return [] }
        let pcmData = data.dropFirst(44)

        // Convert Int16 PCM to Float32
        var samples: [Float] = []
        samples.reserveCapacity(pcmData.count / 2)

        pcmData.withUnsafeBytes { buffer in
            let int16Buffer = buffer.bindMemory(to: Int16.self)
            for sample in int16Buffer {
                samples.append(Float(sample) / Float(Int16.max))
            }
        }

        return samples
    }

    /// Stops capture and returns the raw WAV file data directly.
    /// Use this to send to Groq API without double-conversion.
    func stopCaptureAsWavData() -> Data? {
        recorder?.stop()
        recorder = nil
        isCapturing = false

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        guard let fileURL = tempFileURL else { return nil }
        defer {
            try? FileManager.default.removeItem(at: fileURL)
            tempFileURL = nil
        }

        return try? Data(contentsOf: fileURL)
    }

    enum iOSAudioError: Error, LocalizedError {
        case alreadyCapturing
        case formatError
        case converterError

        var errorDescription: String? {
            switch self {
            case .alreadyCapturing: return "Audio capture is already in progress"
            case .formatError: return "Failed to create audio format"
            case .converterError: return "Failed to create audio converter"
            }
        }
    }
}
