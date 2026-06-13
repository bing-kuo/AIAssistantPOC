//
//  SettingsView.swift
//  AIAssistantPOC
//

import SwiftUI

struct SettingsView: View {
    @State private var viewModel: SettingsViewModel

    init(viewModel: SettingsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Form {
            Section {
                Toggle("settings.voiceResponses", isOn: voiceResponsesBinding)
            } header: {
                Text("settings.section.general")
            }

            Section {
                LabeledContent("settings.server", value: viewModel.preferences.serverDisplayURL)
            }
        }
        .navigationTitle("settings.title")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }

    private var voiceResponsesBinding: Binding<Bool> {
        Binding(
            get: { viewModel.preferences.voiceResponsesEnabled },
            set: { isEnabled in Task { await viewModel.setVoiceResponses(isEnabled) } }
        )
    }
}
