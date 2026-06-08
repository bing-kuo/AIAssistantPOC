//
//  FetchSessionSummariesInteractor.swift
//  AIAssistantPOC
//

import Foundation

struct FetchSessionSummariesInteractor: FetchSessionSummariesUseCase {

    private let repository: any ChatSessionReadRepository

    init(repository: any ChatSessionReadRepository) {
        self.repository = repository
    }

    func callAsFunction() async -> [ChatSessionSummary] {
        (try? await repository.summaries()) ?? []
    }
}
