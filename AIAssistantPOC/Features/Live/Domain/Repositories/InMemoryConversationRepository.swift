//
//  InMemoryConversationRepository.swift
//  AIAssistantPOC
//

import Foundation
import VoiceAgentDomain

actor InMemoryConversationRepository: ConversationRepository {

    private let maxMessages: Int
    private var history: [LLMMessage] = []

    init(maxMessages: Int = 12) {
        let normalized = max(2, maxMessages)
        self.maxMessages = normalized - (normalized % 2)
    }

    func context() -> [LLMMessage] {
        history
    }

    func record(userMessage: String, assistantReply: String) {
        guard !assistantReply.isEmpty else { return }
        history.append(LLMMessage(role: .user, content: userMessage))
        history.append(LLMMessage(role: .assistant, content: assistantReply))
        capHistory()
    }

    func restore(_ messages: [LLMMessage]) {
        history = messages
        capHistory()
    }

    func reset() {
        history.removeAll()
    }

    private func capHistory() {
        if history.count > maxMessages {
            history.removeFirst(history.count - maxMessages)
        }
    }
}
