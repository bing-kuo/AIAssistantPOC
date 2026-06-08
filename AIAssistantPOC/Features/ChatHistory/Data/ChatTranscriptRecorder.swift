//
//  ChatTranscriptRecorder.swift
//  AIAssistantPOC
//

import Foundation
import os

actor ChatTranscriptRecorder: ChatTranscriptRepository {

    private let writer: any ChatSessionWriteRepository
    private let titleLength: Int
    private let logger = Logger(subsystem: "AIAssistantPOC", category: "ChatTranscript")
    private var currentSessionID: UUID?

    init(writer: any ChatSessionWriteRepository, titleLength: Int = 20) {
        self.writer = writer
        self.titleLength = titleLength
    }

    func beginNewSession() {
        currentSessionID = nil
    }

    func resume(sessionID: UUID) {
        currentSessionID = sessionID
    }

    func recordUserMessage(_ text: String) async {
        let message = ChatMessage(role: .user, text: text)
        do {
            if let id = currentSessionID {
                try await writer.append(message, to: id)
            } else {
                currentSessionID = try await writer.createSession(
                    title: String(text.prefix(titleLength)),
                    firstMessage: message
                )
            }
        } catch {
            logger.error("Failed to record user message: \(error.localizedDescription, privacy: .public)")
        }
    }

    func recordAssistantMessage(_ text: String) async {
        guard let id = currentSessionID else { return }
        do {
            try await writer.append(ChatMessage(role: .assistant, text: text), to: id)
        } catch {
            logger.error("Failed to record assistant message: \(error.localizedDescription, privacy: .public)")
        }
    }
}
