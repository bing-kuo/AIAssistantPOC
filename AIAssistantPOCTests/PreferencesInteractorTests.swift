//
//  PreferencesInteractorTests.swift
//  AIAssistantPOCTests
//

import Foundation
import Testing
@testable import AIAssistantPOC

private actor StubPreferencesStore: PreferencesReadRepository, PreferencesWriteRepository {
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
@Suite("Preferences use cases")
struct PreferencesInteractorTests {

    @Test("fetch returns the repository's preferences")
    func fetchReturnsStored() async {
        // Given a stored preference
        let store = StubPreferencesStore(AppPreferences(voiceResponsesEnabled: true, serverDisplayURL: "host"))
        let sut = FetchPreferencesInteractor(repository: store)

        // When fetching
        let result = await sut()

        // Then the stored value is returned
        #expect(result.voiceResponsesEnabled == true)
        #expect(result.serverDisplayURL == "host")
    }

    @Test("update forwards the preferences to the repository")
    func updateSaves() async {
        // Given an interactor over a store
        let store = StubPreferencesStore(.default)
        let sut = UpdatePreferencesInteractor(repository: store)
        let updated = AppPreferences(voiceResponsesEnabled: false, serverDisplayURL: "host")

        // When updating
        await sut(updated)

        // Then the repository received the new value
        #expect(await store.saved == [updated])
    }
}
