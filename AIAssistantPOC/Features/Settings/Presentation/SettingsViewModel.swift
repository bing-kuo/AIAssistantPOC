//
//  SettingsViewModel.swift
//  AIAssistantPOC
//

import Foundation
import Observation

@MainActor
@Observable
final class SettingsViewModel {

    private let fetchPreferences: any FetchPreferencesUseCase
    private let updatePreferences: any UpdatePreferencesUseCase

    private(set) var preferences: AppPreferences = .default

    init(
        fetchPreferences: any FetchPreferencesUseCase,
        updatePreferences: any UpdatePreferencesUseCase
    ) {
        self.fetchPreferences = fetchPreferences
        self.updatePreferences = updatePreferences
    }

    func load() async {
        preferences = await fetchPreferences()
    }

    func setVoiceResponses(_ isEnabled: Bool) async {
        preferences.voiceResponsesEnabled = isEnabled
        await updatePreferences(preferences)
    }
}
