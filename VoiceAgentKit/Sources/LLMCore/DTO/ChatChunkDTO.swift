//
//  ChatChunkDTO.swift
//  LLMCore
//

import Foundation

struct ChatChunkDTO: Decodable {
    let delta: String?
    let error: String?

    func toEvent() -> SSEEvent {
        if let error { return .failure(error) }
        return .delta(delta ?? "")
    }
}
