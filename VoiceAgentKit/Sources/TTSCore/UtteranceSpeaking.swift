//
//  UtteranceSpeaking.swift
//  TTSCore
//

import Foundation

protocol UtteranceSpeaking: Sendable {
    func availableVoices() async -> [VoiceOption]
    func speak(text: String, voiceID: String?, rate: Float, pitch: Float) async throws
    func stop() async
}
