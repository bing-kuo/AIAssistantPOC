//
//  SwiftDataChatStoreTests.swift
//  AIAssistantPOCTests
//

import Foundation
import SwiftData
import Testing
@testable import AIAssistantPOC

@MainActor
@Suite("SwiftDataChatStore")
struct SwiftDataChatStoreTests {

    private func makeStore() throws -> SwiftDataChatStore {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: SessionRecord.self, configurations: configuration)
        return SwiftDataChatStore(modelContainer: container)
    }

    @Test("createSession surfaces a summary carrying the title and a 40-char preview")
    func createSurfacesSummary() async throws {
        // Given a store and a long first message
        let store = try makeStore()
        let longText = String(repeating: "A", count: 60)
        let first = ChatMessage(role: .user, text: longText, createdAt: Date(timeIntervalSince1970: 0))

        // When a session is created
        _ = try await store.createSession(title: "My Title", firstMessage: first)

        // Then a single summary exposes the title and a preview truncated to 40 characters
        let summaries = try await store.summaries()
        #expect(summaries.count == 1)
        #expect(summaries[0].title == "My Title")
        #expect(summaries[0].lastMessagePreview == String(repeating: "A", count: 40))
    }

    @Test("append bumps updatedAt so the touched session sorts to the top")
    func appendReordersByUpdatedAt() async throws {
        // Given two sessions created at increasing times
        let store = try makeStore()
        let idA = try await store.createSession(
            title: "A",
            firstMessage: ChatMessage(role: .user, text: "a", createdAt: Date(timeIntervalSince1970: 0))
        )
        let idB = try await store.createSession(
            title: "B",
            firstMessage: ChatMessage(role: .user, text: "b", createdAt: Date(timeIntervalSince1970: 10))
        )

        // Then B (newer) is first
        let initial = try await store.summaries()
        #expect(initial.map(\.id) == [idB, idA])

        // When a message is appended to A at a later time
        try await store.append(
            ChatMessage(role: .assistant, text: "a-reply", createdAt: Date(timeIntervalSince1970: 20)),
            to: idA
        )

        // Then A moves to the top and its preview reflects the latest message
        let reordered = try await store.summaries()
        #expect(reordered.map(\.id) == [idA, idB])
        #expect(reordered[0].lastMessagePreview == "a-reply")
    }

    @Test("session(id:) returns the full transcript ordered by creation time")
    func sessionReturnsOrderedMessages() async throws {
        // Given a session with a user turn then an assistant turn
        let store = try makeStore()
        let id = try await store.createSession(
            title: "T",
            firstMessage: ChatMessage(role: .user, text: "hi", createdAt: Date(timeIntervalSince1970: 0))
        )
        try await store.append(
            ChatMessage(role: .assistant, text: "hello", createdAt: Date(timeIntervalSince1970: 5)),
            to: id
        )

        // When the full session is loaded
        let session = try await store.session(id: id)

        // Then the messages are ordered and mapped to domain roles
        #expect(session?.messages.map(\.role) == [.user, .assistant])
        #expect(session?.messages.map(\.text) == ["hi", "hello"])
    }

    @Test("deleteSession removes the session and cascades its messages")
    func deleteCascades() async throws {
        // Given a session with messages
        let store = try makeStore()
        let id = try await store.createSession(
            title: "T",
            firstMessage: ChatMessage(role: .user, text: "hi", createdAt: Date(timeIntervalSince1970: 0))
        )

        // When the session is deleted
        try await store.deleteSession(id: id)

        // Then it is gone
        #expect(try await store.summaries().isEmpty)
        #expect(try await store.session(id: id) == nil)
    }
}
