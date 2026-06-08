//
//  VoiceSessionViewModelTests.swift
//  AIAssistantPOCTests
//

import Foundation
import Testing
import VoiceAgentDomain
@testable import AIAssistantPOC

// MARK: - Capture ports (recorder / detector) mocks

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

// MARK: - Use case mocks

private actor Counter {
    private(set) var value = 0
    func increment() { value += 1 }
}

private actor Gate {
    private var continuation: CheckedContinuation<Void, Never>?
    private(set) var isParked = false
    private var released = false

    func wait() async {
        if released { return }
        isParked = true
        await withCheckedContinuation { continuation = $0 }
        isParked = false
    }

    func release() {
        released = true
        continuation?.resume()
        continuation = nil
    }
}

/// Emits scripted events then finishes immediately.
private struct ScriptedProcessTurn: ProcessVoiceTurnUseCase {
    let events: [VoiceTurnEvent]
    init(_ events: [VoiceTurnEvent] = []) { self.events = events }

    func callAsFunction(_ audio: [Float]) -> AsyncThrowingStream<VoiceTurnEvent, Error> {
        let events = events
        return AsyncThrowingStream { continuation in
            for event in events { continuation.yield(event) }
            continuation.finish()
        }
    }
}

/// Emits scripted events, then parks on a gate until released.
private struct GatedProcessTurn: ProcessVoiceTurnUseCase {
    let events: [VoiceTurnEvent]
    let gate: Gate
    let invocations: Counter

    func callAsFunction(_ audio: [Float]) -> AsyncThrowingStream<VoiceTurnEvent, Error> {
        let events = events
        let gate = gate
        let invocations = invocations
        return AsyncThrowingStream { continuation in
            let task = Task {
                await invocations.increment()
                for event in events { continuation.yield(event) }
                await gate.wait()
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

private actor SpyStartNew: StartNewConversationUseCase {
    private(set) var count = 0
    func callAsFunction() async { count += 1 }
}

private actor SpyResume: ResumeConversationUseCase {
    private(set) var sessions: [UUID] = []
    func callAsFunction(_ session: ChatSession) async { sessions.append(session.id) }
}

private let fullTurnEvents: [VoiceTurnEvent] = [
    .userTranscribed("HELLO"),
    .replyDelta("Hi"),
    .replyDelta(" there"),
    .replyCompleted("Hi there"),
    .speaking,
]

// MARK: - Helpers

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
private func makeViewModel(
    recorder: any AudioRecording,
    detector: any VoiceActivityDetecting,
    processTurn: any ProcessVoiceTurnUseCase = ScriptedProcessTurn(),
    startNew: any StartNewConversationUseCase = SpyStartNew(),
    resume: any ResumeConversationUseCase = SpyResume()
) -> VoiceSessionViewModel {
    VoiceSessionViewModel(
        recorder: recorder,
        detector: detector,
        processTurn: processTurn,
        startNew: startNew,
        resume: resume
    )
}

@MainActor
@Suite("VoiceSessionViewModel")
struct VoiceSessionViewModelTests {

    @Test("auto-switches through speaking → responding → playing → listening")
    func autoSwitchesThroughStates() async {
        // Given a detector scripting a full utterance and a process use case parked at .speaking
        let recorder = MockRecording(frames: [frame(), frame()])
        let detector = MockDetector(scriptedEvents: [.speechStarted, .speechEnded(segment: [0.2, 0.2])])
        let gate = Gate()
        let processTurn = GatedProcessTurn(events: fullTurnEvents, gate: gate, invocations: Counter())
        let sut = makeViewModel(recorder: recorder, detector: detector, processTurn: processTurn)

        // When the user starts the session, it streams the reply and parks while playing
        await sut.toggle()
        await wait(for: sut) { $0.state == .playing }
        #expect(sut.messages.map(\.role) == [.user, .assistant])
        #expect(sut.messages.first?.text == "HELLO")
        #expect(sut.messages.last?.text == "Hi there")
        #expect(sut.state == .playing)

        // And after playback finishes it returns to listening
        await gate.release()
        await wait(for: sut) { $0.state == .listening }
        #expect(sut.state == .listening)
    }

    @Test("denied microphone permission moves to failed")
    func deniedPermissionFails() async {
        // Given
        let sut = makeViewModel(
            recorder: MockRecording(permission: false),
            detector: MockDetector(scriptedEvents: [])
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
        let sut = makeViewModel(recorder: recorder, detector: MockDetector(scriptedEvents: []))

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
        let sut = makeViewModel(recorder: recorder, detector: MockDetector(scriptedEvents: []))

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
        // Given a session parked inside the process use case at .speaking (state == .playing)
        let recorder = MockRecording(frames: [frame()])
        let detector = MockDetector(scriptedEvents: [.speechStarted, .speechEnded(segment: [0.2, 0.2])])
        let gate = Gate()
        let processTurn = GatedProcessTurn(events: fullTurnEvents, gate: gate, invocations: Counter())
        let sut = makeViewModel(recorder: recorder, detector: detector, processTurn: processTurn)

        await sut.toggle()
        await wait(for: sut) { $0.state == .playing }
        #expect(sut.state == .playing)
        #expect(await gate.isParked)

        // When the user stops while playback is still in flight
        await sut.toggle()
        #expect(sut.state == .idle)

        // And the still-parked turn is allowed to resume after the stop
        await gate.release()

        // Then the cancelled turn must not resurrect the session by writing .listening over .idle
        var observed: SessionState = sut.state
        for _ in 0..<50 {
            try? await Task.sleep(for: .milliseconds(10))
            if sut.state != .idle { observed = sut.state; break }
        }
        #expect(observed == .idle)
    }

    @Test("audio is not fed to the VAD while a turn is being processed (no buffered replay)")
    func noVADReplayWhileProcessing() async {
        // Given a session parked in its first turn (process use case holds .processing)
        let probe = ReplayProbe()
        let recorder = HeldFrameRecorder(extraFrames: 20)
        let gate = Gate()
        let invocations = Counter()
        let processTurn = GatedProcessTurn(events: [], gate: gate, invocations: invocations)
        let sut = makeViewModel(recorder: recorder, detector: ProbingDetector(probe: probe), processTurn: processTurn)

        await sut.toggle()
        for _ in 0..<200 {
            if await invocations.value == 1 { break }
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(await invocations.value == 1)

        // When the user keeps speaking (a burst of audio) while the turn is still processing
        await recorder.releaseFrames()
        for _ in 0..<200 {
            if await probe.samplesFinished { break }
            try? await Task.sleep(for: .milliseconds(10))
        }

        // Then none of that audio reached the VAD — only the single pre-processing frame did
        #expect(await probe.samplesFinished)
        #expect(await probe.batchCount == 1)

        await gate.release()
    }

    @Test("stopping the session terminates the audio feeder (no orphaned VAD stream)")
    func stopConvergesFeeder() async {
        // Given an active session whose microphone stream stays open until stopped
        let probe = ReplayProbe()
        let recorder = OpenRecorder()
        let sut = makeViewModel(recorder: recorder, detector: ProbingDetector(probe: probe), processTurn: ScriptedProcessTurn())

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

    @Test("a completed turn appends the user message then the streamed assistant reply")
    func buildsTurnMessages() async {
        // Given a session that streams a full turn
        let recorder = MockRecording(frames: [frame()])
        let detector = MockDetector(scriptedEvents: [.speechStarted, .speechEnded(segment: [0.2, 0.2])])
        let sut = makeViewModel(recorder: recorder, detector: detector, processTurn: ScriptedProcessTurn(fullTurnEvents))

        // When the turn runs to completion
        await sut.toggle()
        await wait(for: sut) { $0.messages.count == 2 }

        // Then both sides of the turn are reflected in the live view
        #expect(sut.messages.map(\.role) == [.user, .assistant])
        #expect(sut.messages.map(\.text) == ["HELLO", "Hi there"])
    }

    @Test("resume loads the session transcript and delegates restore to the use case")
    func resumeLoadsTranscript() async {
        // Given a recorded session with one full turn
        let resume = SpyResume()
        let sut = makeViewModel(
            recorder: MockRecording(),
            detector: MockDetector(scriptedEvents: []),
            resume: resume
        )
        let id = UUID()
        let session = ChatSession(
            id: id,
            title: "Earlier",
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 10),
            messages: [
                ChatMessage(role: .user, text: "previous question", createdAt: Date(timeIntervalSince1970: 0)),
                ChatMessage(role: .assistant, text: "previous answer", createdAt: Date(timeIntervalSince1970: 5)),
            ]
        )

        // When the session is resumed
        await sut.resume(session)

        // Then the full transcript is shown and the restore use case received the session
        #expect(sut.messages.map(\.text) == ["previous question", "previous answer"])
        #expect(await resume.sessions == [id])
    }

    @Test("beginNewSession clears the live view and delegates to the use case")
    func beginNewSessionResets() async {
        // Given a view model carrying a resumed turn
        let startNew = SpyStartNew()
        let sut = makeViewModel(
            recorder: MockRecording(),
            detector: MockDetector(scriptedEvents: []),
            startNew: startNew
        )
        await sut.resume(
            ChatSession(
                id: UUID(),
                title: "Earlier",
                createdAt: Date(timeIntervalSince1970: 0),
                updatedAt: Date(timeIntervalSince1970: 0),
                messages: [ChatMessage(role: .user, text: "old", createdAt: Date(timeIntervalSince1970: 0))]
            )
        )

        // When a new session begins
        await sut.beginNewSession()

        // Then the live view is cleared and the start-new use case is invoked
        #expect(sut.messages.isEmpty)
        #expect(await startNew.count == 1)
    }
}
