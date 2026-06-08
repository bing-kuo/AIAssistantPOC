//
//  PreviewSpeechSynthesizer.swift
//  AIAssistantPOC
//

import VoiceAgentDomain

struct PreviewSpeechSynthesizer: SpeechSynthesizing {
    func speak(_ text: String) async throws {}
    func stop() async {}
}
