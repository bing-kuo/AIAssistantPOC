//
//  VoiceSessionViewModel.swift
//  AIAssistantPOC
//

import Observation
import VoiceAgentDomain

enum SessionState: Equatable, Sendable {
    case idle
    case listening
    case speaking
    case processing
    case responding
    case playing
    case failed
}

@MainActor
@Observable
final class VoiceSessionViewModel {

    private let recorder: any AudioRecording
    private let detector: any VoiceActivityDetecting
    private let pipeline: any SpeechPipeline
    private let conversation: any ConversationManaging
    private let synthesizer: any SpeechSynthesizing
    private var sessionTask: Task<Void, Never>?
    private var isTransitioning = false

    private(set) var state: SessionState = .idle
    private(set) var lastRMS: Float = 0
    private(set) var lastUserText: String?
    private(set) var answer: String = ""

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
        pipeline: any SpeechPipeline,
        conversation: any ConversationManaging,
        synthesizer: any SpeechSynthesizing
    ) {
        self.recorder = recorder
        self.detector = detector
        self.pipeline = pipeline
        self.conversation = conversation
        self.synthesizer = synthesizer
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
        await conversation.reset()
        lastUserText = nil
        answer = ""

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
            let text = try await pipeline.process(segment)
            try Task.checkCancellation()
            guard !text.isEmpty else {
                state = .listening
                return
            }
            lastUserText = text
            answer = ""
            state = .responding
            for try await delta in conversation.respond(to: text) {
                answer += delta
            }
            try Task.checkCancellation()
            await speak(answer)
            try Task.checkCancellation()
            state = .listening
        } catch {
            if !Task.isCancelled { state = .failed }
        }
    }

    private func speak(_ text: String) async {
        guard !text.isEmpty else { return }
        lastRMS = 0
        state = .playing
        try? await synthesizer.speak(text)
        await detector.reset()
    }

    private func stop() async {
        sessionTask?.cancel()
        sessionTask = nil
        await synthesizer.stop()
        await recorder.stop()
        lastRMS = 0
        state = .idle
    }
}
