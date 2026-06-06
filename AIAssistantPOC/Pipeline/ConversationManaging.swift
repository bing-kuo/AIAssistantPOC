//
//  ConversationManaging.swift
//  AIAssistantPOC
//

import Foundation

protocol ConversationManaging: Sendable {
    func respond(to userText: String) -> AsyncThrowingStream<String, Error>
    func reset() async
}
