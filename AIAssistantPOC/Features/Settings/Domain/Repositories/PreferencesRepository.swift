//
//  PreferencesRepository.swift
//  AIAssistantPOC
//

import Foundation

protocol PreferencesReadRepository: Sendable {
    func load() async -> AppPreferences
}

protocol PreferencesWriteRepository: Sendable {
    func save(_ preferences: AppPreferences) async
}
