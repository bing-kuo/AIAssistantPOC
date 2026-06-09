//
//  TranscribeUtteranceInteractor.swift
//  AIAssistantPOC
//

import Foundation
import VoiceAgentDomain

struct TranscribeUtteranceInteractor: TranscribeUtteranceUseCase {

    private let recognizer: any SpeechRecognizing
    private let sampleRate: Int

    init(recognizer: any SpeechRecognizing, sampleRate: Int = 16_000) {
        self.recognizer = recognizer
        self.sampleRate = sampleRate
    }

    func callAsFunction(_ audio: [Float]) async throws -> String {
        do {
            return try await recognizer.transcribe(audio, sampleRate: sampleRate).text
        } catch SpeechRecognitionError.transport {
            return try await recognizer.transcribe(audio, sampleRate: sampleRate).text
        }
    }
}
