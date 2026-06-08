//
//  ChatSessionReadRepository.swift
//  AIAssistantPOC
//

import Foundation

protocol ChatSessionReadRepository: Sendable {
    func summaries() async throws -> [ChatSessionSummary]
    func session(id: UUID) async throws -> ChatSession?
}
