//
//  ChatSessionReading.swift
//  AIAssistantPOC
//

import Foundation

protocol ChatSessionReading: Sendable {
    func summaries() async throws -> [ChatSessionSummary]
    func session(id: UUID) async throws -> ChatSession?
}
