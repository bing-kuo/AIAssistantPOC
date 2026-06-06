//
//  AVUtteranceSpeaker.swift
//  AppleTTS
//

import AVFoundation
import VoiceAgentDomain

@MainActor
final class AVUtteranceSpeaker: NSObject, UtteranceSpeaking {

    private let synthesizer = AVSpeechSynthesizer()
    private var continuation: CheckedContinuation<Void, Error>?

    override init() {
        super.init()
        synthesizer.delegate = self
        #if !os(macOS)
        synthesizer.usesApplicationAudioSession = true
        #endif
    }

    func availableVoices() -> [VoiceOption] {
        AVSpeechSynthesisVoice.speechVoices().map { voice in
            VoiceOption(
                identifier: voice.identifier,
                language: voice.language,
                quality: VoiceQuality(voice.quality)
            )
        }
    }

    func speak(text: String, voiceID: String?, rate: Float, pitch: Float) async throws {
        let utterance = AVSpeechUtterance(string: text)
        if let voiceID, let voice = AVSpeechSynthesisVoice(identifier: voiceID) {
            utterance.voice = voice
        }
        utterance.rate = rate
        utterance.pitchMultiplier = pitch

        let restoreSession = engagePlaybackSession()
        defer { restoreSession() }

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                self.continuation = continuation
                self.synthesizer.speak(utterance)
            }
        } onCancel: {
            Task { @MainActor in self.synthesizer.stopSpeaking(at: .immediate) }
        }
    }

    private func engagePlaybackSession() -> @MainActor () -> Void {
        #if os(macOS)
        return {}
        #else
        let session = AVAudioSession.sharedInstance()
        let previousCategory = session.category
        let previousMode = session.mode
        let previousOptions = session.categoryOptions
        do {
            try session.setCategory(
                .playAndRecord,
                mode: .spokenAudio,
                options: [.duckOthers, .defaultToSpeaker, .allowBluetooth]
            )
            try session.setActive(true)
            TTSLog.synthesizer.info("Playback audio session engaged (spokenAudio)")
        } catch {
            TTSLog.synthesizer.error("Playback session config failed: \(error.localizedDescription, privacy: .public)")
        }
        return {
            do {
                try session.setCategory(previousCategory, mode: previousMode, options: previousOptions)
                try session.setActive(true)
            } catch {
                TTSLog.synthesizer.error("Playback session restore failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        #endif
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    private func finish(with error: Error?) {
        guard let continuation else { return }
        self.continuation = nil
        if let error {
            continuation.resume(throwing: error)
        } else {
            continuation.resume()
        }
    }
}

extension AVUtteranceSpeaker: AVSpeechSynthesizerDelegate {

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in self.finish(with: nil) }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in self.finish(with: TTSError.cancelled) }
    }
}

private extension VoiceQuality {
    init(_ quality: AVSpeechSynthesisVoiceQuality) {
        switch quality {
        case .premium: self = .premium
        case .enhanced: self = .enhanced
        default: self = .default
        }
    }
}
