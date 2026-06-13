//
//  CompositionRoot.swift
//  AIAssistantPOC
//

import Foundation
import SwiftData
import VoiceAgentDomain
import AVAudioCapture
import VoiceActivityDetection
import SileroVAD
import WhisperSTT
import ProxyLLM
import AppleTTS

@MainActor
struct CompositionRoot {

    func makeAppCoordinator() -> AppCoordinator {
        let store = makeStore()
        let conversation = InMemoryConversationRepository()
        let transcript = ChatTranscriptRecorder(writer: store)

        return AppCoordinator(
            voice: makeVoiceViewModel(conversation: conversation, transcript: transcript),
            sessionList: makeSessionList(store: store),
            makeSettings: { self.makeSettings() },
            warmUpServer: makeServerWarmUp()
        )
    }

    private func makeSessionList(store: SwiftDataChatStore) -> SessionListViewModel {
        SessionListViewModel(
            fetchSummaries: FetchSessionSummariesInteractor(repository: store),
            deleteSession: DeleteSessionInteractor(repository: store),
            loadSession: LoadSessionInteractor(repository: store)
        )
    }

    private func makeVoiceViewModel(
        conversation: any ConversationRepository,
        transcript: any ChatTranscriptRepository
    ) -> VoiceSessionViewModel {
        VoiceSessionViewModel(
            recorder: AudioEngineRecorder(),
            detector: makeDetector(),
            processTurn: makeProcessTurn(conversation: conversation, transcript: transcript),
            startNew: StartNewConversationInteractor(conversation: conversation, transcript: transcript),
            resume: ResumeConversationInteractor(conversation: conversation, transcript: transcript)
        )
    }

    private func makeSettings() -> SettingsViewModel {
        let store = UserDefaultsPreferencesStore(serverDisplayURL: Self.serverBaseURL.absoluteString)
        return SettingsViewModel(
            fetchPreferences: FetchPreferencesInteractor(repository: store),
            updatePreferences: UpdatePreferencesInteractor(repository: store)
        )
    }

    private func makeServerWarmUp() -> any WarmUpServerConnectionUseCase {
        WarmUpServerConnectionInteractor {
            var request = URLRequest(url: Self.serverBaseURL)
            request.timeoutInterval = 3
            _ = try? await URLSession.shared.data(for: request)
        }
    }

    private func makeStore() -> SwiftDataChatStore {
        do {
            let container = try ModelContainer(for: SessionRecord.self)
            return SwiftDataChatStore(modelContainer: container)
        } catch {
            let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try! ModelContainer(for: SessionRecord.self, configurations: configuration)
            return SwiftDataChatStore(modelContainer: container)
        }
    }

    private func makeDetector() -> any VoiceActivityDetecting {
        do {
            return SpeechEndpointDetector(scorer: try SileroVAD())
        } catch {
            return SpeechEndpointDetector(scorer: SilentScorer())
        }
    }

    private func makeProcessTurn(
        conversation: any ConversationRepository,
        transcript: any ChatTranscriptRepository
    ) -> any ProcessVoiceTurnUseCase {
        let recognizer = WhisperSpeechRecognizer(configuration: WhisperConfiguration(baseURL: Self.serverBaseURL))
        let responder = ProxyLLMResponder(configuration: LLMConfiguration(baseURL: Self.serverBaseURL))
        return ProcessVoiceTurnInteractor(
            transcribe: TranscribeUtteranceInteractor(recognizer: recognizer),
            generateReply: GenerateReplyInteractor(
                responder: responder,
                conversation: conversation,
                systemPrompt: Self.systemPrompt
            ),
            synthesizer: AppleSpeechSynthesizer.live(),
            transcript: transcript
        )
    }

    private nonisolated static let serverBaseURL = URL(string: "http://192.168.0.35:8000")!

    private nonisolated static let systemPrompt = """
    You are a concise, friendly voice assistant. Keep replies short and natural for speech. \
    Reply in the same language the user speaks.
    """
}

struct SilentScorer: SpeechProbabilityScoring {
    func score(_ window: [Float]) async throws -> Float { 0 }
    func reset() async {}
}
