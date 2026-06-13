//
//  PreviewSettings.swift
//  AIAssistantPOC
//

import SwiftUI

struct PreviewPreferencesStore: PreferencesReadRepository, PreferencesWriteRepository {
    func load() async -> AppPreferences {
        AppPreferences(voiceResponsesEnabled: true, serverDisplayURL: "http://192.168.0.35:8000")
    }

    func save(_ preferences: AppPreferences) async {}
}

extension SettingsViewModel {
    static func preview() -> SettingsViewModel {
        let store = PreviewPreferencesStore()
        return SettingsViewModel(
            fetchPreferences: FetchPreferencesInteractor(repository: store),
            updatePreferences: UpdatePreferencesInteractor(repository: store)
        )
    }
}

#Preview {
    NavigationStack {
        SettingsView(viewModel: .preview())
    }
}
