//
//  SessionListViewModel.swift
//  AIAssistantPOC
//

import Foundation
import Observation

@MainActor
@Observable
final class SessionListViewModel {

    private let fetchSummaries: any FetchSessionSummariesUseCase
    private let deleteSession: any DeleteSessionUseCase
    private let loadSession: any LoadSessionUseCase

    private(set) var summaries: [ChatSessionSummary] = []

    init(
        fetchSummaries: any FetchSessionSummariesUseCase,
        deleteSession: any DeleteSessionUseCase,
        loadSession: any LoadSessionUseCase
    ) {
        self.fetchSummaries = fetchSummaries
        self.deleteSession = deleteSession
        self.loadSession = loadSession
    }

    func load() async {
        summaries = await fetchSummaries()
    }

    func delete(id: UUID) async {
        await deleteSession(id)
        await load()
    }

    func resolve(_ id: UUID) async -> ChatSession? {
        await loadSession(id)
    }
}
