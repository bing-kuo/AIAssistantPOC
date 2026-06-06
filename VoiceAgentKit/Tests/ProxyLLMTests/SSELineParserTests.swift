//
//  SSELineParserTests.swift
//  ProxyLLMTests
//

import Foundation
import Testing
@testable import ProxyLLM

@Suite("SSELineParser")
struct SSELineParserTests {

    @Test("decodes a delta payload")
    func decodesDelta() {
        // Given a data line carrying a delta
        let line = #"data: {"delta": "hello"}"#
        // When
        let event = SSELineParser.parse(line: line)
        // Then
        #expect(event == .delta("hello"))
    }

    @Test("decodes the terminal DONE sentinel")
    func decodesDone() {
        #expect(SSELineParser.parse(line: "data: [DONE]") == .done)
    }

    @Test("decodes a server error payload")
    func decodesError() {
        // Given
        let line = #"data: {"error": "rate limited"}"#
        // When / Then
        #expect(SSELineParser.parse(line: line) == .failure("rate limited"))
    }

    @Test("ignores blank lines and keep-alive comments")
    func ignoresNonEvents() {
        #expect(SSELineParser.parse(line: "") == nil)
        #expect(SSELineParser.parse(line: "   ") == nil)
        #expect(SSELineParser.parse(line: ": keep-alive") == nil)
        #expect(SSELineParser.parse(line: "event: message") == nil)
    }

    @Test("reports malformed JSON payloads as a failure")
    func malformedPayload() {
        #expect(SSELineParser.parse(line: "data: not-json") == .failure("malformed event payload"))
    }
}
