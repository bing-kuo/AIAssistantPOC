//
//  DiagnosticCaptureSink.swift
//  AVAudioCapture
//

import Foundation
import VoiceAgentDomain

/// Accumulates raw and downsampled capture audio for offline inspection.
///
/// The audio tap runs on a real-time render thread outside the recorder actor, so
/// access is guarded by a lock rather than actor isolation, mirroring `AudioDownsampler`.
final class DiagnosticCaptureSink: @unchecked Sendable {

    private let lock = NSLock()
    private var raw: [Float] = []
    private var downsampled: [Float] = []
    private var framedSampleCount = 0
    private let hardwareSampleRate: Double
    private let targetSampleRate: Double

    init(hardwareSampleRate: Double, targetSampleRate: Double) {
        self.hardwareSampleRate = hardwareSampleRate
        self.targetSampleRate = targetSampleRate
    }

    func appendRaw(_ samples: [Float]) {
        lock.lock()
        raw.append(contentsOf: samples)
        lock.unlock()
    }

    func appendDownsampled(_ samples: [Float], rms: Float) {
        lock.lock()
        downsampled.append(contentsOf: samples)
        framedSampleCount += samples.count
        let shouldLog = Double(framedSampleCount) >= targetSampleRate
        if shouldLog { framedSampleCount = 0 }
        lock.unlock()

        if shouldLog {
            VoiceLog.recorder.info("Capture level rms=\(rms, privacy: .public)")
        }
    }

    func flush() {
        lock.lock()
        let rawCopy = raw
        let downsampledCopy = downsampled
        raw.removeAll()
        downsampled.removeAll()
        framedSampleCount = 0
        lock.unlock()

        let rawRate = Int(hardwareSampleRate.rounded())
        let rawStats = AudioProbe.analyze(rawCopy, sampleRate: rawRate)
        let downsampledStats = AudioProbe.analyze(downsampledCopy, sampleRate: Int(targetSampleRate))

        VoiceLog.recorder.info("Capture raw \(rawStats.description, privacy: .public)")
        VoiceLog.recorder.info("Capture 16k \(downsampledStats.description, privacy: .public)")

        if let url = AudioProbe.dumpWAV(rawCopy, sampleRate: rawRate, label: "capture_raw_\(rawRate)") {
            VoiceLog.recorder.info("Capture raw WAV written: \(url.lastPathComponent, privacy: .public)")
        }
        if let url = AudioProbe.dumpWAV(downsampledCopy, sampleRate: Int(targetSampleRate), label: "capture_16k") {
            VoiceLog.recorder.info("Capture 16k WAV written: \(url.lastPathComponent, privacy: .public)")
        }
    }
}
