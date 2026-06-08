//
//  ChatSessionWriteRepository.swift
//  AIAssistantPOC
//

import Foundation

protocol ChatSessionWriteRepository: Sendable {
    func createSession(title: String, firstMessage: ChatMessage) async throws -> UUID
    func append(_ message: ChatMessage, to sessionID: UUID) async throws
    func deleteSession(id: UUID) async throws
}
