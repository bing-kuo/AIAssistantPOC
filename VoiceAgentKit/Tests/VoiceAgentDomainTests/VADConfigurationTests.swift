//
//  VADConfigurationTests.swift
//  VoiceAgentDomainTests
//

import Testing
@testable import VoiceAgentDomain

@Suite("VADConfiguration")
struct VADConfigurationTests {

    @Test("windowDurationMs reflects window size over sample rate")
    func windowDurationMatchesWindowOverSampleRate() {
        let configuration = VADConfiguration(sampleRate: 16_000, windowSize: 512)

        #expect(configuration.windowDurationMs == 512.0 / 16_000.0 * 1_000)
    }

    @Test("windowDurationMs is zero when sample rate is non-positive")
    func windowDurationIsZeroForInvalidSampleRate() {
        let configuration = VADConfiguration(sampleRate: 0, windowSize: 512)

        #expect(configuration.windowDurationMs == 0)
    }
}
