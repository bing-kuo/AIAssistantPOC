//
//  FetchSessionSummariesUseCase.swift
//  AIAssistantPOC
//

import Foundation

protocol FetchSessionSummariesUseCase: Sendable {
    func callAsFunction() async -> [ChatSessionSummary]
}
