//
//  AppleSpeechSynthesizer.swift
//  TTSCore
//

import Foundation

/// ``SpeechSynthesizing`` backed by Apple's on-device `AVSpeechSynthesizer`.
///
/// Detects the dominant language of the text, selects the best available voice
/// for it (preferring premium/enhanced voices), and plays the utterance. A
/// single voice reads the whole reply; embedded foreign words are read by it.
public actor AppleSpeechSynthesizer: SpeechSynthesizing {

    private let speaker: any UtteranceSpeaking
    private let configuration: TTSConfiguration

    /// Builds a synthesizer backed by the live `AVSpeechSynthesizer`.
    @MainActor
    public static func live(configuration: TTSConfiguration = TTSConfiguration()) -> AppleSpeechSynthesizer {
        AppleSpeechSynthesizer(speaker: AVUtteranceSpeaker(), configuration: configuration)
    }

    init(speaker: any UtteranceSpeaking, configuration: TTSConfiguration = TTSConfiguration()) {
        self.speaker = speaker
        self.configuration = configuration
    }

    public func speak(_ text: String) async throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TTSError.emptyText }
        if Task.isCancelled { throw TTSError.cancelled }

        let language = DominantLanguageDetector.detect(trimmed)
        let voices = await speaker.availableVoices()
        let voice = VoiceSelector.select(for: language, from: voices)

        TTSLog.synthesizer.info("Speak language=\(language.bcp47, privacy: .public) voice=\(voice?.identifier ?? "default", privacy: .public) chars=\(trimmed.count, privacy: .public)")

        do {
            try await speaker.speak(
                text: trimmed,
                voiceID: voice?.identifier,
                rate: configuration.rate,
                pitch: configuration.pitch
            )
        } catch let error as TTSError {
            throw error
        } catch {
            throw TTSError.synthesisFailed(error.localizedDescription)
        }
    }

    public func stop() async {
        await speaker.stop()
    }
}
