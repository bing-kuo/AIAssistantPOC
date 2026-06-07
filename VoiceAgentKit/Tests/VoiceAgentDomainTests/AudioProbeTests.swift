//
//  AudioProbeTests.swift
//  VoiceAgentDomainTests
//

import Testing
import Foundation
@testable import VoiceAgentDomain

@Suite("AudioProbe.analyze")
struct AudioProbeAnalyzeTests {

    @Test("Empty samples report zero loudness and negative-infinity dBFS")
    func emptyBlockReportsSilence() {
        let stats = AudioProbe.analyze([], sampleRate: 16_000)

        #expect(stats.rms == 0)
        #expect(stats.peak == 0)
        #expect(stats.dBFS == -.infinity)
        #expect(stats.sampleCount == 0)
        #expect(stats.durationSeconds == 0)
    }

    @Test("Silence reports zero rms and peak")
    func silenceReportsZero() {
        let samples = [Float](repeating: 0, count: 16_000)

        let stats = AudioProbe.analyze(samples, sampleRate: 16_000)

        #expect(stats.rms == 0)
        #expect(stats.peak == 0)
    }

    @Test("Full-scale square wave peaks at 0 dBFS with unit rms")
    func fullScaleReportsZeroDBFS() {
        let samples: [Float] = [1, -1, 1, -1, 1, -1, 1, -1]

        let stats = AudioProbe.analyze(samples, sampleRate: 8)

        #expect(stats.peak == 1)
        #expect(abs(stats.rms - 1) < 0.0001)
        #expect(abs(stats.dBFS - 0) < 0.01)
    }

    @Test("Half-scale square wave reports approximately -6 dBFS")
    func halfScaleReportsMinusSixDBFS() {
        let samples: [Float] = [0.5, -0.5, 0.5, -0.5]

        let stats = AudioProbe.analyze(samples, sampleRate: 4)

        #expect(stats.peak == 0.5)
        #expect(abs(stats.dBFS - (-6.02)) < 0.1)
    }

    @Test("Duration equals sample count over sample rate")
    func durationMatchesSampleCountOverRate() {
        let samples = [Float](repeating: 0.1, count: 8_000)

        let stats = AudioProbe.analyze(samples, sampleRate: 16_000)

        #expect(abs(stats.durationSeconds - 0.5) < 0.0001)
        #expect(stats.sampleCount == 8_000)
    }
}

@Suite("AudioProbe WAV encoding")
struct AudioProbeWAVTests {

    @Test("Header carries RIFF/WAVE/fmt/data marker chunks")
    func headerHasCanonicalChunks() {
        let data = AudioProbe.encodeWAV([0, 0.5, -0.5], sampleRate: 16_000)

        #expect(ascii(data, 0, 4) == "RIFF")
        #expect(ascii(data, 8, 4) == "WAVE")
        #expect(ascii(data, 12, 4) == "fmt ")
        #expect(ascii(data, 36, 4) == "data")
    }

    @Test("Header encodes mono 16-bit PCM at the requested sample rate")
    func headerEncodesFormatFields() {
        let data = AudioProbe.encodeWAV([0, 0, 0], sampleRate: 16_000)

        #expect(uint16LE(data, 20) == 1)
        #expect(uint16LE(data, 22) == 1)
        #expect(uint32LE(data, 24) == 16_000)
        #expect(uint16LE(data, 34) == 16)
    }

    @Test("Data size equals sample count times two bytes")
    func dataSizeMatchesSampleCount() {
        let samples = [Float](repeating: 0.25, count: 100)

        let data = AudioProbe.encodeWAV(samples, sampleRate: 16_000)

        #expect(uint32LE(data, 40) == 200)
        #expect(data.count == 44 + 200)
    }

    private func ascii(_ data: Data, _ offset: Int, _ length: Int) -> String {
        String(bytes: data[data.startIndex + offset ..< data.startIndex + offset + length], encoding: .ascii) ?? ""
    }

    private func uint16LE(_ data: Data, _ offset: Int) -> UInt16 {
        let base = data.startIndex + offset
        return UInt16(data[base]) | (UInt16(data[base + 1]) << 8)
    }

    private func uint32LE(_ data: Data, _ offset: Int) -> UInt32 {
        let base = data.startIndex + offset
        return UInt32(data[base])
            | (UInt32(data[base + 1]) << 8)
            | (UInt32(data[base + 2]) << 16)
            | (UInt32(data[base + 3]) << 24)
    }
}
