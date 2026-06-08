//
//  ChatSessionSummary.swift
//  AIAssistantPOC
//

import Foundation

nonisolated struct ChatSessionSummary: Sendable, Identifiable, Equatable {
    let id: UUID
    let title: String
    let updatedAt: Date
    let lastMessagePreview: String
}
