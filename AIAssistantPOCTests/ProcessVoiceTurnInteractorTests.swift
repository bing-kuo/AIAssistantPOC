//
//  ProcessVoiceTurnInteractorTests.swift
//  AIAssistantPOCTests
//

import Foundation
import Testing
import VoiceAgentDomain
@testable import AIAssistantPOC

private struct StubTranscribe: TranscribeUtteranceUseCase {
    let text: String
    func callAsFunction(_ audio: [Float]) async throws -> String { text }
}

private struct StubGenerateReply: GenerateReplyUseCase {
    let deltas: [String]
    func callAsFunction(_ userText: String) -> AsyncThrowingStream<String, Error> {
        let deltas = deltas
        return AsyncThrowingStream { continuation in
            for delta in deltas { continuation.yield(delta) }
            continuation.finish()
        }
    }
}

private actor SpySynthesizer: SpeechSynthesizing {
    private(set) var spokenText: String?
    private(set) var stopCount = 0
    func speak(_ text: String) async throws { spokenText = text }
    func stop() async { stopCount += 1 }
}

private actor SpyTranscript: ChatTranscriptRecording {
    private(set) var userMessages: [String] = []
    private(set) var assistantMessages: [String] = []
    func beginNewSession() {}
    func resume(sessionID: UUID) {}
    func recordUserMessage(_ text: String) { userMessages.append(text) }
    func recordAssistantMessage(_ text: String) { assistantMessages.append(text) }
}

private func collect(_ stream: AsyncThrowingStream<VoiceTurnEvent, Error>) async throws -> [VoiceTurnEvent] {
    var events: [VoiceTurnEvent] = []
    for try await event in stream { events.append(event) }
    return events
}

@Suite("ProcessVoiceTurnInteractor")
struct ProcessVoiceTurnInteractorTests {

    @Test("emits no events and persists nothing when the utterance transcribes to empty")
    func emptyUtterance() async throws {
        // Given a turn whose transcription is empty
        let synthesizer = SpySynthesizer()
        let transcript = SpyTranscript()
        let sut = ProcessVoiceTurnInteractor(
            transcribe: StubTranscribe(text: ""),
            generateReply: StubGenerateReply(deltas: ["unused"]),
            synthesizer: synthesizer,
            transcript: transcript
        )

        // When the turn runs
        let events = try await collect(sut([0.1, 0.2]))

        // Then nothing is emitted, recorded, or spoken
        #expect(events.isEmpty)
        #expect(await transcript.userMessages.isEmpty)
        #expect(await transcript.assistantMessages.isEmpty)
        #expect(await synthesizer.spokenText == nil)
    }

    @Test("a full turn emits the transcript, reply deltas, completion, and speaking in order")
    func fullTurn() async throws {
        // Given a turn that transcribes then streams a two-delta reply
        let synthesizer = SpySynthesizer()
        let transcript = SpyTranscript()
        let sut = ProcessVoiceTurnInteractor(
            transcribe: StubTranscribe(text: "HELLO"),
            generateReply: StubGenerateReply(deltas: ["Hi", " there"]),
            synthesizer: synthesizer,
            transcript: transcript
        )

        // When the turn runs to completion
        let events = try await collect(sut([0.2, 0.2]))

        // Then the event sequence is well-formed
        #expect(events == [
            .userTranscribed("HELLO"),
            .replyDelta("Hi"),
            .replyDelta(" there"),
            .replyCompleted("Hi there"),
            .speaking,
        ])

        // And both sides are persisted and the full reply is spoken
        #expect(await transcript.userMessages == ["HELLO"])
        #expect(await transcript.assistantMessages == ["Hi there"])
        #expect(await synthesizer.spokenText == "Hi there")
    }

    @Test("an empty reply records the user turn but does not speak")
    func emptyReply() async throws {
        // Given a turn that transcribes but the model returns nothing
        let synthesizer = SpySynthesizer()
        let transcript = SpyTranscript()
        let sut = ProcessVoiceTurnInteractor(
            transcribe: StubTranscribe(text: "HELLO"),
            generateReply: StubGenerateReply(deltas: []),
            synthesizer: synthesizer,
            transcript: transcript
        )

        // When the turn runs
        let events = try await collect(sut([0.2, 0.2]))

        // Then the user turn is recorded, completion is emitted empty, and nothing is spoken
        #expect(events == [.userTranscribed("HELLO"), .replyCompleted("")])
        #expect(await transcript.userMessages == ["HELLO"])
        #expect(await transcript.assistantMessages.isEmpty)
        #expect(await synthesizer.spokenText == nil)
    }
}
