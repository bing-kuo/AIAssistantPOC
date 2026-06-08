//
//  SessionListViewModelTests.swift
//  AIAssistantPOCTests
//

import Foundation
import Testing
@testable import AIAssistantPOC

private actor MockChatStore: ChatSessionReading, ChatSessionWriting {
    private var stored: [ChatSessionSummary]
    private(set) var deleted: [UUID] = []

    init(summaries: [ChatSessionSummary] = []) { self.stored = summaries }

    func summaries() async throws -> [ChatSessionSummary] { stored }
    func session(id: UUID) async throws -> ChatSession? { nil }
    func createSession(title: String, firstMessage: ChatMessage) async throws -> UUID { UUID() }
    func append(_ message: ChatMessage, to sessionID: UUID) async throws {}

    func deleteSession(id: UUID) async throws {
        deleted.append(id)
        stored.removeAll { $0.id == id }
    }
}

private func summary(id: UUID = UUID(), title: String = "T", at seconds: TimeInterval = 0) -> ChatSessionSummary {
    ChatSessionSummary(id: id, title: title, updatedAt: Date(timeIntervalSince1970: seconds), lastMessagePreview: "preview")
}

@MainActor
@Suite("SessionListViewModel")
struct SessionListViewModelTests {

    @Test("load publishes the summaries returned by the reader")
    func loadPublishesSummaries() async {
        // Given two stored summaries
        let a = summary(title: "A")
        let b = summary(title: "B")
        let store = MockChatStore(summaries: [a, b])
        let sut = SessionListViewModel(reading: store, writing: store)

        // When loading
        await sut.load()

        // Then both are published
        #expect(sut.summaries.map(\.id) == [a.id, b.id])
    }

    @Test("delete removes the session through the writer and reloads")
    func deleteRemovesAndReloads() async {
        // Given a loaded list of two
        let a = summary(title: "A")
        let b = summary(title: "B")
        let store = MockChatStore(summaries: [a, b])
        let sut = SessionListViewModel(reading: store, writing: store)
        await sut.load()

        // When one is deleted
        await sut.delete(id: a.id)

        // Then the writer was asked and the reloaded list no longer contains it
        #expect(await store.deleted == [a.id])
        #expect(sut.summaries.map(\.id) == [b.id])
    }

    @Test("an empty store yields an empty list")
    func emptyStays() async {
        // Given an empty store
        let store = MockChatStore(summaries: [])
        let sut = SessionListViewModel(reading: store, writing: store)

        // When loading
        await sut.load()

        // Then the list is empty
        #expect(sut.summaries.isEmpty)
    }
}
