//
//  ChatTranscriptRecorderTests.swift
//  AIAssistantPOCTests
//

import Foundation
import Testing
@testable import AIAssistantPOC

private actor SpyWriter: ChatSessionWriting {
    private(set) var created: [(title: String, firstMessage: ChatMessage)] = []
    private(set) var appended: [(message: ChatMessage, sessionID: UUID)] = []
    private(set) var deleted: [UUID] = []
    private let stubID: UUID

    init(stubID: UUID = UUID()) { self.stubID = stubID }

    func createSession(title: String, firstMessage: ChatMessage) async throws -> UUID {
        created.append((title, firstMessage))
        return stubID
    }

    func append(_ message: ChatMessage, to sessionID: UUID) async throws {
        appended.append((message, sessionID))
    }

    func deleteSession(id: UUID) async throws {
        deleted.append(id)
    }
}

@Suite("ChatTranscriptRecorder")
struct ChatTranscriptRecorderTests {

    @Test("first user message creates a session titled with the first 20 characters")
    func firstUserMessageCreatesSession() async throws {
        // Given a fresh recorder
        let writer = SpyWriter()
        let sut = ChatTranscriptRecorder(writer: writer)
        let text = "This sentence is definitely longer than twenty characters"

        // When the first user message is recorded
        await sut.recordUserMessage(text)

        // Then a session is created with a 20-char title and the message preserved
        let created = await writer.created
        #expect(created.count == 1)
        #expect(created[0].title == String(text.prefix(20)))
        #expect(created[0].firstMessage.role == .user)
        #expect(created[0].firstMessage.text == text)
        #expect(await writer.appended.isEmpty)
    }

    @Test("assistant message after a user message appends to the same session")
    func assistantAppendsToSession() async throws {
        // Given a recorder with one user message recorded
        let stubID = UUID()
        let writer = SpyWriter(stubID: stubID)
        let sut = ChatTranscriptRecorder(writer: writer)
        await sut.recordUserMessage("hello")

        // When the assistant reply is recorded
        await sut.recordAssistantMessage("hi there")

        // Then it is appended to the created session
        let appended = await writer.appended
        #expect(appended.count == 1)
        #expect(appended[0].sessionID == stubID)
        #expect(appended[0].message.role == .assistant)
        #expect(appended[0].message.text == "hi there")
    }

    @Test("a second turn appends both messages without creating a new session")
    func secondTurnAppends() async throws {
        // Given a recorder mid-session
        let writer = SpyWriter()
        let sut = ChatTranscriptRecorder(writer: writer)
        await sut.recordUserMessage("u1")
        await sut.recordAssistantMessage("a1")

        // When a second turn runs
        await sut.recordUserMessage("u2")
        await sut.recordAssistantMessage("a2")

        // Then only one session was ever created and three appends followed
        #expect(await writer.created.count == 1)
        #expect(await writer.appended.count == 3)
    }

    @Test("an assistant message with no active session is dropped")
    func assistantWithoutSessionIsNoop() async throws {
        // Given a fresh recorder
        let writer = SpyWriter()
        let sut = ChatTranscriptRecorder(writer: writer)

        // When an assistant message arrives first
        await sut.recordAssistantMessage("orphan")

        // Then nothing is written
        #expect(await writer.created.isEmpty)
        #expect(await writer.appended.isEmpty)
    }

    @Test("beginNewSession forces the next user message to create a new session")
    func beginNewSessionResets() async throws {
        // Given a recorder with an active session
        let writer = SpyWriter()
        let sut = ChatTranscriptRecorder(writer: writer)
        await sut.recordUserMessage("u1")

        // When a new session begins and another user message is recorded
        await sut.beginNewSession()
        await sut.recordUserMessage("u2")

        // Then a second session is created
        #expect(await writer.created.count == 2)
    }

    @Test("resume routes subsequent messages to the resumed session id")
    func resumeAppendsToExistingSession() async throws {
        // Given a recorder resumed onto an existing session
        let existing = UUID()
        let writer = SpyWriter()
        let sut = ChatTranscriptRecorder(writer: writer)
        await sut.resume(sessionID: existing)

        // When a user message is recorded
        await sut.recordUserMessage("continue")

        // Then it appends to the resumed session rather than creating one
        #expect(await writer.created.isEmpty)
        let appended = await writer.appended
        #expect(appended.count == 1)
        #expect(appended[0].sessionID == existing)
    }
}
