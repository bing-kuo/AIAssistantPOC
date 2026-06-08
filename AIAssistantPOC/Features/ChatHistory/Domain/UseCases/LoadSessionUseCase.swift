//
//  LoadSessionUseCase.swift
//  AIAssistantPOC
//

import Foundation

protocol LoadSessionUseCase: Sendable {
    func callAsFunction(_ id: UUID) async -> ChatSession?
}
