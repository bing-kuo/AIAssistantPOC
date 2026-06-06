//
//  ProxyLLMResponder.swift
//  LLMCore
//

import Foundation

/// ``LLMResponding`` backed by the self-hosted chat proxy over Server-Sent Events.
///
/// Stateless and `Sendable`: it posts the conversation as JSON, consumes the
/// `text/event-stream` response line by line, and forwards each text delta. The
/// provider credentials and model selection live on the proxy, not here.
public struct ProxyLLMResponder: LLMResponding {

    private let configuration: LLMConfiguration
    private let session: URLSession

    public init(configuration: LLMConfiguration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    public func stream(_ messages: [LLMMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await self.run(messages, into: continuation)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func run(
        _ messages: [LLMMessage],
        into continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws {
        guard !messages.isEmpty else { throw LLMError.emptyConversation }

        let request = try makeRequest(messages)
        LLMLog.responder.info("POST \(self.configuration.endpoint.absoluteString, privacy: .public) messages=\(messages.count, privacy: .public)")

        let bytes: URLSession.AsyncBytes
        let response: URLResponse
        do {
            (bytes, response) = try await session.bytes(for: request)
        } catch {
            LLMLog.responder.error("LLM transport error: \(error.localizedDescription, privacy: .public)")
            throw LLMError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else { throw LLMError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            LLMLog.responder.error("LLM server status \(http.statusCode, privacy: .public)")
            throw LLMError.server(status: http.statusCode)
        }

        for try await line in bytes.lines {
            if Task.isCancelled { return }
            switch SSELineParser.parse(line: line) {
            case .delta(let text):
                if !text.isEmpty { continuation.yield(text) }
            case .done:
                return
            case .failure(let message):
                LLMLog.responder.error("LLM stream error: \(message, privacy: .public)")
                throw LLMError.stream(message)
            case .none:
                continue
            }
        }
    }

    private func makeRequest(_ messages: [LLMMessage]) throws -> URLRequest {
        var request = URLRequest(url: configuration.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = configuration.timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        if let token = configuration.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        do {
            request.httpBody = try JSONEncoder().encode(ChatRequestDTO.fromDomain(messages))
        } catch {
            throw LLMError.decoding(error.localizedDescription)
        }
        return request
    }
}
