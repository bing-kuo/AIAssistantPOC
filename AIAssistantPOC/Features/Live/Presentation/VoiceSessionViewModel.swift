//
//  VoiceSessionViewModel.swift
//  AIAssistantPOC
//

import Foundation
import Observation
import VoiceAgentDomain

@MainActor
@Observable
final class VoiceSessionViewModel {

    private let recorder: any AudioRecording
    private let detector: any VoiceActivityDetecting
    private let processTurn: any ProcessVoiceTurnUseCase
    private let startNew: any StartNewConversationUseCase
    private let resumeConversation: any ResumeConversationUseCase
    private var sessionTask: Task<Void, Never>?
    private var isTransitioning = false

    private(set) var state: SessionState = .idle
    private(set) var lastRMS: Float = 0
    private(set) var messages: [ChatMessage] = []

    var isActive: Bool {
        switch state {
        case .idle, .failed: false
        case .listening, .speaking, .processing, .responding, .playing: true
        }
    }

    private var isCapturing: Bool {
        switch state {
        case .listening, .speaking: true
        case .idle, .processing, .responding, .playing, .failed: false
        }
    }

    init(
        recorder: any AudioRecording,
        detector: any VoiceActivityDetecting,
        processTurn: any ProcessVoiceTurnUseCase,
        startNew: any StartNewConversationUseCase,
        resume: any ResumeConversationUseCase
    ) {
        self.recorder = recorder
        self.detector = detector
        self.processTurn = processTurn
        self.startNew = startNew
        self.resumeConversation = resume
    }

    func beginNewSession() async {
        await startNew()
        messages = []
    }

    func resume(_ session: ChatSession) async {
        await resumeConversation(session)
        messages = session.messages
    }

    func toggle() async {
        guard !isTransitioning else { return }
        isTransitioning = true
        defer { isTransitioning = false }
        if isActive {
            await stop()
        } else {
            await start()
        }
    }

    private func start() async {
        guard await recorder.requestPermission() else {
            state = .failed
            return
        }

        await detector.reset()

        do {
            let frames = try await recorder.start()
            state = .listening
            sessionTask = Task { [weak self] in
                await self?.run(frames)
            }
        } catch {
            state = .failed
        }
    }

    private func run(_ frames: AsyncStream<AudioFrame>) async {
        let (sampleStream, sampleContinuation) = AsyncStream<[Float]>.makeStream()
        let events = detector.events(from: sampleStream)

        let feeder = Task { [weak self] in
            for await frame in frames {
                guard let self else { break }
                guard self.isCapturing else {
                    self.lastRMS = 0
                    continue
                }
                self.lastRMS = frame.rms
                sampleContinuation.yield(frame.samples)
            }
            sampleContinuation.finish()
        }

        for await event in events {
            switch event {
            case .speechStarted:
                state = .speaking
            case .speechEnded(let segment):
                await process(segment)
            }
        }

        feeder.cancel()
        await feeder.value
        lastRMS = 0
    }

    private func process(_ segment: [Float]) async {
        state = .processing
        do {
            for try await event in processTurn(segment) {
                try Task.checkCancellation()
                apply(event)
            }
            try Task.checkCancellation()
            await detector.reset()
            state = .listening
        } catch {
            if !Task.isCancelled { state = .failed }
        }
    }

    private func apply(_ event: VoiceTurnEvent) {
        switch event {
        case .userTranscribed(let text):
            messages.append(ChatMessage(role: .user, text: text))
            state = .responding
        case .replyDelta(let delta):
            appendAssistantDelta(delta)
        case .replyCompleted:
            break
        case .speaking:
            lastRMS = 0
            state = .playing
        }
    }

    private func appendAssistantDelta(_ delta: String) {
        if let index = messages.indices.last, messages[index].role == .assistant {
            let previous = messages[index]
            messages[index] = ChatMessage(
                id: previous.id,
                role: .assistant,
                text: previous.text + delta,
                createdAt: previous.createdAt
            )
        } else {
            messages.append(ChatMessage(role: .assistant, text: delta))
        }
    }

    private func stop() async {
        sessionTask?.cancel()
        sessionTask = nil
        await recorder.stop()
        lastRMS = 0
        state = .idle
    }
}
