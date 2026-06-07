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

private actor CountingRecorder: AudioRecording {
    private(set) var permissionRequests = 0
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private var gates: [CheckedContinuation<Void, Never>] = []
    private var opened = false

    func requestPermission() async -> Bool {
        permissionRequests += 1
        if opened { return true }
        await withCheckedContinuation { gates.append($0) }
        return true
    }

    func releaseAll() {
        opened = true
        for gate in gates { gate.resume() }
        gates.removeAll()
    }

    func start() async throws -> AsyncStream<AudioFrame> {
        startCount += 1
        return AsyncStream { $0.finish() }
    }

    func stop() async { stopCount += 1 }
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
    private var released = false
    private let gated: Bool

    init(gated: Bool = false) { self.gated = gated }

    var isParked: Bool { continuation != nil }

    func speak(_ text: String) async throws {
        spokenText = text
        guard gated, !released else { return }
        await withCheckedContinuation { self.continuation = $0 }
    }

    func release() {
        released = true
        continuation?.resume()
        continuation = nil
    }

    func stop() async { stopCount += 1 }
}

private actor ReplayProbe {
    private(set) var batchCount = 0
    private(set) var samplesFinished = false
    func record() { batchCount += 1 }
    func finish() { samplesFinished = true }
}

private struct ProbingDetector: VoiceActivityDetecting {
    let probe: ReplayProbe

    func events(from samples: AsyncStream<[Float]>) -> AsyncStream<VADEvent> {
        let probe = probe
        return AsyncStream { continuation in
            let task = Task {
                var emitted = false
                for await batch in samples {
                    await probe.record()
                    if !emitted {
                        emitted = true
                        continuation.yield(.speechEnded(segment: batch))
                    }
                }
                await probe.finish()
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func reset() async {}
}

private actor HeldFrameRecorder: AudioRecording {
    private var continuation: AsyncStream<AudioFrame>.Continuation?
    private let extraFrames: Int
    private(set) var stopCount = 0

    init(extraFrames: Int) { self.extraFrames = extraFrames }

    func requestPermission() async -> Bool { true }

    func start() async throws -> AsyncStream<AudioFrame> {
        let (stream, continuation) = AsyncStream<AudioFrame>.makeStream()
        self.continuation = continuation
        continuation.yield(Self.frame())
        return stream
    }

    func releaseFrames() {
        for _ in 0..<extraFrames { continuation?.yield(Self.frame()) }
        continuation?.finish()
    }

    func stop() async {
        stopCount += 1
        continuation?.finish()
        continuation = nil
    }

    nonisolated static func frame() -> AudioFrame {
        AudioFrame(samples: [0.2, 0.2], frameCount: 2, rms: 0.3, timestamp: 0)
    }
}

private actor OpenRecorder: AudioRecording {
    private var continuation: AsyncStream<AudioFrame>.Continuation?
    private(set) var stopCount = 0

    func requestPermission() async -> Bool { true }

    func start() async throws -> AsyncStream<AudioFrame> {
        let (stream, continuation) = AsyncStream<AudioFrame>.makeStream()
        self.continuation = continuation
        return stream
    }

    func stop() async {
        stopCount += 1
        continuation?.finish()
        continuation = nil
    }
}

private actor GatedPipeline: SpeechPipeline {
    private(set) var processCount = 0
    private var gate: CheckedContinuation<Void, Never>?
    private var released = false

    func process(_ audio: [Float]) async throws -> String {
        processCount += 1
        if processCount == 1, !released {
            await withCheckedContinuation { gate = $0 }
        }
        return ""
    }

    func release() {
        released = true
        gate?.resume()
        gate = nil
    }
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

    @Test("rapid double toggle must start exactly one session (no orphaned task)")
    func rapidToggleDoesNotOrphanSession() async {
        // Given a recorder whose permission request parks until both toggles arrive,
        // so `state` is still .idle (isActive == false) when the second toggle reads it
        let recorder = CountingRecorder()
        let sut = VoiceSessionViewModel(
            recorder: recorder,
            detector: MockDetector(scriptedEvents: []),
            pipeline: ImmediatePipeline(output: ""),
            conversation: ScriptedConversation(deltas: []),
            synthesizer: GatedSynthesizer()
        )

        // When the user frantically taps twice before the first start resolves
        async let first: Void = sut.toggle()
        async let second: Void = sut.toggle()

        for _ in 0..<100 {
            if await recorder.permissionRequests >= 2 { break }
            try? await Task.sleep(for: .milliseconds(10))
        }
        await recorder.releaseAll()
        _ = await (first, second)

        // Then only one capture session is created; the first task is never orphaned by a second start
        #expect(await recorder.startCount == 1)
    }

    @Test("stopping mid-playback must stay idle, not be overwritten back to listening")
    func stopDuringPlaybackStaysIdle() async {
        // Given a session parked inside a gated synthesizer (state == .playing)
        let recorder = MockRecording(frames: [frame()])
        let detector = MockDetector(scriptedEvents: [.speechStarted, .speechEnded(segment: [0.2, 0.2])])
        let synthesizer = GatedSynthesizer(gated: true)
        let sut = VoiceSessionViewModel(
            recorder: recorder,
            detector: detector,
            pipeline: ImmediatePipeline(output: "HELLO"),
            conversation: ScriptedConversation(deltas: ["Hi"]),
            synthesizer: synthesizer
        )

        await sut.toggle()
        await wait(for: sut) { $0.state == .playing }
        for _ in 0..<100 {
            if await synthesizer.isParked { break }
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(sut.state == .playing)
        #expect(await synthesizer.isParked)

        // When the user stops while playback is still in flight
        await sut.toggle()
        #expect(sut.state == .idle)

        // And the still-parked process() is allowed to resume after the stop
        await synthesizer.release()

        // Then process() must not resurrect the session by writing .listening over .idle
        var observed: SessionState = sut.state
        for _ in 0..<50 {
            try? await Task.sleep(for: .milliseconds(10))
            if sut.state != .idle { observed = sut.state; break }
        }
        #expect(observed == .idle)
    }

    @Test("audio is not fed to the VAD while a turn is being processed (no buffered replay)")
    func noVADReplayWhileProcessing() async {
        // Given a session parked in its first turn (gated pipeline holds .processing)
        let probe = ReplayProbe()
        let recorder = HeldFrameRecorder(extraFrames: 20)
        let pipeline = GatedPipeline()
        let sut = VoiceSessionViewModel(
            recorder: recorder,
            detector: ProbingDetector(probe: probe),
            pipeline: pipeline,
            conversation: ScriptedConversation(deltas: []),
            synthesizer: GatedSynthesizer()
        )

        await sut.toggle()
        for _ in 0..<200 {
            if await pipeline.processCount == 1 { break }
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(await pipeline.processCount == 1)

        // When the user keeps speaking (a burst of audio) while the turn is still processing
        await recorder.releaseFrames()
        for _ in 0..<200 {
            if await probe.samplesFinished { break }
            try? await Task.sleep(for: .milliseconds(10))
        }

        // Then none of that audio reached the VAD — only the single pre-processing frame did
        #expect(await probe.samplesFinished)
        #expect(await probe.batchCount == 1)

        await pipeline.release()
    }

    @Test("stopping the session terminates the audio feeder (no orphaned VAD stream)")
    func stopConvergesFeeder() async {
        // Given an active session whose microphone stream stays open until stopped
        let probe = ReplayProbe()
        let recorder = OpenRecorder()
        let sut = VoiceSessionViewModel(
            recorder: recorder,
            detector: ProbingDetector(probe: probe),
            pipeline: ImmediatePipeline(output: ""),
            conversation: ScriptedConversation(deltas: []),
            synthesizer: GatedSynthesizer()
        )

        await sut.toggle()
        await wait(for: sut) { $0.state == .listening }

        // When the user stops the session
        await sut.toggle()
        #expect(sut.state == .idle)

        // Then the feeder converges: the VAD sample stream is terminated, not left orphaned
        for _ in 0..<200 {
            if await probe.samplesFinished { break }
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(await probe.samplesFinished)
    }
}
