//
//  ConversationLifecycleInteractorTests.swift
//  AIAssistantPOCTests
//
//  Covers StartNewConversationInteractor and ResumeConversationInteractor.
//

import Foundation
import Testing
import VoiceAgentDomain
@testable import AIAssistantPOC

private actor SpyConversationRepository: ConversationRepository {
    private(set) var resetCount = 0
    private(set) var restored: [[LLMMessage]] = []
    func context() -> [LLMMessage] { [] }
    func record(userMessage: String, assistantReply: String) {}
    func restore(_ messages: [LLMMessage]) { restored.append(messages) }
    func reset() { resetCount += 1 }
}

private actor SpyTranscript: ChatTranscriptRepository {
    private(set) var beganNewCount = 0
    private(set) var resumed: [UUID] = []
    func beginNewSession() { beganNewCount += 1 }
    func resume(sessionID: UUID) { resumed.append(sessionID) }
    func recordUserMessage(_ text: String) {}
    func recordAssistantMessage(_ text: String) {}
}

@MainActor
@Suite("StartNewConversationInteractor")
struct StartNewConversationInteractorTests {

    @Test("resets the conversation repository and begins a new transcript session")
    func startsFresh() async {
        // Given a start-new use case over spy collaborators
        let repo = SpyConversationRepository()
        let transcript = SpyTranscript()
        let sut = StartNewConversationInteractor(conversation: repo, transcript: transcript)

        // When a new conversation is started
        await sut()

        // Then both the history and the transcript session are reset
        #expect(await repo.resetCount == 1)
        #expect(await transcript.beganNewCount == 1)
    }
}

@MainActor
@Suite("ResumeConversationInteractor")
struct ResumeConversationInteractorTests {

    @Test("restores prior turns as LLM context and points the transcript at the session")
    func resumes() async {
        // Given a recorded session with one full turn
        let repo = SpyConversationRepository()
        let transcript = SpyTranscript()
        let sut = ResumeConversationInteractor(conversation: repo, transcript: transcript)
        let id = UUID()
        let session = ChatSession(
            id: id,
            title: "Earlier",
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 10),
            messages: [
                ChatMessage(role: .user, text: "Q", createdAt: Date(timeIntervalSince1970: 0)),
                ChatMessage(role: .assistant, text: "A", createdAt: Date(timeIntervalSince1970: 5)),
            ]
        )

        // When the session is resumed
        await sut(session)

        // Then the history is restored with mapped roles and the transcript points at the session
        let restored = await repo.restored
        #expect(restored.count == 1)
        #expect(restored[0].map(\.role) == [.user, .assistant])
        #expect(restored[0].map(\.content) == ["Q", "A"])
        #expect(await transcript.resumed == [id])
    }
}
