//
//  ConversationManaging.swift
//  AIAssistantPOC
//

import Foundation
import VoiceAgentDomain

protocol ConversationManaging: Sendable {
    func respond(to userText: String) -> AsyncThrowingStream<String, Error>
    func restore(_ messages: [LLMMessage]) async
    func reset() async
}
