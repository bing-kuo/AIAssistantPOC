//
//  ConversationManager.swift
//  AIAssistantPOC
//

import Foundation
import LLMCore

actor ConversationManager: ConversationManaging {

    private let responder: any LLMResponding
    private let systemPrompt: String
    private let maxMessages: Int
    private var history: [LLMMessage] = []

    init(responder: any LLMResponding, systemPrompt: String, maxMessages: Int = 12) {
        self.responder = responder
        self.systemPrompt = systemPrompt
        let normalized = max(2, maxMessages)
        self.maxMessages = normalized - (normalized % 2)
    }

    nonisolated func respond(to userText: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let messages = await self.prepare(userText)
                    var assistant = ""
                    for try await delta in self.responder.stream(messages) {
                        if Task.isCancelled { break }
                        assistant += delta
                        continuation.yield(delta)
                    }
                    await self.commit(user: userText, assistant: assistant)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func reset() {
        history.removeAll()
    }

    private func prepare(_ userText: String) -> [LLMMessage] {
        var messages = [LLMMessage(role: .system, content: systemPrompt)]
        messages.append(contentsOf: history)
        messages.append(LLMMessage(role: .user, content: userText))
        return messages
    }

    private func commit(user: String, assistant: String) {
        guard !assistant.isEmpty else { return }
        history.append(LLMMessage(role: .user, content: user))
        history.append(LLMMessage(role: .assistant, content: assistant))
        if history.count > maxMessages {
            history.removeFirst(history.count - maxMessages)
        }
    }
}
