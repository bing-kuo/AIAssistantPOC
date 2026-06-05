//
//  RecorderView.swift
//  AIAssistantPOC
//
//  Created by Bing on 2026/6/5.
//

import SwiftUI

struct RecorderView: View {
    @State private var viewModel: RecorderViewModel

    init(viewModel: RecorderViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: viewModel.isRecording ? "waveform.circle.fill" : "mic.circle")
                .font(.system(size: 72))
                .foregroundStyle(viewModel.isRecording ? Color.red : Color.accentColor)
                .symbolEffect(.pulse, isActive: viewModel.isRecording)

            Text(viewModel.status.localizationKey)
                .font(.headline)

            ProgressView(value: Double(min(max(viewModel.lastRMS * 4, 0), 1)))
                .progressViewStyle(.linear)
                .tint(.green)
                .frame(maxWidth: 220)

            Button {
                Task { await viewModel.toggle() }
            } label: {
                Label(
                    viewModel.isRecording ? "button.stopRecording" : "button.startRecording",
                    systemImage: viewModel.isRecording ? "stop.fill" : "record.circle"
                )
                .frame(maxWidth: 220)
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.isRecording ? .red : .accentColor)
        }
        .padding()
    }
}

extension RecorderStatus {
    var localizationKey: LocalizedStringKey {
        switch self {
        case .idle: "status.idle"
        case .recording: "status.recording"
        case .stopped: "status.stopped"
        case .permissionDenied: "status.permissionDenied"
        case .failed: "status.failed"
        }
    }
}

#Preview {
    RecorderView(viewModel: RecorderViewModel(recorder: PreviewAudioRecorder()))
}
