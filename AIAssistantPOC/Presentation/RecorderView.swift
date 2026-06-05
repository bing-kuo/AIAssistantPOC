//
//  RecorderView.swift
//  AIAssistantPOC
//
//  Created by Bing on 2026/6/5.
//

import SwiftUI
import VoiceIntelligence

struct RecorderView: View {
    @State private var viewModel: VoiceSessionViewModel

    init(viewModel: VoiceSessionViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: viewModel.state.symbolName)
                .font(.system(size: 72))
                .foregroundStyle(viewModel.state.tint)
                .symbolEffect(.pulse, isActive: viewModel.isActive)
                .contentTransition(.symbolEffect(.replace))

            Text(viewModel.state.localizationKey)
                .font(.headline)

            if case .result(let text) = viewModel.state {
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }

            ProgressView(value: Double(min(max(viewModel.lastRMS * 4, 0), 1)))
                .progressViewStyle(.linear)
                .tint(.green)
                .frame(maxWidth: 220)

            Button {
                Task { await viewModel.toggle() }
            } label: {
                Label(
                    viewModel.isActive ? "button.stopRecording" : "button.startRecording",
                    systemImage: viewModel.isActive ? "stop.fill" : "record.circle"
                )
                .frame(maxWidth: 220)
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.isActive ? .red : .accentColor)
        }
        .padding()
        .animation(.default, value: viewModel.state)
    }
}

extension SessionState {
    var localizationKey: LocalizedStringKey {
        switch self {
        case .idle: "status.idle"
        case .listening: "status.listening"
        case .speaking: "status.speaking"
        case .processing: "status.processing"
        case .result: "status.result"
        case .failed: "status.failed"
        }
    }

    var symbolName: String {
        switch self {
        case .idle: "mic.circle"
        case .listening: "ear.badge.waveform"
        case .speaking: "waveform.circle.fill"
        case .processing: "gearshape.circle.fill"
        case .result: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .idle: .accentColor
        case .listening: .blue
        case .speaking: .red
        case .processing: .orange
        case .result: .green
        case .failed: .yellow
        }
    }
}

#Preview {
    RecorderView(
        viewModel: VoiceSessionViewModel(
            recorder: PreviewAudioRecorder(),
            detector: SpeechEndpointDetector(scorer: SilentScorer()),
            pipeline: StubSpeechPipeline()
        )
    )
}
