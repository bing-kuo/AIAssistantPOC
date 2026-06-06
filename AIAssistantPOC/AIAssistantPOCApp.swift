//
//  AIAssistantPOCApp.swift
//  AIAssistantPOC
//
//  Created by Bing on 2026/6/5.
//

import SwiftUI
import VoiceAgentDomain
import AVAudioCapture
import VoiceActivityDetection
import SileroVAD
import WhisperSTT
import ProxyLLM
import AppleTTS

@main
struct AIAssistantPOCApp: App {

    @State private var viewModel = VoiceSessionViewModel(
        recorder: AudioEngineRecorder(),
        detector: AIAssistantPOCApp.makeDetector(),
        pipeline: AIAssistantPOCApp.makePipeline(),
        conversation: AIAssistantPOCApp.makeConversation(),
        synthesizer: AppleSpeechSynthesizer.live()
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
        let recognizer = WhisperSpeechRecognizer(configuration: WhisperConfiguration(baseURL: serverBaseURL))
        return SttSpeechPipeline(recognizer: recognizer)
    }

    private static func makeConversation() -> any ConversationManaging {
        let responder = ProxyLLMResponder(configuration: LLMConfiguration(baseURL: serverBaseURL))
        return ConversationManager(responder: responder, systemPrompt: systemPrompt)
    }

    // hardcode URL for demo. Use `ipconfig getifaddr en1` to check IP.
    private static let serverBaseURL = URL(string: "http://192.168.0.35:8000")!

    private static let systemPrompt = """
    You are a concise, friendly voice assistant. Keep replies short and natural for speech. \
    Reply in the same language the user speaks.
    """
}

struct SilentScorer: SpeechProbabilityScoring {
    func score(_ window: [Float]) async throws -> Float { 0 }
    func reset() async {}
}
