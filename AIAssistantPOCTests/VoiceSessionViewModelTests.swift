//
//  VoiceSessionViewModelTests.swift
//  AIAssistantPOCTests
//

import Testing
import VoiceAgentDomain
@testable import AIAssistantPOC

private actor MockRecording: AudioRecording {
    private let permission: Bool
    private let frames: [AudioFrame]
    private(set) var stopCount = 0

    init(permission: Bool = true, frames: [AudioFrame] = []) {
        self.permission = permission
        self.frames = frames
    }

    func requestPermission() async -> Bool { permission }

    func start() async throws -> AsyncStream<AudioFrame> {
        guard permission else { throw AudioRecorderError.permissionDenied }
        let frames = frames
        return AsyncStream { continuation in
            for frame in frames { continuation.yield(frame) }
            continuation.finish()
        }
    }

    func stop() async { stopCount += 1 }
}

private struct MockDetector: VoiceActivityDetecting {
    let scriptedEvents: [VADEvent]

    func events(from samples: AsyncStream<[Float]>) -> AsyncStream<VADEvent> {
        let scriptedEvents = scriptedEvents
        return AsyncStream { continuation in
            let drain = Task { for await _ in samples {} }
            for event in scriptedEvents { continuation.yield(event) }
            continuation.finish()
            continuation.onTermination = { _ in drain.cancel() }
        }
    }

    func reset() async {}
}

private struct ImmediatePipeline: SpeechPipeline {
    let output: String
    func process(_ audio: [Float]) async throws -> String { output }
}

private struct ScriptedConversation: ConversationManaging {
    let deltas: [String]
    func respond(to userText: String) -> AsyncThrowingStream<String, Error> {
        let deltas = deltas
        return AsyncThrowingStream { continuation in
            for delta in deltas { continuation.yield(delta) }
            continuation.finish()
        }
    }
    func reset() async {}
}

private actor GatedSynthesizer: SpeechSynthesizing {
    private(set) var spokenText: String?
    private(set) var stopCount = 0
    private var continuation: CheckedContinuation<Void, Never>?
    private let gated: Bool

    init(gated: Bool = false) { self.gated = gated }

    func speak(_ text: String) async throws {
        spokenText = text
        guard gated else { return }
        await withCheckedContinuation { self.continuation = $0 }
    }

    func release() { continuation?.resume(); continuation = nil }
    func stop() async { stopCount += 1 }
}

@MainActor
private func wait(
    for viewModel: VoiceSessionViewModel,
    until predicate: @escaping (VoiceSessionViewModel) -> Bool
) async {
    for _ in 0..<200 {
        if predicate(viewModel) { return }
        try? await Task.sleep(for: .milliseconds(10))
    }
}

private func frame() -> AudioFrame {
    AudioFrame(samples: [0.1, -0.1], frameCount: 2, rms: 0.1, timestamp: 0)
}

@MainActor
@Suite("VoiceSessionViewModel")
struct VoiceSessionViewModelTests {

    @Test("auto-switches through speaking → processing → responding → playing → listening")
    func autoSwitchesThroughStates() async {
        // Given a detector scripting a full utterance, a streamed reply, and a gated synthesizer
        let recorder = MockRecording(frames: [frame(), frame()])
        let detector = MockDetector(scriptedEvents: [.speechStarted, .speechEnded(segment: [0.2, 0.2])])
        let pipeline = ImmediatePipeline(output: "HELLO")
        let conversation = ScriptedConversation(deltas: ["Hi", " there"])
        let synthesizer = GatedSynthesizer(gated: true)
        let sut = VoiceSessionViewModel(
            recorder: recorder,
            detector: detector,
            pipeline: pipeline,
            conversation: conversation,
            synthesizer: synthesizer
        )

        // When the user starts the session
        await sut.toggle()

        // Then the reply is synthesized while the state is .playing
        for _ in 0..<200 {
            if await synthesizer.spokenText == "Hi there" { break }
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(sut.lastUserText == "HELLO")
        #expect(await synthesizer.spokenText == "Hi there")
        #expect(sut.state == .playing)

        // And after playback finishes it returns to listening
        await synthesizer.release()
        await wait(for: sut) { $0.state == .listening }
        #expect(sut.state == .listening)
    }

    @Test("denied microphone permission moves to failed")
    func deniedPermissionFails() async {
        // Given
        let recorder = MockRecording(permission: false)
        let detector = MockDetector(scriptedEvents: [])
        let sut = VoiceSessionViewModel(
            recorder: recorder,
            detector: detector,
            pipeline: ImmediatePipeline(output: ""),
            conversation: ScriptedConversation(deltas: []),
            synthesizer: GatedSynthesizer()
        )

        // When
        await sut.toggle()

        // Then
        #expect(sut.state == .failed)
    }

    @Test("toggling while active stops and returns to idle")
    func toggleStops() async {
        // Given a detector that emits nothing so the session stays listening
        let recorder = MockRecording(frames: [frame()])
        let detector = MockDetector(scriptedEvents: [])
        let sut = VoiceSessionViewModel(
            recorder: recorder,
            detector: detector,
            pipeline: ImmediatePipeline(output: ""),
            conversation: ScriptedConversation(deltas: []),
            synthesizer: GatedSynthesizer()
        )

        // When started then toggled again
        await sut.toggle()
        await sut.toggle()

        // Then
        #expect(sut.state == .idle)
        #expect(await recorder.stopCount >= 1)
    }
}
