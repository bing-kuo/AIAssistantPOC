//
//  LoadSessionInteractor.swift
//  AIAssistantPOC
//

import Foundation

struct LoadSessionInteractor: LoadSessionUseCase {

    private let repository: any ChatSessionReadRepository

    init(repository: any ChatSessionReadRepository) {
        self.repository = repository
    }

    func callAsFunction(_ id: UUID) async -> ChatSession? {
        try? await repository.session(id: id)
    }
}
