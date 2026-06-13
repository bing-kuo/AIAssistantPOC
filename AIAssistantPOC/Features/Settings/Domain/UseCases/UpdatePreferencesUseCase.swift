//
//  UpdatePreferencesUseCase.swift
//  AIAssistantPOC
//

import Foundation

protocol UpdatePreferencesUseCase: Sendable {
    func callAsFunction(_ preferences: AppPreferences) async
}

struct UpdatePreferencesInteractor: UpdatePreferencesUseCase {
    private let repository: any PreferencesWriteRepository

    init(repository: any PreferencesWriteRepository) {
        self.repository = repository
    }

    func callAsFunction(_ preferences: AppPreferences) async {
        await repository.save(preferences)
    }
}
