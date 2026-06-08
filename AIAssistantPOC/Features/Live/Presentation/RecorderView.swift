//
//  RecorderView.swift
//  AIAssistantPOC
//
//  Created by Bing on 2026/6/5.
//

import SwiftUI
import VoiceAgentDomain

struct RecorderView: View {
    @State private var viewModel: VoiceSessionViewModel

    init(viewModel: VoiceSessionViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    private static let bottomAnchor = "transcript.bottom"

    var body: some View {
        VStack(spacing: 0) {
            transcript
            footer
        }
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message)
                    }
                    Color.clear
                        .frame(height: 1)
                        .id(Self.bottomAnchor)
                }
                .padding()
            }
            .overlay {
                if viewModel.messages.isEmpty {
                    ContentUnavailableView("live.empty", systemImage: "waveform.and.mic")
                }
            }
            .onChange(of: viewModel.messages.last?.id) {
                scrollToBottom(proxy)
            }
            .onChange(of: viewModel.messages.last?.text) {
                scrollToBottom(proxy)
            }
            .onAppear {
                scrollToBottom(proxy, animated: false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                if viewModel.state == .failed {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                }
                Text(viewModel.state.localizationKey)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: 150, alignment: .leading)

            Spacer(minLength: 16)

            HStack(spacing: 16) {
                MicroWaveformView(rms: viewModel.lastRMS, mode: viewModel.state.waveformMode)
                    .tint(viewModel.state.tint)
                    .frame(width: 44, height: 24)

                Button {
                    Task { await viewModel.toggle() }
                } label: {
                    Image(systemName: viewModel.isActive ? "stop.fill" : "mic.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(viewModel.isActive ? Color.red : Color.accentColor, in: Circle())
                }
                .accessibilityLabel(Text(viewModel.isActive ? "button.stopRecording" : "button.startRecording"))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
        .padding(.horizontal)
        .padding(.bottom, 8)
        .animation(.default, value: viewModel.state)
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool = true) {
        guard !viewModel.messages.isEmpty else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(Self.bottomAnchor, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(Self.bottomAnchor, anchor: .bottom)
        }
    }
}

#Preview {
    RecorderView(
        viewModel: VoiceSessionViewModel(
            recorder: PreviewAudioRecorder(),
            detector: PreviewVoiceActivityDetector(),
            pipeline: StubSpeechPipeline(),
            conversation: PreviewConversationManager(),
            synthesizer: PreviewSpeechSynthesizer(),
            transcript: PreviewChatTranscriptRecorder()
        )
    )
}
