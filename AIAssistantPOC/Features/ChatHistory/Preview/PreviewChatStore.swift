//
//  PreviewChatStore.swift
//  AIAssistantPOC
//

import Foundation

struct PreviewChatStore: ChatSessionReading, ChatSessionWriting {
    var sessions: [ChatSession]

    init(sessions: [ChatSession] = PreviewChatStore.sample) {
        self.sessions = sessions
    }

    func summaries() async throws -> [ChatSessionSummary] {
        sessions
            .sorted { $0.updatedAt > $1.updatedAt }
            .map { session in
                ChatSessionSummary(
                    id: session.id,
                    title: session.title,
                    updatedAt: session.updatedAt,
                    lastMessagePreview: String((session.messages.last?.text ?? "").prefix(40))
                )
            }
    }

    func session(id: UUID) async throws -> ChatSession? {
        sessions.first { $0.id == id }
    }

    func createSession(title: String, firstMessage: ChatMessage) async throws -> UUID { UUID() }
    func append(_ message: ChatMessage, to sessionID: UUID) async throws {}
    func deleteSession(id: UUID) async throws {}

    static let sample: [ChatSession] = [
        ChatSession(
            id: UUID(),
            title: "Weekend plans",
            createdAt: Date(timeIntervalSince1970: 1_000),
            updatedAt: Date(timeIntervalSince1970: 2_000),
            messages: [
                ChatMessage(role: .user, text: "What should I do this weekend?", createdAt: Date(timeIntervalSince1970: 1_000)),
                ChatMessage(role: .assistant, text: "How about a hike and a good book?", createdAt: Date(timeIntervalSince1970: 1_100)),
            ]
        ),
        ChatSession(
            id: UUID(),
            title: "Dinner ideas",
            createdAt: Date(timeIntervalSince1970: 500),
            updatedAt: Date(timeIntervalSince1970: 900),
            messages: [
                ChatMessage(role: .user, text: "Suggest a quick dinner.", createdAt: Date(timeIntervalSince1970: 500)),
                ChatMessage(role: .assistant, text: "Pasta with garlic and olive oil.", createdAt: Date(timeIntervalSince1970: 600)),
            ]
        ),
    ]
}
