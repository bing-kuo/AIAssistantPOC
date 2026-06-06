//
//  PreviewSpeechSynthesizer.swift
//  AIAssistantPOC
//

import TTSCore

struct PreviewSpeechSynthesizer: SpeechSynthesizing {
    func speak(_ text: String) async throws {}
    func stop() async {}
}
