//
//  WhisperSpeechRecognizer.swift
//  WhisperSTT
//

import Foundation
import VoiceAgentDomain

/// ``SpeechRecognizing`` backed by a self-hosted Whisper HTTP service.
///
/// Stateless and `Sendable`: it encodes the utterance to WAV, posts it as
/// multipart form data, and maps the JSON response to a ``Transcription``.
public struct WhisperSpeechRecognizer: SpeechRecognizing {

    private let configuration: WhisperConfiguration
    private let session: URLSession

    public init(configuration: WhisperConfiguration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    public func transcribe(_ audio: [Float], sampleRate: Int) async throws -> Transcription {
        guard !audio.isEmpty else { throw SpeechRecognitionError.emptyAudio }

        #if DEBUG
        if AudioProbe.isEnabled {
            let stats = AudioProbe.analyze(audio, sampleRate: sampleRate)
            STTLog.recognizer.info("STT input \(stats.description, privacy: .public)")
            if let url = AudioProbe.dumpWAV(audio, sampleRate: sampleRate, label: "utterance") {
                STTLog.recognizer.info("STT input WAV written: \(url.lastPathComponent, privacy: .public)")
            }
        }
        #endif

        let wav = WAVEncoder.encode(audio, sampleRate: sampleRate)
        let boundary = "Boundary-\(UUID().uuidString)"

        var request = URLRequest(url: configuration.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = configuration.timeout
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.multipartBody(
            wav: wav,
            boundary: boundary,
            fieldName: configuration.fileFieldName,
            filename: "audio.wav"
        )

        STTLog.recognizer.info("POST \(self.configuration.endpoint.absoluteString, privacy: .public) bytes=\(wav.count, privacy: .public)")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            STTLog.recognizer.error("STT transport error: \(error.localizedDescription, privacy: .public)")
            throw SpeechRecognitionError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw SpeechRecognitionError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            STTLog.recognizer.error("STT server status \(http.statusCode, privacy: .public)")
            throw SpeechRecognitionError.server(status: http.statusCode)
        }

        do {
            let dto = try JSONDecoder().decode(STTResponseDTO.self, from: data)
            let transcription = dto.toDomain()
            STTLog.recognizer.info("STT transcription chars=\(transcription.text.count, privacy: .public)")
            return transcription
        } catch {
            throw SpeechRecognitionError.decoding(error.localizedDescription)
        }
    }

    static func multipartBody(wav: Data, boundary: String, fieldName: String, filename: String) -> Data {
        var body = Data()
        func append(_ string: String) { body.append(contentsOf: Array(string.utf8)) }

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(filename)\"\r\n")
        append("Content-Type: audio/wav\r\n\r\n")
        body.append(wav)
        append("\r\n--\(boundary)--\r\n")
        return body
    }
}
