//
//  AudioConverter.swift
//  wispr
//
//  Converts raw PCM Float32 audio samples to WAV format
//  for uploading to cloud transcription APIs.
//

import Foundation

enum AudioConverter: Sendable {

    /// Converts 16 kHz mono Float32 samples to a WAV file as `Data`.
    ///
    /// The Groq / OpenAI Whisper APIs accept WAV uploads directly.
    /// We encode as 16-bit PCM (Int16) which is universally supported
    /// and half the size of Float32 PCM.
    ///
    /// - Parameters:
    ///   - samples: Raw audio samples in Float32, range [-1.0, 1.0].
    ///   - sampleRate: Sample rate in Hz (default 16000, matching AudioEngine output).
    /// - Returns: A complete WAV file as `Data`.
    nonisolated static func wavData(from samples: [Float], sampleRate: Int = 16_000) -> Data {
        let numChannels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let bytesPerSample = bitsPerSample / 8
        let dataSize = UInt32(samples.count * Int(bytesPerSample))
        let fileSize = 36 + dataSize  // total file size minus 8 bytes for RIFF header

        var data = Data(capacity: 44 + Int(dataSize))

        // RIFF header
        data.append(contentsOf: "RIFF".utf8)
        data.append(littleEndian: fileSize)
        data.append(contentsOf: "WAVE".utf8)

        // fmt  sub-chunk
        data.append(contentsOf: "fmt ".utf8)
        data.append(littleEndian: UInt32(16))                          // sub-chunk size
        data.append(littleEndian: UInt16(1))                           // PCM format
        data.append(littleEndian: numChannels)
        data.append(littleEndian: UInt32(sampleRate))                  // sample rate
        let byteRate = UInt32(sampleRate) * UInt32(numChannels) * UInt32(bytesPerSample)
        data.append(littleEndian: byteRate)
        data.append(littleEndian: numChannels * bytesPerSample)        // block align
        data.append(littleEndian: bitsPerSample)

        // data sub-chunk
        data.append(contentsOf: "data".utf8)
        data.append(littleEndian: dataSize)

        // Convert Float32 samples → Int16 PCM
        for sample in samples {
            let clamped = max(-1.0, min(1.0, sample))
            let int16 = Int16(clamped * Float(Int16.max))
            data.append(littleEndian: int16)
        }

        return data
    }
}

// MARK: - Data Helpers

private extension Data {
    nonisolated mutating func append<T: FixedWidthInteger>(littleEndian value: T) {
        var le = value.littleEndian
        append(UnsafeBufferPointer(start: &le, count: 1))
    }
}
