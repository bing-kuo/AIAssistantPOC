//
//  StartNewConversationUseCase.swift
//  AIAssistantPOC
//

import Foundation

protocol StartNewConversationUseCase: Sendable {
    func callAsFunction() async
}
