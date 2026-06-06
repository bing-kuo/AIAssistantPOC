//
//  FIRDecimatorTests.swift
//  AVAudioCaptureTests
//

import Foundation
import Testing
@testable import AVAudioCapture

@Suite("FIRDecimator")
struct FIRDecimatorTests {

    private func tone(frequency: Double, sampleRate: Double, count: Int) -> [Float] {
        (0..<count).map { Float(sin(2 * Double.pi * frequency * Double($0) / sampleRate)) }
    }

    private func rms(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        var sum: Float = 0
        for s in samples { sum += s * s }
        return (sum / Float(samples.count)).squareRoot()
    }

    @Test("decimates 48k to 16k preserving sample count ratio")
    func decimatesByThree() {
        // Given
        var sut = FIRDecimator(factor: 3, cutoffHz: 7200, inputSampleRate: 48_000)
        // When
        let output = sut.process(tone(frequency: 1_000, sampleRate: 48_000, count: 4_800))
        // Then output is roughly one third of the input
        #expect(abs(output.count - 1_600) <= 2)
    }

    @Test("passband tone (1 kHz) survives decimation")
    func passbandPreserved() {
        // Given a 1 kHz tone, well below the 8 kHz post-decimation Nyquist
        var sut = FIRDecimator(factor: 3, cutoffHz: 7200, inputSampleRate: 48_000)
        let input = tone(frequency: 1_000, sampleRate: 48_000, count: 9_600)
        // When
        let output = sut.process(input)
        // Then amplitude is preserved (input sine rms ~0.707)
        #expect(abs(rms(output) - 0.707) < 0.05)
    }

    @Test("out-of-band tone (11 kHz) is rejected, not aliased")
    func aliasRejected() {
        // Given an 11 kHz tone that would alias to 5 kHz if not filtered
        var sut = FIRDecimator(factor: 3, cutoffHz: 7200, inputSampleRate: 48_000)
        let input = tone(frequency: 11_000, sampleRate: 48_000, count: 9_600)
        // When
        let output = sut.process(input)
        // Then it is heavily attenuated
        #expect(rms(output) < 0.1)
    }
}
