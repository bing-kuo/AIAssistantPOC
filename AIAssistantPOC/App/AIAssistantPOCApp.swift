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

        let conversation = InMemoryConversationRepository()
        let transcript = ChatTranscriptRecorder(writer: store)
        let processTurn = AIAssistantPOCApp.makeProcessTurn(conversation: conversation, transcript: transcript)

        _viewModel = State(
            initialValue: VoiceSessionViewModel(
                recorder: AudioEngineRecorder(),
                detector: AIAssistantPOCApp.makeDetector(),
                processTurn: processTurn,
                startNew: StartNewConversationInteractor(conversation: conversation, transcript: transcript),
                resume: ResumeConversationInteractor(conversation: conversation, transcript: transcript)
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView(
                voiceViewModel: viewModel,
                fetchSummaries: FetchSessionSummariesInteractor(repository: store),
                deleteSession: DeleteSessionInteractor(repository: store),
                loadSession: LoadSessionInteractor(repository: store),
                warmUpServer: AIAssistantPOCApp.makeServerWarmUp()
            )
        }
    }

    private static func makeServerWarmUp() -> any WarmUpServerConnectionUseCase {
        WarmUpServerConnectionInteractor {
            var request = URLRequest(url: serverBaseURL)
            request.timeoutInterval = 3
            _ = try? await URLSession.shared.data(for: request)
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

    private static func makeProcessTurn(
        conversation: any ConversationRepository,
        transcript: any ChatTranscriptRepository
    ) -> any ProcessVoiceTurnUseCase {
        let recognizer = WhisperSpeechRecognizer(configuration: WhisperConfiguration(baseURL: serverBaseURL))
        let responder = ProxyLLMResponder(configuration: LLMConfiguration(baseURL: serverBaseURL))
        return ProcessVoiceTurnInteractor(
            transcribe: TranscribeUtteranceInteractor(recognizer: recognizer),
            generateReply: GenerateReplyInteractor(
                responder: responder,
                conversation: conversation,
                systemPrompt: systemPrompt
            ),
            synthesizer: AppleSpeechSynthesizer.live(),
            transcript: transcript
        )
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
