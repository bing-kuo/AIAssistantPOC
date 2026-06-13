//
//  SessionListViewModelTests.swift
//  AIAssistantPOCTests
//

import Foundation
import Testing
@testable import AIAssistantPOC

private actor MockChatStore: ChatSessionReadRepository, ChatSessionWriteRepository {
    private var stored: [ChatSessionSummary]
    private let sessions: [UUID: ChatSession]
    private(set) var deleted: [UUID] = []

    init(summaries: [ChatSessionSummary] = [], sessions: [ChatSession] = []) {
        self.stored = summaries
        self.sessions = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })
    }

    func summaries() async throws -> [ChatSessionSummary] { stored }
    func session(id: UUID) async throws -> ChatSession? { sessions[id] }
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

    private func makeViewModel(_ store: MockChatStore) -> SessionListViewModel {
        SessionListViewModel(
            fetchSummaries: FetchSessionSummariesInteractor(repository: store),
            deleteSession: DeleteSessionInteractor(repository: store),
            loadSession: LoadSessionInteractor(repository: store)
        )
    }

    @Test("load publishes the summaries returned by the fetch use case")
    func loadPublishesSummaries() async {
        // Given two stored summaries
        let a = summary(title: "A")
        let b = summary(title: "B")
        let sut = makeViewModel(MockChatStore(summaries: [a, b]))

        // When loading
        await sut.load()

        // Then both are published
        #expect(sut.summaries.map(\.id) == [a.id, b.id])
    }

    @Test("delete removes the session through the delete use case and reloads")
    func deleteRemovesAndReloads() async {
        // Given a loaded list of two
        let a = summary(title: "A")
        let b = summary(title: "B")
        let store = MockChatStore(summaries: [a, b])
        let sut = makeViewModel(store)
        await sut.load()

        // When one is deleted
        await sut.delete(id: a.id)

        // Then the store was asked and the reloaded list no longer contains it
        #expect(await store.deleted == [a.id])
        #expect(sut.summaries.map(\.id) == [b.id])
    }

    @Test("an empty store yields an empty list")
    func emptyStays() async {
        // Given an empty store
        let sut = makeViewModel(MockChatStore(summaries: []))

        // When loading
        await sut.load()

        // Then the list is empty
        #expect(sut.summaries.isEmpty)
    }

    @Test("resolve returns the full session for a known id")
    func resolveReturnsSession() async {
        // Given a store holding a session
        let id = UUID()
        let session = ChatSession(
            id: id,
            title: "T",
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0),
            messages: [ChatMessage(role: .assistant, text: "hi")]
        )
        let sut = makeViewModel(MockChatStore(sessions: [session]))

        // When resolving its id
        let resolved = await sut.resolve(id)

        // Then the full session is returned
        #expect(resolved?.id == id)
    }

    @Test("resolve returns nil for an unknown id")
    func resolveUnknownReturnsNil() async {
        // Given a store with no sessions
        let sut = makeViewModel(MockChatStore())

        // When resolving an unknown id
        let resolved = await sut.resolve(UUID())

        // Then nothing is returned
        #expect(resolved == nil)
    }
}
