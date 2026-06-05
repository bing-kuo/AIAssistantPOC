//
//  SpeechPipeline.swift
//  AIAssistantPOC
//

import Foundation

protocol SpeechPipeline: Sendable {
    func process(_ audio: [Float]) async throws -> String
}

struct StubSpeechPipeline: SpeechPipeline {
    func process(_ audio: [Float]) async throws -> String {
        try await Task.sleep(for: .milliseconds(800))
        let seconds = Double(audio.count) / 16_000
        return String(format: "(stub) STT → LLM handled %.1fs of speech", seconds)
    }
}
