//
//  ResumeConversationUseCase.swift
//  AIAssistantPOC
//

import Foundation

protocol ResumeConversationUseCase: Sendable {
    func callAsFunction(_ session: ChatSession) async
}
