//
//  SpeechEndpointDetectorTests.swift
//  VoiceIntelligenceTests
//

import Testing
@testable import VoiceIntelligence

private actor ScriptedScorer: SpeechProbabilityScoring {
    private let probabilities: [Float]
    private var index = 0
    private(set) var resetCount = 0

    init(_ probabilities: [Float]) {
        self.probabilities = probabilities
    }

    func score(_ window: [Float]) async throws -> Float {
        defer { index += 1 }
        return index < probabilities.count ? probabilities[index] : 0
    }

    func reset() async {
        resetCount += 1
    }
}

private func window(_ value: Float, size: Int = 512) -> [Float] {
    [Float](repeating: value, count: size)
}

private func collect(_ stream: AsyncStream<VADEvent>) async -> [VADEvent] {
    var events: [VADEvent] = []
    for await event in stream { events.append(event) }
    return events
}

@Suite("SpeechEndpointDetector")
struct SpeechEndpointDetectorTests {

    private func fastConfiguration() -> VADConfiguration {
        VADConfiguration(
            sampleRate: 16_000,
            windowSize: 512,
            speechThreshold: 0.5,
            silenceThreshold: 0.35,
            minSilenceDurationMs: 64,
            minSpeechDurationMs: 32,
            speechPadMs: 0
        )
    }

    @Test("emits speechStarted then speechEnded across a speech-to-silence transition")
    func detectsStartAndEndpoint() async {
        // Given a window of speech followed by sustained silence
        let scorer = ScriptedScorer([0.9, 0.1, 0.1])
        let sut = SpeechEndpointDetector(scorer: scorer, configuration: fastConfiguration())
        let input = AsyncStream<[Float]> { continuation in
            continuation.yield(window(0.5))
            continuation.yield(window(0.0))
            continuation.yield(window(0.0))
            continuation.finish()
        }

        // When
        let events = await collect(sut.events(from: input))

        // Then
        #expect(events.count == 2)
        #expect(events.first == .speechStarted)
        if case .speechEnded(let segment) = events.last {
            #expect(!segment.isEmpty)
        } else {
            Issue.record("Expected speechEnded as the final event")
        }
    }

    @Test("does not emit speechEnded while speech is ongoing")
    func noEndpointWhileSpeaking() async {
        // Given continuous speech with no trailing silence
        let scorer = ScriptedScorer([0.9, 0.8, 0.95])
        let sut = SpeechEndpointDetector(scorer: scorer, configuration: fastConfiguration())
        let input = AsyncStream<[Float]> { continuation in
            for _ in 0..<3 { continuation.yield(window(0.5)) }
            continuation.finish()
        }

        // When
        let events = await collect(sut.events(from: input))

        // Then
        #expect(events == [.speechStarted])
    }

    @Test("ignores a brief blip shorter than the minimum speech duration")
    func debouncesShortBlip() async {
        // Given a single high window then silence, below minSpeechDuration of two windows
        let config = VADConfiguration(
            sampleRate: 16_000,
            windowSize: 512,
            speechThreshold: 0.5,
            silenceThreshold: 0.35,
            minSilenceDurationMs: 64,
            minSpeechDurationMs: 64,
            speechPadMs: 0
        )
        let scorer = ScriptedScorer([0.9, 0.0, 0.0])
        let sut = SpeechEndpointDetector(scorer: scorer, configuration: config)
        let input = AsyncStream<[Float]> { continuation in
            continuation.yield(window(0.5))
            continuation.yield(window(0.0))
            continuation.yield(window(0.0))
            continuation.finish()
        }

        // When
        let events = await collect(sut.events(from: input))

        // Then
        #expect(events.isEmpty)
    }

    @Test("reset clears state and resets the scorer")
    func resetForwardsToScorer() async {
        // Given
        let scorer = ScriptedScorer([])
        let sut = SpeechEndpointDetector(scorer: scorer, configuration: fastConfiguration())

        // When
        await sut.reset()

        // Then
        #expect(await scorer.resetCount == 1)
    }
}
