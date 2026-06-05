//
//  PreviewAudioRecorder.swift
//  AIAssistantPOC
//

import VoiceCore

struct PreviewAudioRecorder: AudioRecording {
    func requestPermission() async -> Bool { true }

    func start() async throws -> AsyncStream<AudioFrame> {
        AsyncStream { $0.finish() }
    }

    func stop() async {}
}
