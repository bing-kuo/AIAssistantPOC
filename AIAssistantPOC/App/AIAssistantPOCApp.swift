//
//  AIAssistantPOCApp.swift
//  AIAssistantPOC
//
//  Created by Bing on 2026/6/5.
//

import SwiftUI
import SwiftData
import VoiceAgentDomain
import AVAudioCapture
import VoiceActivityDetection
import SileroVAD
import WhisperSTT
import ProxyLLM
import AppleTTS

@main
struct AIAssistantPOCApp: App {

    private let store: SwiftDataChatStore

    @State private var viewModel: VoiceSessionViewModel

    init() {
        let store = AIAssistantPOCApp.makeStore()
        self.store = store
        _viewModel = State(
            initialValue: VoiceSessionViewModel(
                recorder: AudioEngineRecorder(),
                detector: AIAssistantPOCApp.makeDetector(),
                pipeline: AIAssistantPOCApp.makePipeline(),
                conversation: AIAssistantPOCApp.makeConversation(),
                synthesizer: AppleSpeechSynthesizer.live(),
                transcript: ChatTranscriptRecorder(writer: store)
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView(voiceViewModel: viewModel, reading: store, writing: store)
        }
    }

    private static func makeStore() -> SwiftDataChatStore {
        do {
            let container = try ModelContainer(for: SessionRecord.self)
            return SwiftDataChatStore(modelContainer: container)
        } catch {
            let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try! ModelContainer(for: SessionRecord.self, configurations: configuration)
            return SwiftDataChatStore(modelContainer: container)
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
