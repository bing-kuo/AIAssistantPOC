//
//  AppPreferences.swift
//  AIAssistantPOC
//

import Foundation

nonisolated struct AppPreferences: Sendable, Equatable {
    var voiceResponsesEnabled: Bool
    var serverDisplayURL: String

    static let `default` = AppPreferences(voiceResponsesEnabled: true, serverDisplayURL: "")
}
