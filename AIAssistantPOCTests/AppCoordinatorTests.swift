//
//  AppCoordinatorTests.swift
//  AIAssistantPOCTests
//

import Foundation
import Testing
import VoiceAgentDomain
@testable import AIAssistantPOC

private actor NoopRecorder: AudioRecording {
    func requestPermission() async -> Bool { true }
    func start() async throws -> AsyncStream<AudioFrame> { AsyncStream { $0.finish() } }
    func stop() async {}
}

private struct NoopDetector: VoiceActivityDetecting {
    func events(from samples: AsyncStream<[Float]>) -> AsyncStream<VADEvent> {
        AsyncStream { $0.finish() }
    }
    func reset() async {}
}

private actor SpyStartNew: StartNewConversationUseCase {
    private(set) var count = 0
    func callAsFunction() async { count += 1 }
}

private actor SpyResume: ResumeConversationUseCase {
    private(set) var sessions: [UUID] = []
    func callAsFunction(_ session: ChatSession) async { sessions.append(session.id) }
}

private struct StubLoadSession: LoadSessionUseCase {
    let result: ChatSession?
    func callAsFunction(_ id: UUID) async -> ChatSession? { result }
}

private struct StubFetchSummaries: FetchSessionSummariesUseCase {
    func callAsFunction() async -> [ChatSessionSummary] { [] }
}

private struct StubDeleteSession: DeleteSessionUseCase {
    func callAsFunction(_ id: UUID) async {}
}

private struct StubWarmUp: WarmUpServerConnectionUseCase {
    func callAsFunction() async {}
}

@MainActor
@Suite("AppCoordinator")
struct AppCoordinatorTests {

    private func makeCoordinator(
        loadResult: ChatSession? = nil,
        startNew: SpyStartNew = SpyStartNew(),
        resume: SpyResume = SpyResume(),
        makeSettings: @escaping @MainActor () -> SettingsViewModel = { .preview() }
    ) -> AppCoordinator {
        let voice = VoiceSessionViewModel(
            recorder: NoopRecorder(),
            detector: NoopDetector(),
            processTurn: PreviewProcessVoiceTurn(),
            startNew: startNew,
            resume: resume
        )
        let sessionList = SessionListViewModel(
            fetchSummaries: StubFetchSummaries(),
            deleteSession: StubDeleteSession(),
            loadSession: StubLoadSession(result: loadResult)
        )
        return AppCoordinator(
            voice: voice,
            sessionList: sessionList,
            makeSettings: makeSettings,
            warmUpServer: StubWarmUp()
        )
    }

    private func session(id: UUID = UUID(), messages: [ChatMessage] = []) -> ChatSession {
        ChatSession(
            id: id,
            title: "T",
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0),
            messages: messages
        )
    }

    @Test("opening settings switches the root destination and dismisses history")
    func openSettings() {
        // Given history is open on the live destination
        let sut = makeCoordinator()
        sut.openHistory()

        // When settings is opened
        sut.openSettings()

        // Then the root shows settings and the drawer is dismissed
        #expect(sut.rootDestination == .settings)
        #expect(sut.isHistoryPresented == false)
    }

    @Test("closing settings returns to the live destination")
    func closeSettings() {
        // Given the settings destination
        let sut = makeCoordinator()
        sut.openSettings()

        // When settings is closed
        sut.closeSettings()

        // Then the live destination is restored
        #expect(sut.rootDestination == .live)
    }

    @Test("settings view model is built lazily on first open and then cached")
    func settingsBuiltLazilyAndCached() {
        // Given a coordinator that counts how often settings is constructed
        var buildCount = 0
        let sut = makeCoordinator(makeSettings: {
            buildCount += 1
            return .preview()
        })

        // Then nothing is built until settings is opened
        #expect(sut.settings == nil)
        #expect(buildCount == 0)

        // When settings is opened, closed, and opened again
        sut.openSettings()
        let first = sut.settings
        sut.closeSettings()
        sut.openSettings()

        // Then it is built exactly once and the same instance is reused
        #expect(buildCount == 1)
        #expect(sut.settings === first)
    }

    @Test("opening then closing history toggles the drawer")
    func toggleHistory() {
        // Given a fresh coordinator
        let sut = makeCoordinator()

        // When the drawer is opened then closed
        sut.openHistory()
        let opened = sut.isHistoryPresented
        sut.closeHistory()

        // Then it tracks both states
        #expect(opened == true)
        #expect(sut.isHistoryPresented == false)
    }

    @Test("starting a new session dismisses history and begins a new conversation")
    func startNewSession() async {
        // Given history is open
        let startNew = SpyStartNew()
        let sut = makeCoordinator(startNew: startNew)
        sut.openHistory()

        // When a new session starts
        await sut.startNewSession()

        // Then the drawer closes and the start use case ran
        #expect(sut.isHistoryPresented == false)
        #expect(await startNew.count == 1)
    }

    @Test("selecting an existing session resumes it and dismisses history")
    func selectExistingSession() async {
        // Given a loadable session carrying a message
        let message = ChatMessage(role: .assistant, text: "hi")
        let target = session(messages: [message])
        let resume = SpyResume()
        let sut = makeCoordinator(loadResult: target, resume: resume)
        sut.openHistory()

        // When it is selected
        await sut.selectSession(target.id)

        // Then it is resumed, surfaced on the live view model, and the drawer closes
        #expect(await resume.sessions == [target.id])
        #expect(sut.voice.messages.map(\.id) == [message.id])
        #expect(sut.isHistoryPresented == false)
    }

    @Test("selecting a missing session does not resume but still dismisses history")
    func selectMissingSession() async {
        // Given loadSession yields nothing
        let resume = SpyResume()
        let sut = makeCoordinator(loadResult: nil, resume: resume)
        sut.openHistory()

        // When a selection is made
        await sut.selectSession(UUID())

        // Then nothing is resumed yet the drawer still closes
        #expect(await resume.sessions.isEmpty)
        #expect(sut.isHistoryPresented == false)
    }
}
