//
//  SwiftDataChatStore.swift
//  AIAssistantPOC
//

import Foundation
import SwiftData

@ModelActor
actor SwiftDataChatStore: ChatSessionReading, ChatSessionWriting {

    private nonisolated static let previewLength = 40

    func summaries() async throws -> [ChatSessionSummary] {
        let descriptor = FetchDescriptor<SessionRecord>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map(Self.summary(from:))
    }

    func session(id: UUID) async throws -> ChatSession? {
        guard let record = try fetchRecord(id: id) else { return nil }
        return Self.session(from: record)
    }

    func createSession(title: String, firstMessage: ChatMessage) async throws -> UUID {
        let record = SessionRecord(
            id: UUID(),
            title: title,
            createdAt: firstMessage.createdAt,
            updatedAt: firstMessage.createdAt
        )
        modelContext.insert(record)
        let message = MessageRecord(from: firstMessage)
        message.session = record
        modelContext.insert(message)
        try modelContext.save()
        return record.id
    }

    func append(_ message: ChatMessage, to sessionID: UUID) async throws {
        guard let record = try fetchRecord(id: sessionID) else { return }
        let messageRecord = MessageRecord(from: message)
        messageRecord.session = record
        modelContext.insert(messageRecord)
        record.updatedAt = message.createdAt
        try modelContext.save()
    }

    func deleteSession(id: UUID) async throws {
        guard let record = try fetchRecord(id: id) else { return }
        modelContext.delete(record)
        try modelContext.save()
    }

    private func fetchRecord(id: UUID) throws -> SessionRecord? {
        var descriptor = FetchDescriptor<SessionRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private nonisolated static func summary(from record: SessionRecord) -> ChatSessionSummary {
        let preview = record.messages
            .sorted { $0.createdAt < $1.createdAt }
            .last?
            .text ?? ""
        return ChatSessionSummary(
            id: record.id,
            title: record.title,
            updatedAt: record.updatedAt,
            lastMessagePreview: String(preview.prefix(previewLength))
        )
    }

    private nonisolated static func session(from record: SessionRecord) -> ChatSession {
        let messages = record.messages
            .sorted { $0.createdAt < $1.createdAt }
            .map { record in
                ChatMessage(
                    id: record.id,
                    role: ChatRole(rawValue: record.roleRaw) ?? .user,
                    text: record.text,
                    createdAt: record.createdAt
                )
            }
        return ChatSession(
            id: record.id,
            title: record.title,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt,
            messages: messages
        )
    }
}
