//
//  VoiceSessionViewModel.swift
//  AIAssistantPOC
//

import Observation
import VoiceCore
import VoiceIntelligence

enum SessionState: Equatable, Sendable {
    case idle
    case listening
    case speaking
    case processing
    case responding
    case failed
}

@MainActor
@Observable
final class VoiceSessionViewModel {

    private let recorder: any AudioRecording
    private let detector: any VoiceActivityDetecting
    private let pipeline: any SpeechPipeline
    private let conversation: any ConversationManaging
    private var sessionTask: Task<Void, Never>?

    private(set) var state: SessionState = .idle
    private(set) var lastRMS: Float = 0
    private(set) var lastUserText: String?
    private(set) var answer: String = ""

    var isActive: Bool {
        switch state {
        case .idle, .failed: false
        case .listening, .speaking, .processing, .responding: true
        }
    }

    init(
        recorder: any AudioRecording,
        detector: any VoiceActivityDetecting,
        pipeline: any SpeechPipeline,
        conversation: any ConversationManaging
    ) {
        self.recorder = recorder
        self.detector = detector
        self.pipeline = pipeline
        self.conversation = conversation
    }

    func toggle() async {
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
        lastRMS = 0
    }

    private func process(_ segment: [Float]) async {
        state = .processing
        do {
            let text = try await pipeline.process(segment)
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
            state = .listening
        } catch {
            if !Task.isCancelled { state = .failed }
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
