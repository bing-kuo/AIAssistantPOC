//
//  SpeechPipeline.swift
//  AIAssistantPOC
//

import Foundation
import STTCore

protocol SpeechPipeline: Sendable {
    func process(_ audio: [Float]) async throws -> String
}

struct SttSpeechPipeline: SpeechPipeline {
    let recognizer: any SpeechRecognizing
    var sampleRate: Int = 16_000

    func process(_ audio: [Float]) async throws -> String {
        let transcription = try await recognizer.transcribe(audio, sampleRate: sampleRate)
        return transcription.text
    }
}

struct StubSpeechPipeline: SpeechPipeline {
    func process(_ audio: [Float]) async throws -> String {
        try await Task.sleep(for: .milliseconds(800))
        let seconds = Double(audio.count) / 16_000
        return String(format: "(stub) %.1fs of speech", seconds)
    }
}
