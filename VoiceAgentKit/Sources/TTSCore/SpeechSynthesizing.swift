//
//  SpeechSynthesizing.swift
//  TTSCore
//

import Foundation

/// Errors raised while synthesizing or playing speech.
public enum TTSError: Error, Sendable, Equatable {
    case emptyText
    case cancelled
    case synthesisFailed(String)
}

/// Tunable, framework-free synthesis settings.
///
/// Values are neutral so they survive a backend swap: `rate` follows the
/// platform convention where `0.5` is a natural default, and `pitch` is a
/// multiplier around `1.0`.
public struct TTSConfiguration: Sendable, Equatable {

    /// Speaking rate; `0.5` reads naturally on Apple voices.
    public let rate: Float

    /// Pitch multiplier; `1.0` is the unmodified voice.
    public let pitch: Float

    public init(rate: Float = 0.5, pitch: Float = 1.0) {
        self.rate = rate
        self.pitch = pitch
    }
}

/// An abstraction boundary for turning text into spoken audio.
///
/// Consumers depend only on this protocol (DIP), so the concrete engine
/// (Apple's on-device `AVSpeechSynthesizer`, or a future cloud TTS that
/// downloads and plays audio) can be swapped without changing callers.
public protocol SpeechSynthesizing: Sendable {

    /// Speaks the given text, returning when playback has finished.
    /// - Parameter text: The text to vocalize. The implementation picks a voice
    ///   for the dominant language of the text.
    /// - Throws: ``TTSError`` on empty input, cancellation, or synthesis failure.
    func speak(_ text: String) async throws

    /// Stops any in-progress playback immediately.
    func stop() async
}
