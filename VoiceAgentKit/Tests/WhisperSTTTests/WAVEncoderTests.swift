//
//  WAVEncoderTests.swift
//  WhisperSTTTests
//

import Foundation
import Testing
@testable import WhisperSTT

@Suite("WAVEncoder")
struct WAVEncoderTests {

    private func ascii(_ data: Data, _ range: Range<Int>) -> String {
        String(decoding: data[range], as: UTF8.self)
    }

    private func uint32LE(_ data: Data, _ offset: Int) -> UInt32 {
        UInt32(data[offset]) | (UInt32(data[offset + 1]) << 8) | (UInt32(data[offset + 2]) << 16) | (UInt32(data[offset + 3]) << 24)
    }

    private func int16LE(_ data: Data, _ offset: Int) -> Int16 {
        Int16(bitPattern: UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8))
    }

    @Test("writes a valid RIFF/WAVE header with correct sizes")
    func headerIsValid() {
        // Given 100 mono samples at 16 kHz
        let samples = [Float](repeating: 0, count: 100)
        // When
        let data = WAVEncoder.encode(samples, sampleRate: 16_000)
        // Then
        #expect(data.count == 44 + 200)
        #expect(ascii(data, 0..<4) == "RIFF")
        #expect(ascii(data, 8..<12) == "WAVE")
        #expect(ascii(data, 12..<16) == "fmt ")
        #expect(ascii(data, 36..<40) == "data")
        #expect(uint32LE(data, 4) == UInt32(36 + 200))
        #expect(uint32LE(data, 24) == 16_000)
        #expect(uint32LE(data, 40) == 200)
    }

    @Test("scales full-scale samples to Int16 range")
    func scalesAmplitude() {
        // Given
        let samples: [Float] = [0, 1.0, -1.0, 0.5]
        // When
        let data = WAVEncoder.encode(samples, sampleRate: 16_000)
        // Then first PCM sample starts at byte 44
        #expect(int16LE(data, 44) == 0)
        #expect(int16LE(data, 46) == 32767)
        #expect(int16LE(data, 48) == -32767)
        #expect(abs(Int(int16LE(data, 50)) - 16383) <= 1)
    }

    @Test("clamps out-of-range samples")
    func clampsOverflow() {
        // Given values beyond [-1, 1]
        let samples: [Float] = [2.0, -2.0]
        // When
        let data = WAVEncoder.encode(samples, sampleRate: 16_000)
        // Then they saturate rather than overflow
        #expect(int16LE(data, 44) == 32767)
        #expect(int16LE(data, 46) == -32767)
    }
}
