//
//  AIAssistantPOCApp.swift
//  AIAssistantPOC
//
//  Created by Bing on 2026/6/5.
//

import SwiftUI
import VoiceCore
import VoiceIntelligence

@main
struct AIAssistantPOCApp: App {

    @State private var viewModel = VoiceSessionViewModel(
        recorder: AudioEngineRecorder(),
        detector: AIAssistantPOCApp.makeDetector(),
        pipeline: StubSpeechPipeline()
    )

    var body: some Scene {
        WindowGroup {
            RecorderView(viewModel: viewModel)
        }
    }

    private static func makeDetector() -> any VoiceActivityDetecting {
        do {
            return SpeechEndpointDetector(scorer: try SileroVAD())
        } catch {
            return SpeechEndpointDetector(scorer: SilentScorer())
        }
    }
}

struct SilentScorer: SpeechProbabilityScoring {
    func score(_ window: [Float]) async throws -> Float { 0 }
    func reset() async {}
}
