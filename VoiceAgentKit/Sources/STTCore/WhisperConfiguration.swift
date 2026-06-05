//
//  WhisperConfiguration.swift
//  STTCore
//

import Foundation

/// Connection settings for the self-hosted Whisper STT service.
///
/// The base URL is injected so the endpoint can be repointed (e.g. from a Mac's
/// LAN address to a remote server) without code changes.
public struct WhisperConfiguration: Sendable {

    /// Scheme + host + port of the STT service, e.g. `http://192.168.0.35:8000`.
    public let baseURL: URL

    /// Path of the transcription endpoint.
    public let path: String

    /// The multipart form field name the server expects for the audio file.
    public let fileFieldName: String

    /// Request timeout in seconds.
    public let timeout: TimeInterval

    public init(
        baseURL: URL,
        path: String = "/api/v1/stt",
        fileFieldName: String = "file",
        timeout: TimeInterval = 30
    ) {
        self.baseURL = baseURL
        self.path = path
        self.fileFieldName = fileFieldName
        self.timeout = timeout
    }

    /// The fully resolved endpoint URL.
    public var endpoint: URL {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.path = path
        return components?.url ?? baseURL
    }
}
