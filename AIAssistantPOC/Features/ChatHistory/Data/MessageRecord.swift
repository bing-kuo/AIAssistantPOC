//
//  MessageRecord.swift
//  AIAssistantPOC
//

import Foundation
import SwiftData

@Model
nonisolated final class MessageRecord {
    @Attribute(.unique) var id: UUID
    var roleRaw: String
    var text: String
    var createdAt: Date
    var session: SessionRecord?

    init(id: UUID, roleRaw: String, text: String, createdAt: Date) {
        self.id = id
        self.roleRaw = roleRaw
        self.text = text
        self.createdAt = createdAt
    }

    convenience init(from message: ChatMessage) {
        self.init(id: message.id, roleRaw: message.role.rawValue, text: message.text, createdAt: message.createdAt)
    }
}
