//
//  ProcessVoiceTurnUseCase.swift
//  AIAssistantPOC
//

import Foundation

enum VoiceTurnEvent: Sendable, Equatable {
    case userTranscribed(String)
    case replyDelta(String)
    case replyCompleted(String)
    case speaking
}

protocol ProcessVoiceTurnUseCase: Sendable {
    func callAsFunction(_ audio: [Float]) -> AsyncThrowingStream<VoiceTurnEvent, Error>
}
