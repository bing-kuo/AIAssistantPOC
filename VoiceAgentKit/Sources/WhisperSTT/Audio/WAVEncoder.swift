//
//  WAVEncoder.swift
//  WhisperSTT
//

import Foundation

/// Encodes mono Float32 PCM samples into a 16-bit PCM WAV container.
///
/// Pure Foundation (no AVFoundation) so the networking layer stays dependency-free.
public enum WAVEncoder {

    /// Produces a complete WAV file (44-byte header + little-endian Int16 PCM).
    /// - Parameters:
    ///   - samples: Mono Float32 samples in `-1.0...1.0`.
    ///   - sampleRate: Sample rate in Hz.
    public static func encode(_ samples: [Float], sampleRate: Int) -> Data {
        let numChannels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let bytesPerSample = UInt32(bitsPerSample / 8)
        let byteRate = UInt32(sampleRate) * UInt32(numChannels) * bytesPerSample
        let blockAlign = numChannels * UInt16(bytesPerSample)
        let dataSize = UInt32(samples.count) * bytesPerSample

        var data = Data()
        data.reserveCapacity(44 + Int(dataSize))

        func appendASCII(_ string: String) { data.append(contentsOf: Array(string.utf8)) }
        func appendUInt32LE(_ value: UInt32) {
            data.append(UInt8(value & 0xFF))
            data.append(UInt8((value >> 8) & 0xFF))
            data.append(UInt8((value >> 16) & 0xFF))
            data.append(UInt8((value >> 24) & 0xFF))
        }
        func appendUInt16LE(_ value: UInt16) {
            data.append(UInt8(value & 0xFF))
            data.append(UInt8((value >> 8) & 0xFF))
        }

        appendASCII("RIFF")
        appendUInt32LE(36 + dataSize)
        appendASCII("WAVE")

        appendASCII("fmt ")
        appendUInt32LE(16)
        appendUInt16LE(1)
        appendUInt16LE(numChannels)
        appendUInt32LE(UInt32(sampleRate))
        appendUInt32LE(byteRate)
        appendUInt16LE(blockAlign)
        appendUInt16LE(bitsPerSample)

        appendASCII("data")
        appendUInt32LE(dataSize)

        for sample in samples {
            let clamped = max(-1.0, min(1.0, sample))
            let scaled = Int16(clamped * 32767)
            appendUInt16LE(UInt16(bitPattern: scaled))
        }

        return data
    }
}
