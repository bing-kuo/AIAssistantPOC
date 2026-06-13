//
//  GenerateReplyInteractorTests.swift
//  AIAssistantPOCTests
//

import Foundation
import Testing
import VoiceAgentDomain
@testable import AIAssistantPOC

private final class RecordingResponder: LLMResponding, @unchecked Sendable {
    private let deltas: [String]
    private let lock = NSLock()
    private var captured: [LLMMessage] = []

    init(deltas: [String]) { self.deltas = deltas }

    func stream(_ messages: [LLMMessage]) -> AsyncThrowingStream<String, Error> {
        lock.lock()
        captured = messages
        lock.unlock()
        let deltas = deltas
        return AsyncThrowingStream { continuation in
            for delta in deltas { continuation.yield(delta) }
            continuation.finish()
        }
    }

    var lastMessages: [LLMMessage] {
        lock.lock(); defer { lock.unlock() }
        return captured
    }
}

private func drain(_ stream: AsyncThrowingStream<String, Error>) async throws -> String {
    var accumulated = ""
    for try await delta in stream { accumulated += delta }
    return accumulated
}

@MainActor
@Suite("GenerateReplyInteractor")
struct GenerateReplyInteractorTests {

    @Test("seeds the system prompt and streams the reply deltas")
    func seedsSystemAndStreams() async throws {
        // Given a fresh conversation and a responder scripting two deltas
        let responder = RecordingResponder(deltas: ["Hi", " there"])
        let repo = InMemoryConversationRepository()
        let sut = GenerateReplyInteractor(responder: responder, conversation: repo, systemPrompt: "SYS")

        // When a turn runs
        let reply = try await drain(sut("U1"))

        // Then the LLM call is seeded with system + the new user turn, and deltas concatenate
        let messages = responder.lastMessages
        #expect(reply == "Hi there")
        #expect(messages.map(\.role) == [.system, .user])
        #expect(messages[0].content == "SYS")
        #expect(messages[1].content == "U1")
    }

    @Test("carries prior turns from the repository into the next call as context")
    func carriesContext() async throws {
        // Given a conversation that has already had one turn
        let responder = RecordingResponder(deltas: ["A1"])
        let repo = InMemoryConversationRepository()
        let sut = GenerateReplyInteractor(responder: responder, conversation: repo, systemPrompt: "SYS")
        _ = try await drain(sut("U1"))

        // When a second turn runs
        _ = try await drain(sut("U2"))

        // Then the second call carries system + the first full turn + the new user turn
        let messages = responder.lastMessages
        #expect(messages.map(\.role) == [.system, .user, .assistant, .user])
        #expect(messages.map(\.content) == ["SYS", "U1", "A1", "U2"])
    }

    @Test("persists the completed exchange back into the repository")
    func persistsExchange() async throws {
        // Given a fresh conversation
        let responder = RecordingResponder(deltas: ["A1"])
        let repo = InMemoryConversationRepository()
        let sut = GenerateReplyInteractor(responder: responder, conversation: repo, systemPrompt: "SYS")

        // When a turn completes
        _ = try await drain(sut("U1"))

        // Then the repository holds the recorded turn
        let context = await repo.context()
        #expect(context.map(\.content) == ["U1", "A1"])
    }
}
