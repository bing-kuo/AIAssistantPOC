//
//  DeleteSessionUseCase.swift
//  AIAssistantPOC
//

import Foundation

protocol DeleteSessionUseCase: Sendable {
    func callAsFunction(_ id: UUID) async
}
