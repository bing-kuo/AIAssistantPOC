//
//  DecimatorVADValidationTests.swift
//  VoiceIntelligenceTests
//

import AVFoundation
import Foundation
import Testing
@testable import VoiceCore
@testable import VoiceIntelligence

private final class Collector: @unchecked Sendable {
    var at16k: [Float] = []
    var at48k: [Float] = []
    var resumed = false
}

private final class Fed: @unchecked Sendable {
    let buffer: AVAudioPCMBuffer
    var done = false
    init(_ b: AVAudioPCMBuffer) { buffer = b }
}

@Suite("Decimator + VAD validation")
struct DecimatorVADValidationTests {

    private func convert(_ pcm: AVAudioPCMBuffer, to format: AVAudioFormat) -> [Float] {
        guard let converter = AVAudioConverter(from: pcm.format, to: format) else { return [] }
        let capacity = AVAudioFrameCount(Double(pcm.frameLength) * format.sampleRate / pcm.format.sampleRate) + 32
        guard let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return [] }
        let fed = Fed(pcm)
        converter.convert(to: out, error: nil) { _, status in
            if fed.done { status.pointee = .noDataNow; return nil }
            fed.done = true; status.pointee = .haveData; return fed.buffer
        }
        guard let ch = out.floatChannelData else { return [] }
        return Array(UnsafeBufferPointer(start: ch[0], count: Int(out.frameLength)))
    }

    private func maxProb(_ samples16k: [Float]) async throws -> Float {
        let vad = try SileroVAD()
        await vad.reset()
        var best: Float = 0
        var i = 0
        while i + 512 <= samples16k.count {
            best = max(best, try await vad.score(Array(samples16k[i..<i + 512])))
            i += 512
        }
        return best
    }

    @Test("FIR decimator preserves Silero response far better than AVAudioConverter")
    func decimatorPreservesSpeech() async throws {
        let synthesizer = AVSpeechSynthesizer()
        let utterance = AVSpeechUtterance(string: "Testing one two three. This is a speech sample for voice activity detection.")
        let f16 = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false)!
        let f48 = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48_000, channels: 1, interleaved: false)!
        let collector = Collector()

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            synthesizer.write(utterance) { buffer in
                guard let pcm = buffer as? AVAudioPCMBuffer else { return }
                if pcm.frameLength == 0 {
                    if !collector.resumed { collector.resumed = true; continuation.resume() }
                    return
                }
                collector.at16k.append(contentsOf: self.convert(pcm, to: f16))
                collector.at48k.append(contentsOf: self.convert(pcm, to: f48))
            }
        }

        let reference = try await maxProb(collector.at16k)

        var decimator = FIRDecimator(factor: 3, cutoffHz: 7_200, inputSampleRate: 48_000)
        let decimated = decimator.process(collector.at48k)
        let viaDecimator = try await maxProb(decimated)

        var streamingDecimator = FIRDecimator(factor: 3, cutoffHz: 7_200, inputSampleRate: 48_000)
        var streamed: [Float] = []
        var c = 0
        let chunkSize = 4_803
        while c < collector.at48k.count {
            let slice = Array(collector.at48k[c..<min(c + chunkSize, collector.at48k.count)])
            streamed.append(contentsOf: streamingDecimator.process(slice))
            c += chunkSize
        }
        let viaStreaming = try await maxProb(streamed)

        print("VALIDATION reference16k=\(reference) viaFIRDecimator=\(viaDecimator) viaStreaming=\(viaStreaming) decCount=\(decimated.count) streamCount=\(streamed.count)")

        #expect(reference > 0.8)
        #expect(viaDecimator > reference * 0.6)
        #expect(viaStreaming > reference * 0.6)
    }
}
