//
//  ChatTranscriptRecording.swift
//  AIAssistantPOC
//

import Foundation

protocol ChatTranscriptRecording: Sendable {
    func beginNewSession() async
    func resume(sessionID: UUID) async
    func recordUserMessage(_ text: String) async
    func recordAssistantMessage(_ text: String) async
}
