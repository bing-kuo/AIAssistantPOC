//
//  PreviewConversationManager.swift
//  AIAssistantPOC
//

import Foundation

struct PreviewConversationManager: ConversationManaging {
    func respond(to userText: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                for word in ["This ", "is ", "a ", "preview ", "reply."] {
                    continuation.yield(word)
                }
                continuation.finish()
            }
        }
    }

    func reset() async {}
}
