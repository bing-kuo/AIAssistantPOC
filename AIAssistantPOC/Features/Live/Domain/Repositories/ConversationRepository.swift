//
//  ConversationRepository.swift
//  AIAssistantPOC
//

import Foundation
import VoiceAgentDomain

protocol ConversationRepository: Sendable {
    func context() async -> [LLMMessage]
    func record(userMessage: String, assistantReply: String) async
    func restore(_ messages: [LLMMessage]) async
    func reset() async
}
