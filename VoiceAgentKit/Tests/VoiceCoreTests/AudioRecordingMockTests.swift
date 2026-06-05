//
//  AudioRecordingMockTests.swift
//  VoiceCoreTests
//

import Testing
@testable import VoiceCore

/// In-memory ``AudioRecording`` that emits a scripted set of frames.
actor MockAudioRecorder: AudioRecording {

    private let permission: Bool
    private let framesToEmit: [AudioFrame]
    private(set) var didRequestPermission = false
    private(set) var startCount = 0
    private(set) var stopCount = 0

    init(permission: Bool = true, framesToEmit: [AudioFrame] = []) {
        self.permission = permission
        self.framesToEmit = framesToEmit
    }

    func requestPermission() async -> Bool {
        didRequestPermission = true
        return permission
    }

    func start() async throws -> AsyncStream<AudioFrame> {
        guard permission else { throw AudioRecorderError.permissionDenied }
        startCount += 1
        let frames = framesToEmit
        return AsyncStream { continuation in
            for frame in frames { continuation.yield(frame) }
            continuation.finish()
        }
    }

    func stop() async {
        stopCount += 1
    }
}

@Suite("AudioRecording contract")
struct AudioRecordingMockTests {

    @Test("granted permission allows start and streams every frame")
    func startStreamsFrames() async throws {
        // Given
        let frames = [
            AudioFrame(samples: [0.1, -0.1], frameCount: 2, rms: 0.1, timestamp: 0),
            AudioFrame(samples: [0.2, -0.2], frameCount: 2, rms: 0.2, timestamp: 0.02),
        ]
        let sut = MockAudioRecorder(permission: true, framesToEmit: frames)

        // When
        #expect(await sut.requestPermission() == true)
        let stream = try await sut.start()
        var received: [AudioFrame] = []
        for await frame in stream { received.append(frame) }

        // Then
        #expect(received == frames)
        #expect(await sut.startCount == 1)
        #expect(await sut.didRequestPermission == true)
    }

    @Test("denied permission throws on start")
    func deniedPermissionThrows() async {
        // Given
        let sut = MockAudioRecorder(permission: false)

        // When
        let granted = await sut.requestPermission()

        // Then
        #expect(granted == false)
        await #expect(throws: AudioRecorderError.permissionDenied) {
            _ = try await sut.start()
        }
    }

    @Test("stop is forwarded to the recorder")
    func stopIsForwarded() async {
        // Given
        let sut = MockAudioRecorder()
        // When
        await sut.stop()
        // Then
        #expect(await sut.stopCount == 1)
    }
}
