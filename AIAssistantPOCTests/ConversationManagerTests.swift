//
//  ConversationManagerTests.swift
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

@Suite("ConversationManager")
struct ConversationManagerTests {

    @Test("seeds the system prompt and accumulates prior turns into history")
    func accumulatesHistory() async throws {
        // Given
        let responder = RecordingResponder(deltas: ["A1"])
        let sut = ConversationManager(responder: responder, systemPrompt: "SYS")

        // When two turns run
        let reply = try await drain(sut.respond(to: "U1"))
        _ = try await drain(sut.respond(to: "U2"))

        // Then the second call carries system + the first full turn + the new user turn
        let messages = responder.lastMessages
        #expect(reply == "A1")
        #expect(messages.map(\.role) == [.system, .user, .assistant, .user])
        #expect(messages[0].content == "SYS")
        #expect(messages[1].content == "U1")
        #expect(messages[2].content == "A1")
        #expect(messages[3].content == "U2")
    }

    @Test("caps history to the most recent turns")
    func capsHistory() async throws {
        // Given a cap of one turn (two messages)
        let responder = RecordingResponder(deltas: ["A"])
        let sut = ConversationManager(responder: responder, systemPrompt: "SYS", maxMessages: 2)

        // When three turns run
        _ = try await drain(sut.respond(to: "U1"))
        _ = try await drain(sut.respond(to: "U2"))
        _ = try await drain(sut.respond(to: "U3"))

        // Then the oldest turn is dropped before the third call
        let messages = responder.lastMessages
        #expect(messages.map(\.role) == [.system, .user, .assistant, .user])
        #expect(messages[1].content == "U2")
        #expect(messages[3].content == "U3")
        #expect(!messages.contains { $0.content == "U1" })
    }

    @Test("reset clears the conversation history")
    func resetClears() async throws {
        // Given a conversation with one prior turn
        let responder = RecordingResponder(deltas: ["A"])
        let sut = ConversationManager(responder: responder, systemPrompt: "SYS")
        _ = try await drain(sut.respond(to: "U1"))

        // When reset then a new turn
        await sut.reset()
        _ = try await drain(sut.respond(to: "U2"))

        // Then history starts fresh
        let messages = responder.lastMessages
        #expect(messages.map(\.role) == [.system, .user])
        #expect(messages[1].content == "U2")
    }
}
