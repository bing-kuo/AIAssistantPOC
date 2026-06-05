//
//  AIAssistantPOCApp.swift
//  AIAssistantPOC
//
//  Created by Bing on 2026/6/5.
//

import SwiftUI
import VoiceCore
import VoiceIntelligence
import STTCore

@main
struct AIAssistantPOCApp: App {

    @State private var viewModel = VoiceSessionViewModel(
        recorder: AudioEngineRecorder(),
        detector: AIAssistantPOCApp.makeDetector(),
        pipeline: AIAssistantPOCApp.makePipeline()
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

    private static func makePipeline() -> any SpeechPipeline {
        let recognizer = WhisperSpeechRecognizer(configuration: WhisperConfiguration(baseURL: sttBaseURL))
        return SttSpeechPipeline(recognizer: recognizer)
    }
    
    // hardcode URL for demo. Use `ipconfig getifaddr en1` to check IP.
    private static let sttBaseURL = URL(string: "http://192.168.0.35:8000")!
}

struct SilentScorer: SpeechProbabilityScoring {
    func score(_ window: [Float]) async throws -> Float { 0 }
    func reset() async {}
}
