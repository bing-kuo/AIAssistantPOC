//
//  AudioMathTests.swift
//  AVAudioCaptureTests
//

import Testing
@testable import AVAudioCapture

@Suite("AudioMath.rms")
struct AudioMathTests {

    @Test("empty buffer yields zero")
    func emptyBufferIsZero() {
        // Given
        let samples: [Float] = []
        // When
        let rms = AudioMath.rms(samples)
        // Then
        #expect(rms == 0)
    }

    @Test("silence yields zero")
    func silenceIsZero() {
        // Given
        let samples = [Float](repeating: 0, count: 1024)
        // When
        let rms = AudioMath.rms(samples)
        // Then
        #expect(rms == 0)
    }

    @Test("DC signal RMS equals its amplitude")
    func dcSignalEqualsAmplitude() {
        // Given a constant +0.5 signal, RMS == 0.5
        let samples = [Float](repeating: 0.5, count: 256)
        // When
        let rms = AudioMath.rms(samples)
        // Then
        #expect(abs(rms - 0.5) < 0.0001)
    }

    @Test("full-scale square wave RMS equals 1.0")
    func squareWaveIsOne() {
        // Given alternating ±1.0 samples
        let samples: [Float] = (0..<512).map { $0.isMultiple(of: 2) ? 1.0 : -1.0 }
        // When
        let rms = AudioMath.rms(samples)
        // Then RMS of ±1 is sqrt(mean(1)) == 1
        #expect(abs(rms - 1.0) < 0.0001)
    }
}
