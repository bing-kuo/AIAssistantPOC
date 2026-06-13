//
//  ChatHistoryUseCaseTests.swift
//  AIAssistantPOCTests
//
//  Covers FetchSessionSummaries / DeleteSession / LoadSession interactors.
//

import Foundation
import Testing
@testable import AIAssistantPOC

private actor SpyChatStore: ChatSessionReadRepository, ChatSessionWriteRepository {
    private let summariesResult: [ChatSessionSummary]
    private let sessionResult: ChatSession?
    private let throwsOnRead: Bool
    private(set) var deleted: [UUID] = []

    init(summaries: [ChatSessionSummary] = [], session: ChatSession? = nil, throwsOnRead: Bool = false) {
        self.summariesResult = summaries
        self.sessionResult = session
        self.throwsOnRead = throwsOnRead
    }

    func summaries() async throws -> [ChatSessionSummary] {
        if throwsOnRead { throw CancellationError() }
        return summariesResult
    }

    func session(id: UUID) async throws -> ChatSession? {
        if throwsOnRead { throw CancellationError() }
        return sessionResult
    }

    func createSession(title: String, firstMessage: ChatMessage) async throws -> UUID { UUID() }
    func append(_ message: ChatMessage, to sessionID: UUID) async throws {}
    func deleteSession(id: UUID) async throws { deleted.append(id) }
}

private func summary(_ title: String) -> ChatSessionSummary {
    ChatSessionSummary(id: UUID(), title: title, updatedAt: Date(timeIntervalSince1970: 0), lastMessagePreview: "p")
}

@MainActor
@Suite("FetchSessionSummariesInteractor")
struct FetchSessionSummariesInteractorTests {

    @Test("returns the summaries from the repository")
    func returnsSummaries() async {
        // Given a repository with two summaries
        let a = summary("A"); let b = summary("B")
        let sut = FetchSessionSummariesInteractor(repository: SpyChatStore(summaries: [a, b]))

        // When fetched
        let result = await sut()

        // Then both are returned in order
        #expect(result.map(\.id) == [a.id, b.id])
    }

    @Test("absorbs repository errors into an empty list")
    func absorbsErrors() async {
        // Given a repository that throws on read
        let sut = FetchSessionSummariesInteractor(repository: SpyChatStore(throwsOnRead: true))

        // When fetched
        let result = await sut()

        // Then the failure is absorbed to an empty list
        #expect(result.isEmpty)
    }
}

@MainActor
@Suite("DeleteSessionInteractor")
struct DeleteSessionInteractorTests {

    @Test("delegates the delete to the repository")
    func delegatesDelete() async {
        // Given a delete use case over a spy repository
        let store = SpyChatStore()
        let sut = DeleteSessionInteractor(repository: store)
        let id = UUID()

        // When invoked
        await sut(id)

        // Then the repository received the delete for that id
        #expect(await store.deleted == [id])
    }
}

@MainActor
@Suite("LoadSessionInteractor")
struct LoadSessionInteractorTests {

    @Test("returns the session from the repository")
    func returnsSession() async {
        // Given a repository holding one session
        let id = UUID()
        let session = ChatSession(
            id: id,
            title: "T",
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0),
            messages: []
        )
        let sut = LoadSessionInteractor(repository: SpyChatStore(session: session))

        // When loaded
        let result = await sut(id)

        // Then the session is returned
        #expect(result?.id == id)
    }

    @Test("absorbs repository errors into nil")
    func absorbsErrors() async {
        // Given a repository that throws on read
        let sut = LoadSessionInteractor(repository: SpyChatStore(throwsOnRead: true))

        // When loaded
        let result = await sut(UUID())

        // Then the failure is absorbed to nil
        #expect(result == nil)
    }
}
