//
//  ChatRequestDTO.swift
//  LLMCore
//

import Foundation

struct ChatRequestDTO: Encodable {

    struct MessageDTO: Encodable {
        let role: String
        let content: String
    }

    let messages: [MessageDTO]

    static func fromDomain(_ messages: [LLMMessage]) -> ChatRequestDTO {
        ChatRequestDTO(
            messages: messages.map { MessageDTO(role: $0.role.rawValue, content: $0.content) }
        )
    }
}
