//
//  AudioDownsampler.swift
//  VoiceCore
//

import AVFoundation

final class AudioDownsampler: @unchecked Sendable {

    private final class ConversionInput: @unchecked Sendable {
        let buffer: AVAudioPCMBuffer
        var consumed = false
        init(buffer: AVAudioPCMBuffer) { self.buffer = buffer }
    }

    private let targetSampleRate: Double
    private var decimator: FIRDecimator?

    private let converter: AVAudioConverter?
    private let targetFormat: AVAudioFormat

    init?(inputFormat: AVAudioFormat, targetSampleRate: Double) {
        guard inputFormat.sampleRate > 0,
              let targetFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: targetSampleRate,
                channels: 1,
                interleaved: false
              )
        else { return nil }

        self.targetSampleRate = targetSampleRate
        self.targetFormat = targetFormat

        let ratio = inputFormat.sampleRate / targetSampleRate
        let integerFactor = Int(ratio.rounded())
        let isIntegerRatio = integerFactor >= 2 && abs(ratio - Double(integerFactor)) < 0.001

        VoiceLog.session.info("AudioDownsampler input format: channels=\(inputFormat.channelCount, privacy: .public), interleaved=\(inputFormat.isInterleaved, privacy: .public), commonFormat=\(inputFormat.commonFormat.rawValue, privacy: .public), rate=\(inputFormat.sampleRate, privacy: .public)")

        if isIntegerRatio {
            let cutoff = targetSampleRate * 0.45
            self.decimator = FIRDecimator(factor: integerFactor, cutoffHz: cutoff, inputSampleRate: inputFormat.sampleRate)
            self.converter = nil
            VoiceLog.session.info("AudioDownsampler: FIR integer decimation, factor=\(integerFactor, privacy: .public), inputRate=\(inputFormat.sampleRate, privacy: .public)")
        } else {
            guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else { return nil }
            converter.sampleRateConverterQuality = .max
            converter.sampleRateConverterAlgorithm = AVSampleRateConverterAlgorithm_Mastering
            self.converter = converter
            self.decimator = nil
            VoiceLog.session.info("AudioDownsampler: AVAudioConverter fallback, inputRate=\(inputFormat.sampleRate, privacy: .public)")
        }
    }

    func downsample(_ buffer: AVAudioPCMBuffer) -> [Float]? {
        if decimator != nil {
            return decimate(buffer)
        }
        return convert(buffer)
    }

    private func decimate(_ buffer: AVAudioPCMBuffer) -> [Float]? {
        guard let channel = buffer.floatChannelData else { return convert(buffer) }
        let input = Array(UnsafeBufferPointer(start: channel[0], count: Int(buffer.frameLength)))
        guard !input.isEmpty else { return nil }
        let output = decimator?.process(input) ?? []
        return output.isEmpty ? nil : output
    }

    private func convert(_ buffer: AVAudioPCMBuffer) -> [Float]? {
        guard let converter else { return nil }
        let ratio = targetSampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 16
        guard capacity > 0,
              let output = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity)
        else { return nil }

        let input = ConversionInput(buffer: buffer)
        let inputBlock: AVAudioConverterInputBlock = { _, statusPointer in
            if input.consumed {
                statusPointer.pointee = .noDataNow
                return nil
            }
            input.consumed = true
            statusPointer.pointee = .haveData
            return input.buffer
        }

        var conversionError: NSError?
        let status = converter.convert(to: output, error: &conversionError, withInputFrom: inputBlock)
        guard status != .error, let channel = output.floatChannelData else { return nil }

        let count = Int(output.frameLength)
        guard count > 0 else { return nil }
        return Array(UnsafeBufferPointer(start: channel[0], count: count))
    }
}
