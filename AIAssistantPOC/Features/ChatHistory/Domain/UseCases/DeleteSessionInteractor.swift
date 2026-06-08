//
//  DeleteSessionInteractor.swift
//  AIAssistantPOC
//

import Foundation

struct DeleteSessionInteractor: DeleteSessionUseCase {

    private let repository: any ChatSessionWriteRepository

    init(repository: any ChatSessionWriteRepository) {
        self.repository = repository
    }

    func callAsFunction(_ id: UUID) async {
        try? await repository.deleteSession(id: id)
    }
}
