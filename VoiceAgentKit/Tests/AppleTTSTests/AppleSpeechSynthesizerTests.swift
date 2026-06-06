//
//  AppleSpeechSynthesizerTests.swift
//  AppleTTSTests
//

import Testing
import VoiceAgentDomain
@testable import AppleTTS

private actor FakeSpeaker: UtteranceSpeaking {
    let voices: [VoiceOption]
    private(set) var spokenText: String?
    private(set) var spokenVoiceID: String?
    private(set) var stopCount = 0

    init(voices: [VoiceOption]) { self.voices = voices }

    func availableVoices() async -> [VoiceOption] { voices }

    func speak(text: String, voiceID: String?, rate: Float, pitch: Float) async throws {
        spokenText = text
        spokenVoiceID = voiceID
    }

    func stop() async { stopCount += 1 }
}

private let sampleVoices = [
    VoiceOption(identifier: "zh.premium", language: "zh-TW", quality: .premium),
    VoiceOption(identifier: "en.default", language: "en-US", quality: .default),
]

@Suite("AppleSpeechSynthesizer")
struct AppleSpeechSynthesizerTests {

    @Test("Chinese-dominant text speaks with the Chinese voice")
    func chineseText() async throws {
        // Given
        let speaker = FakeSpeaker(voices: sampleVoices)
        let sut = AppleSpeechSynthesizer(speaker: speaker)

        // When
        try await sut.speak("今天天氣很好")

        // Then
        #expect(await speaker.spokenVoiceID == "zh.premium")
        #expect(await speaker.spokenText == "今天天氣很好")
    }

    @Test("English-dominant text speaks with the English voice")
    func englishText() async throws {
        // Given
        let speaker = FakeSpeaker(voices: sampleVoices)
        let sut = AppleSpeechSynthesizer(speaker: speaker)

        // When
        try await sut.speak("Open the settings please")

        // Then
        #expect(await speaker.spokenVoiceID == "en.default")
    }

    @Test("empty text throws without speaking")
    func emptyTextThrows() async {
        // Given
        let speaker = FakeSpeaker(voices: sampleVoices)
        let sut = AppleSpeechSynthesizer(speaker: speaker)

        // When / Then
        await #expect(throws: TTSError.emptyText) {
            try await sut.speak("   ")
        }
        #expect(await speaker.spokenText == nil)
    }

    @Test("stop forwards to the underlying speaker")
    func stopForwards() async {
        // Given
        let speaker = FakeSpeaker(voices: sampleVoices)
        let sut = AppleSpeechSynthesizer(speaker: speaker)

        // When
        await sut.stop()

        // Then
        #expect(await speaker.stopCount == 1)
    }
}
