//
//  ProxyLLMResponderTests.swift
//  ProxyLLMTests
//

import Foundation
import Testing
import VoiceAgentDomain
@testable import ProxyLLM

private final class StubURLProtocol: URLProtocol {
    struct Stub: Sendable { let status: Int; let chunks: [String] }

    nonisolated(unsafe) static var stub: Stub?
    nonisolated(unsafe) static var lastRequest: URLRequest?
    nonisolated(unsafe) static var lastBody: Data?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        StubURLProtocol.lastRequest = request
        StubURLProtocol.lastBody = request.httpBody ?? request.bodyStreamData()
        let stub = StubURLProtocol.stub ?? Stub(status: 200, chunks: [])
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: stub.status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "text/event-stream"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        for chunk in stub.chunks {
            client?.urlProtocol(self, didLoad: Data(chunk.utf8))
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private extension URLRequest {
    func bodyStreamData() -> Data? {
        guard let stream = httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let size = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: size)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}

private func makeResponder() -> ProxyLLMResponder {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [StubURLProtocol.self]
    let session = URLSession(configuration: config)
    let llm = LLMConfiguration(baseURL: URL(string: "http://127.0.0.1:8000")!)
    return ProxyLLMResponder(configuration: llm, session: session)
}

private func collect(_ stream: AsyncThrowingStream<String, Error>) async throws -> [String] {
    var deltas: [String] = []
    for try await delta in stream { deltas.append(delta) }
    return deltas
}

@Suite("ProxyLLMResponder", .serialized)
struct ProxyLLMResponderTests {

    @Test("yields deltas in order from a chunked SSE stream and posts correctly")
    func streamsDeltas() async throws {
        // Given an SSE body split across multiple network chunks
        StubURLProtocol.stub = .init(
            status: 200,
            chunks: [
                "data: {\"delta\": \"Hello\"}\n\n",
                "data: {\"delta\": \", \"}\ndata: {\"delta\": \"world\"}\n\n",
                "data: [DONE]\n\n"
            ]
        )
        let sut = makeResponder()

        // When
        let deltas = try await collect(sut.stream([LLMMessage(role: .user, content: "hi")]))

        // Then
        #expect(deltas == ["Hello", ", ", "world"])
        #expect(StubURLProtocol.lastRequest?.httpMethod == "POST")
        #expect(StubURLProtocol.lastRequest?.url?.absoluteString == "http://127.0.0.1:8000/api/v1/chat")
        let contentType = StubURLProtocol.lastRequest?.value(forHTTPHeaderField: "Content-Type")
        #expect(contentType == "application/json")
    }

    @Test("stops at the DONE sentinel and ignores trailing data")
    func stopsAtDone() async throws {
        // Given
        StubURLProtocol.stub = .init(
            status: 200,
            chunks: [
                "data: {\"delta\": \"A\"}\n",
                "data: [DONE]\n",
                "data: {\"delta\": \"should-not-appear\"}\n"
            ]
        )
        let sut = makeResponder()

        // When
        let deltas = try await collect(sut.stream([LLMMessage(role: .user, content: "hi")]))

        // Then
        #expect(deltas == ["A"])
    }

    @Test("throws server error on non-2xx status")
    func serverErrorThrows() async {
        // Given
        StubURLProtocol.stub = .init(status: 503, chunks: [])
        let sut = makeResponder()

        // When / Then
        await #expect(throws: LLMError.server(status: 503)) {
            _ = try await collect(sut.stream([LLMMessage(role: .user, content: "hi")]))
        }
    }

    @Test("throws a stream error when the server emits an error event")
    func streamErrorThrows() async {
        // Given
        StubURLProtocol.stub = .init(
            status: 200,
            chunks: ["data: {\"error\": \"upstream failure\"}\n\n"]
        )
        let sut = makeResponder()

        // When / Then
        await #expect(throws: LLMError.stream("upstream failure")) {
            _ = try await collect(sut.stream([LLMMessage(role: .user, content: "hi")]))
        }
    }

    @Test("rejects an empty conversation without hitting the network")
    func emptyConversationThrows() async {
        let sut = makeResponder()
        await #expect(throws: LLMError.emptyConversation) {
            _ = try await collect(sut.stream([]))
        }
    }

    @Test("encodes the conversation as the proxy request shape")
    func encodesRequestBody() async throws {
        // Given
        StubURLProtocol.stub = .init(status: 200, chunks: ["data: [DONE]\n\n"])
        let sut = makeResponder()

        // When
        _ = try await collect(sut.stream([
            LLMMessage(role: .system, content: "be brief"),
            LLMMessage(role: .user, content: "hi")
        ]))

        // Then
        let body = try #require(StubURLProtocol.lastBody)
        let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        let messages = try #require(json?["messages"] as? [[String: String]])
        #expect(messages.count == 2)
        #expect(messages[0]["role"] == "system")
        #expect(messages[0]["content"] == "be brief")
        #expect(messages[1]["role"] == "user")
        #expect(messages[1]["content"] == "hi")
    }
}
