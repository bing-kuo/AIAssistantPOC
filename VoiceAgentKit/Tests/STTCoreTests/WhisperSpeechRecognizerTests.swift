//
//  WhisperSpeechRecognizerTests.swift
//  STTCoreTests
//

import Foundation
import Testing
@testable import STTCore

private final class StubURLProtocol: URLProtocol {
    struct Stub: Sendable { let status: Int; let body: Data }

    nonisolated(unsafe) static var stub: Stub?
    nonisolated(unsafe) static var lastRequest: URLRequest?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        StubURLProtocol.lastRequest = request
        let stub = StubURLProtocol.stub ?? Stub(status: 200, body: Data())
        let response = HTTPURLResponse(url: request.url!, statusCode: stub.status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private func makeRecognizer() -> WhisperSpeechRecognizer {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [StubURLProtocol.self]
    let session = URLSession(configuration: config)
    let whisper = WhisperConfiguration(baseURL: URL(string: "http://127.0.0.1:8000")!)
    return WhisperSpeechRecognizer(configuration: whisper, session: session)
}

@Suite("WhisperSpeechRecognizer", .serialized)
struct WhisperSpeechRecognizerTests {

    @Test("maps a successful response to a trimmed Transcription and posts correctly")
    func successMapsResponse() async throws {
        // Given
        StubURLProtocol.stub = .init(
            status: 200,
            body: Data(#"{"text": " hello world ", "language": "en"}"#.utf8)
        )
        let sut = makeRecognizer()

        // When
        let result = try await sut.transcribe([0.1, -0.1, 0.2], sampleRate: 16_000)

        // Then
        #expect(result == Transcription(text: "hello world", language: "en"))
        #expect(StubURLProtocol.lastRequest?.httpMethod == "POST")
        #expect(StubURLProtocol.lastRequest?.url?.absoluteString == "http://127.0.0.1:8000/api/v1/stt")
        let contentType = StubURLProtocol.lastRequest?.value(forHTTPHeaderField: "Content-Type") ?? ""
        #expect(contentType.hasPrefix("multipart/form-data; boundary="))
    }

    @Test("throws server error on non-2xx status")
    func serverErrorThrows() async {
        // Given
        StubURLProtocol.stub = .init(status: 500, body: Data())
        let sut = makeRecognizer()

        // When / Then
        await #expect(throws: SpeechRecognitionError.server(status: 500)) {
            _ = try await sut.transcribe([0.1, 0.2], sampleRate: 16_000)
        }
    }

    @Test("throws decoding error on malformed JSON")
    func decodingErrorThrows() async {
        // Given
        StubURLProtocol.stub = .init(status: 200, body: Data("not json".utf8))
        let sut = makeRecognizer()

        // When
        var thrown: SpeechRecognitionError?
        do { _ = try await sut.transcribe([0.1], sampleRate: 16_000) }
        catch let error as SpeechRecognitionError { thrown = error }
        catch { Issue.record("unexpected error: \(error)") }

        // Then
        guard case .decoding = thrown else {
            Issue.record("expected .decoding, got \(String(describing: thrown))")
            return
        }
    }

    @Test("rejects empty audio without hitting the network")
    func emptyAudioThrows() async {
        let sut = makeRecognizer()
        await #expect(throws: SpeechRecognitionError.emptyAudio) {
            _ = try await sut.transcribe([], sampleRate: 16_000)
        }
    }

    @Test("multipart body wraps the WAV with the configured field name")
    func multipartBodyStructure() {
        // Given
        let wav = Data("RIFFxxxxWAVE".utf8)
        // When
        let body = WhisperSpeechRecognizer.multipartBody(wav: wav, boundary: "B", fieldName: "file", filename: "audio.wav")
        let text = String(decoding: body, as: UTF8.self)
        // Then
        #expect(text.hasPrefix("--B\r\n"))
        #expect(text.contains(#"name="file"; filename="audio.wav""#))
        #expect(text.contains("Content-Type: audio/wav"))
        #expect(text.contains("RIFFxxxxWAVE"))
        #expect(text.hasSuffix("\r\n--B--\r\n"))
    }
}
