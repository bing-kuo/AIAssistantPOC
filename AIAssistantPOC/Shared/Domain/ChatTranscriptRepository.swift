//
//  ChatTranscriptRepository.swift
//  AIAssistantPOC
//

import Foundation

protocol ChatTranscriptRepository: Sendable {
    func beginNewSession() async
    func resume(sessionID: UUID) async
    func recordUserMessage(_ text: String) async
    func recordAssistantMessage(_ text: String) async
}
