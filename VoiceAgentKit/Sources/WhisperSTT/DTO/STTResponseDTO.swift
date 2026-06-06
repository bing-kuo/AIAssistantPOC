//
//  STTResponseDTO.swift
//  WhisperSTT
//

import Foundation
import VoiceAgentDomain

/// Wire representation of the Whisper server's `/api/v1/stt` JSON response.
///
/// Kept internal to the Data layer; mapped to ``Transcription`` so the DTO never
/// leaks into the consumer-facing API.
struct STTResponseDTO: Decodable {
    let text: String
    let language: String?

    func toDomain() -> Transcription {
        Transcription(text: text.trimmingCharacters(in: .whitespacesAndNewlines), language: language)
    }
}
