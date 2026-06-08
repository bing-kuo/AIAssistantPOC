//
//  TranscribeUtteranceInteractorTests.swift
//  AIAssistantPOCTests
//

import Foundation
import Testing
import VoiceAgentDomain
@testable import AIAssistantPOC

private final class SpyRecognizer: SpeechRecognizing, @unchecked Sendable {
    private let result: Transcription
    private let lock = NSLock()
    private var capturedSampleRate: Int?
    private var capturedCount: Int?

    init(result: Transcription) { self.result = result }

    func transcribe(_ audio: [Float], sampleRate: Int) async throws -> Transcription {
        lock.lock()
        capturedSampleRate = sampleRate
        capturedCount = audio.count
        lock.unlock()
        return result
    }

    var sampleRate: Int? { lock.lock(); defer { lock.unlock() }; return capturedSampleRate }
    var count: Int? { lock.lock(); defer { lock.unlock() }; return capturedCount }
}

@Suite("TranscribeUtteranceInteractor")
struct TranscribeUtteranceInteractorTests {

    @Test("passes the audio and sample rate to the recognizer and returns its text")
    func transcribes() async throws {
        // Given a recognizer returning a fixed transcription
        let recognizer = SpyRecognizer(result: Transcription(text: "HELLO", language: "en"))
        let sut = TranscribeUtteranceInteractor(recognizer: recognizer, sampleRate: 16_000)

        // When an utterance is transcribed
        let text = try await sut([0.1, -0.1, 0.2])

        // Then the recognizer receives the audio at the configured sample rate and the text is returned
        #expect(text == "HELLO")
        #expect(await recognizer.sampleRate == 16_000)
        #expect(await recognizer.count == 3)
    }
}
