//
//  AudioProbe.swift
//  VoiceAgentDomain
//

import Foundation

/// A snapshot of the loudness characteristics of a block of PCM samples.
public struct AudioProbeStats: Sendable, Equatable {

    /// Root-mean-square amplitude across the block.
    public let rms: Float

    /// The largest absolute sample value in the block.
    public let peak: Float

    /// Peak amplitude expressed in decibels relative to full scale (`0 dBFS` == `1.0`).
    public let dBFS: Float

    /// The number of samples analysed.
    public let sampleCount: Int

    /// The block duration in seconds for the given sample rate.
    public let durationSeconds: Double

    /// A single-line, log-friendly summary of the statistics.
    public var description: String {
        String(
            format: "rms=%.5f peak=%.5f dBFS=%.1f samples=%d duration=%.2fs",
            rms, peak, dBFS, sampleCount, durationSeconds
        )
    }
}

/// Diagnostic helper for measuring and exporting audio at pipeline boundaries.
///
/// Pure Foundation so it can be shared by every layer without coupling the Domain
/// to audio frameworks. All measurement sites must gate on ``isEnabled`` so the
/// probe is a no-op unless explicitly switched on for an investigation.
public enum AudioProbe {

    /// Whether diagnostic measurement and WAV export are active.
    ///
    /// Enabled by setting the `AUDIO_DIAG=1` environment variable on the run scheme.
    public static var isEnabled: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.environment["AUDIO_DIAG"] == "1"
        #else
        return false
        #endif
    }

    /// Computes loudness statistics for a block of mono Float32 samples.
    /// - Parameters:
    ///   - samples: Mono Float32 PCM samples, nominally in `-1.0...1.0`.
    ///   - sampleRate: The sample rate the block was captured at, in Hz.
    /// - Returns: The measured ``AudioProbeStats``.
    public static func analyze(_ samples: [Float], sampleRate: Int) -> AudioProbeStats {
        guard !samples.isEmpty else {
            return AudioProbeStats(rms: 0, peak: 0, dBFS: -.infinity, sampleCount: 0, durationSeconds: 0)
        }

        var sumOfSquares: Float = 0
        var peak: Float = 0
        for sample in samples {
            sumOfSquares += sample * sample
            let magnitude = abs(sample)
            if magnitude > peak { peak = magnitude }
        }

        let rms = (sumOfSquares / Float(samples.count)).squareRoot()
        let dBFS = peak > 0 ? 20 * log10(peak) : -.infinity
        let duration = sampleRate > 0 ? Double(samples.count) / Double(sampleRate) : 0

        return AudioProbeStats(
            rms: rms,
            peak: peak,
            dBFS: dBFS,
            sampleCount: samples.count,
            durationSeconds: duration
        )
    }

    /// Writes the samples to a timestamped 16-bit PCM WAV file under the diagnostics directory.
    /// - Parameters:
    ///   - samples: Mono Float32 samples in `-1.0...1.0`.
    ///   - sampleRate: Sample rate in Hz, written into the WAV header.
    ///   - label: A short prefix identifying the pipeline stage (e.g. `"capture_16k"`).
    /// - Returns: The file URL on success, or `nil` if the directory or file could not be written.
    @discardableResult
    public static func dumpWAV(_ samples: [Float], sampleRate: Int, label: String) -> URL? {
        #if DEBUG
        guard !samples.isEmpty, let directory = diagnosticsDirectory() else { return nil }

        pruneDiagnostics(in: directory, keeping: maxRetainedFiles)

        let timestamp = Date().timeIntervalSince1970
        let fileName = String(format: "%@_%.3f.wav", label, timestamp)
        let url = directory.appendingPathComponent(fileName)

        do {
            try encodeWAV(samples, sampleRate: sampleRate).write(to: url)
            return url
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }

    #if DEBUG
    private static let maxRetainedFiles = 40

    private static func pruneDiagnostics(in directory: URL, keeping limit: Int) {
        let manager = FileManager.default
        guard let files = try? manager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let wavFiles = files.filter { $0.pathExtension == "wav" }
        guard wavFiles.count >= limit else { return }

        let sorted = wavFiles.sorted { lhs, rhs in
            let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return lhsDate < rhsDate
        }

        for file in sorted.prefix(wavFiles.count - limit + 1) {
            try? manager.removeItem(at: file)
        }
    }

    private static func diagnosticsDirectory() -> URL? {
        guard let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let directory = base.appendingPathComponent("AudioDiagnostics", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory
        } catch {
            return nil
        }
    }

    static func encodeWAV(_ samples: [Float], sampleRate: Int) -> Data {
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
    #endif
}
