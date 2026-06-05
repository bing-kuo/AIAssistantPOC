//
//  SpeechRecognizing.swift
//  STTCore
//

import Foundation

/// The result of transcribing an audio utterance.
public struct Transcription: Sendable, Equatable {

    /// The recognized text.
    public let text: String

    /// The detected language code, if the backend reports one.
    public let language: String?

    public init(text: String, language: String? = nil) {
        self.text = text
        self.language = language
    }
}

/// Errors raised while transcribing audio.
public enum SpeechRecognitionError: Error, Sendable, Equatable {
    case emptyAudio
    case invalidResponse
    case server(status: Int)
    case transport(String)
    case decoding(String)
}

/// An abstraction boundary for converting captured audio into text.
///
/// Consumers depend only on this protocol (DIP), allowing the concrete backend
/// (self-hosted Whisper over HTTP, an on-device recognizer, or a fallback
/// composition of both) to be swapped without changing callers.
public protocol SpeechRecognizing: Sendable {

    /// Transcribes a mono PCM utterance.
    /// - Parameters:
    ///   - audio: Float32 samples in `-1.0...1.0`.
    ///   - sampleRate: The sample rate of `audio`, in Hz.
    /// - Returns: The recognized ``Transcription``.
    /// - Throws: ``SpeechRecognitionError`` on empty input, transport, or decoding failure.
    func transcribe(_ audio: [Float], sampleRate: Int) async throws -> Transcription
}
