//
//  ChatSession.swift
//  AIAssistantPOC
//

import Foundation

nonisolated struct ChatSession: Sendable, Identifiable, Equatable {
    let id: UUID
    let title: String
    let createdAt: Date
    let updatedAt: Date
    let messages: [ChatMessage]
}
