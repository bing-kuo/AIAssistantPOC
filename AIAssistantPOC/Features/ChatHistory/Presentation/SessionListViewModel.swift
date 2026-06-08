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

    private(set) var summaries: [ChatSessionSummary] = []

    init(fetchSummaries: any FetchSessionSummariesUseCase, deleteSession: any DeleteSessionUseCase) {
        self.fetchSummaries = fetchSummaries
        self.deleteSession = deleteSession
    }

    func load() async {
        summaries = await fetchSummaries()
    }

    func delete(id: UUID) async {
        await deleteSession(id)
        await load()
    }
}
