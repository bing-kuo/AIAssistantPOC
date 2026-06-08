//
//  SessionRecord.swift
//  AIAssistantPOC
//

import Foundation
import SwiftData

@Model
nonisolated final class SessionRecord {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \MessageRecord.session)
    var messages: [MessageRecord]

    init(id: UUID, title: String, createdAt: Date, updatedAt: Date, messages: [MessageRecord] = []) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messages = messages
    }
}
