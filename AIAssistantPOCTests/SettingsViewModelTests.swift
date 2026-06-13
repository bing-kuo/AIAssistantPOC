//
//  SettingsViewModelTests.swift
//  AIAssistantPOCTests
//

import Foundation
import Testing
@testable import AIAssistantPOC

private actor MockPreferencesStore: PreferencesReadRepository, PreferencesWriteRepository {
    private var stored: AppPreferences
    private(set) var saved: [AppPreferences] = []

    init(_ initial: AppPreferences) { self.stored = initial }

    func load() async -> AppPreferences { stored }

    func save(_ preferences: AppPreferences) async {
        saved.append(preferences)
        stored = preferences
    }
}

@MainActor
@Suite("SettingsViewModel")
struct SettingsViewModelTests {

    private func makeViewModel(_ store: MockPreferencesStore) -> SettingsViewModel {
        SettingsViewModel(
            fetchPreferences: FetchPreferencesInteractor(repository: store),
            updatePreferences: UpdatePreferencesInteractor(repository: store)
        )
    }

    @Test("load publishes the stored preferences")
    func loadPublishes() async {
        // Given a store with voice responses disabled
        let store = MockPreferencesStore(AppPreferences(voiceResponsesEnabled: false, serverDisplayURL: "host"))
        let sut = makeViewModel(store)

        // When loading
        await sut.load()

        // Then the published preferences match the store
        #expect(sut.preferences.voiceResponsesEnabled == false)
        #expect(sut.preferences.serverDisplayURL == "host")
    }

    @Test("toggling voice responses updates state and persists")
    func setVoiceResponsesPersists() async {
        // Given loaded preferences with the toggle off
        let store = MockPreferencesStore(AppPreferences(voiceResponsesEnabled: false, serverDisplayURL: "host"))
        let sut = makeViewModel(store)
        await sut.load()

        // When voice responses is enabled
        await sut.setVoiceResponses(true)

        // Then the state flips and the change is saved
        #expect(sut.preferences.voiceResponsesEnabled == true)
        #expect(await store.saved.last?.voiceResponsesEnabled == true)
    }
}
