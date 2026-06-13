//
//  UserDefaultsPreferencesStore.swift
//  AIAssistantPOC
//

import Foundation

nonisolated struct UserDefaultsPreferencesStore: PreferencesReadRepository, PreferencesWriteRepository {
    private nonisolated(unsafe) let defaults: UserDefaults
    private let serverDisplayURL: String
    private let voiceResponsesKey = "settings.voiceResponsesEnabled"

    init(defaults: UserDefaults = .standard, serverDisplayURL: String) {
        self.defaults = defaults
        self.serverDisplayURL = serverDisplayURL
    }

    func load() async -> AppPreferences {
        let enabled = defaults.object(forKey: voiceResponsesKey) as? Bool ?? true
        return AppPreferences(voiceResponsesEnabled: enabled, serverDisplayURL: serverDisplayURL)
    }

    func save(_ preferences: AppPreferences) async {
        defaults.set(preferences.voiceResponsesEnabled, forKey: voiceResponsesKey)
    }
}
