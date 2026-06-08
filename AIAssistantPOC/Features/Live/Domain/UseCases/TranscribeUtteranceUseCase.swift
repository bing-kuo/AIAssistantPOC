//
//  TranscribeUtteranceUseCase.swift
//  AIAssistantPOC
//

import Foundation

protocol TranscribeUtteranceUseCase: Sendable {
    func callAsFunction(_ audio: [Float]) async throws -> String
}
