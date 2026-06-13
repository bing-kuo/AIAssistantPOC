//
//  InMemoryConversationRepositoryTests.swift
//  AIAssistantPOCTests
//

import Foundation
import Testing
import VoiceAgentDomain
@testable import AIAssistantPOC

@MainActor
@Suite("InMemoryConversationRepository")
struct InMemoryConversationRepositoryTests {

    @Test("records each exchange as a user + assistant pair in order")
    func recordsExchanges() async {
        // Given a fresh repository
        let sut = InMemoryConversationRepository()

        // When two exchanges are recorded
        await sut.record(userMessage: "U1", assistantReply: "A1")
        await sut.record(userMessage: "U2", assistantReply: "A2")

        // Then the context preserves both turns in order
        let context = await sut.context()
        #expect(context.map(\.role) == [.user, .assistant, .user, .assistant])
        #expect(context.map(\.content) == ["U1", "A1", "U2", "A2"])
    }

    @Test("an empty assistant reply is not recorded")
    func skipsEmptyReply() async {
        // Given a fresh repository
        let sut = InMemoryConversationRepository()

        // When an exchange with an empty reply is recorded
        await sut.record(userMessage: "U1", assistantReply: "")

        // Then nothing is stored
        #expect(await sut.context().isEmpty)
    }

    @Test("caps history to the most recent turns")
    func capsHistory() async {
        // Given a cap of one turn (two messages)
        let sut = InMemoryConversationRepository(maxMessages: 2)

        // When three turns are recorded
        await sut.record(userMessage: "U1", assistantReply: "A1")
        await sut.record(userMessage: "U2", assistantReply: "A2")
        await sut.record(userMessage: "U3", assistantReply: "A3")

        // Then only the most recent turn survives
        let context = await sut.context()
        #expect(context.map(\.content) == ["U3", "A3"])
    }

    @Test("restore seeds prior turns as context")
    func restoreSeeds() async {
        // Given a fresh repository
        let sut = InMemoryConversationRepository()

        // When restored with one prior turn
        await sut.restore([
            LLMMessage(role: .user, content: "U1"),
            LLMMessage(role: .assistant, content: "A1"),
        ])

        // Then the context carries the restored turn
        let context = await sut.context()
        #expect(context.map(\.content) == ["U1", "A1"])
    }

    @Test("restore respects the history cap, dropping the oldest turns")
    func restoreRespectsCap() async {
        // Given a cap of one turn
        let sut = InMemoryConversationRepository(maxMessages: 2)

        // When restored with two turns
        await sut.restore([
            LLMMessage(role: .user, content: "OLD-U"),
            LLMMessage(role: .assistant, content: "OLD-A"),
            LLMMessage(role: .user, content: "NEW-U"),
            LLMMessage(role: .assistant, content: "NEW-A"),
        ])

        // Then only the most recent turn survives
        let context = await sut.context()
        #expect(context.map(\.content) == ["NEW-U", "NEW-A"])
    }

    @Test("reset clears the conversation history")
    func resetClears() async {
        // Given a repository with one recorded turn
        let sut = InMemoryConversationRepository()
        await sut.record(userMessage: "U1", assistantReply: "A1")

        // When reset
        await sut.reset()

        // Then the context is empty
        #expect(await sut.context().isEmpty)
    }
}
