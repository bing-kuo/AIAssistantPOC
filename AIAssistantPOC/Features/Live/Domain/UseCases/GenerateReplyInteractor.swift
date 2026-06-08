//
//  GenerateReplyInteractor.swift
//  AIAssistantPOC
//

import Foundation
import VoiceAgentDomain

struct GenerateReplyInteractor: GenerateReplyUseCase {

    private let responder: any LLMResponding
    private let conversation: any ConversationRepository
    private let systemPrompt: String

    init(responder: any LLMResponding, conversation: any ConversationRepository, systemPrompt: String) {
        self.responder = responder
        self.conversation = conversation
        self.systemPrompt = systemPrompt
    }

    func callAsFunction(_ userText: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let messages = await prepare(userText)
                    var assistant = ""
                    for try await delta in responder.stream(messages) {
                        if Task.isCancelled { break }
                        assistant += delta
                        continuation.yield(delta)
                    }
                    await conversation.record(userMessage: userText, assistantReply: assistant)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func prepare(_ userText: String) async -> [LLMMessage] {
        var messages = [LLMMessage(role: .system, content: systemPrompt)]
        messages.append(contentsOf: await conversation.context())
        messages.append(LLMMessage(role: .user, content: userText))
        return messages
    }
}
