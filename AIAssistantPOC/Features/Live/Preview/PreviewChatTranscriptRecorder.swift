//
//  PreviewChatTranscriptRecorder.swift
//  AIAssistantPOC
//

import Foundation

struct PreviewChatTranscriptRecorder: ChatTranscriptRecording {
    func beginNewSession() async {}
    func resume(sessionID: UUID) async {}
    func recordUserMessage(_ text: String) async {}
    func recordAssistantMessage(_ text: String) async {}
}
