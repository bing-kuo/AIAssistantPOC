//
//  VoiceSelectorTests.swift
//  TTSCoreTests
//

import Testing
@testable import TTSCore

@Suite("VoiceSelector")
struct VoiceSelectorTests {

    @Test("prefers premium over enhanced over default for the same language")
    func prefersHigherQuality() {
        // Given three English voices of differing quality
        let voices = [
            VoiceOption(identifier: "en.default", language: "en-US", quality: .default),
            VoiceOption(identifier: "en.premium", language: "en-US", quality: .premium),
            VoiceOption(identifier: "en.enhanced", language: "en-US", quality: .enhanced),
        ]
        // When
        let selected = VoiceSelector.select(for: .english, from: voices)
        // Then
        #expect(selected?.identifier == "en.premium")
    }

    @Test("matches the language by prefix and prefers the exact region")
    func matchesByPrefixPreferringExact() {
        // Given two Chinese voices of equal quality
        let voices = [
            VoiceOption(identifier: "zh.cn", language: "zh-CN", quality: .enhanced),
            VoiceOption(identifier: "zh.tw", language: "zh-TW", quality: .enhanced),
        ]
        // When asking for Traditional Chinese (zh-TW)
        let selected = VoiceSelector.select(for: .traditionalChinese, from: voices)
        // Then the exact region wins
        #expect(selected?.identifier == "zh.tw")
    }

    @Test("returns nil when no voice matches the language")
    func noMatchReturnsNil() {
        // Given only Chinese voices
        let voices = [VoiceOption(identifier: "zh.tw", language: "zh-TW", quality: .premium)]
        // When asking for English
        let selected = VoiceSelector.select(for: .english, from: voices)
        // Then
        #expect(selected == nil)
    }

    @Test("breaks ties deterministically by smallest identifier")
    func deterministicTiebreak() {
        // Given equal quality and region
        let voices = [
            VoiceOption(identifier: "en.b", language: "en-US", quality: .default),
            VoiceOption(identifier: "en.a", language: "en-US", quality: .default),
        ]
        // When
        let selected = VoiceSelector.select(for: .english, from: voices)
        // Then
        #expect(selected?.identifier == "en.a")
    }
}
