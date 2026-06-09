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

private actor ScriptedRecognizer: SpeechRecognizing {
    private var errors: [SpeechRecognitionError]
    private let success: Transcription
    private(set) var calls = 0

    init(failuresBeforeSuccess errors: [SpeechRecognitionError], success: Transcription) {
        self.errors = errors
        self.success = success
    }

    func transcribe(_ audio: [Float], sampleRate: Int) async throws -> Transcription {
        calls += 1
        if !errors.isEmpty { throw errors.removeFirst() }
        return success
    }
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

    @Test("retries once on a transport error then returns the text")
    func retriesOnTransport() async throws {
        // Given a recognizer that fails once with a transport error, then succeeds
        let recognizer = ScriptedRecognizer(
            failuresBeforeSuccess: [.transport("local network blocked")],
            success: Transcription(text: "HELLO")
        )
        let sut = TranscribeUtteranceInteractor(recognizer: recognizer)

        // When transcribing
        let text = try await sut([0.1])

        // Then it retried once and returned the text
        #expect(text == "HELLO")
        #expect(await recognizer.calls == 2)
    }

    @Test("does not retry on a non-transport error")
    func doesNotRetryOnServerError() async {
        // Given a recognizer that fails with a server error
        let recognizer = ScriptedRecognizer(
            failuresBeforeSuccess: [.server(status: 500), .server(status: 500)],
            success: Transcription(text: "HELLO")
        )
        let sut = TranscribeUtteranceInteractor(recognizer: recognizer)

        // When transcribing, the server error propagates without a retry
        await #expect(throws: SpeechRecognitionError.self) { try await sut([0.1]) }
        #expect(await recognizer.calls == 1)
    }
}
