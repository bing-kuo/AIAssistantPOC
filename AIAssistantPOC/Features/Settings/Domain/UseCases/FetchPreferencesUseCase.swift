//
//  FetchPreferencesUseCase.swift
//  AIAssistantPOC
//

import Foundation

protocol FetchPreferencesUseCase: Sendable {
    func callAsFunction() async -> AppPreferences
}

struct FetchPreferencesInteractor: FetchPreferencesUseCase {
    private let repository: any PreferencesReadRepository

    init(repository: any PreferencesReadRepository) {
        self.repository = repository
    }

    func callAsFunction() async -> AppPreferences {
        await repository.load()
    }
}
