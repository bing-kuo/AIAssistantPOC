//
//  GenerateReplyUseCase.swift
//  AIAssistantPOC
//

import Foundation

protocol GenerateReplyUseCase: Sendable {
    func callAsFunction(_ userText: String) -> AsyncThrowingStream<String, Error>
}
