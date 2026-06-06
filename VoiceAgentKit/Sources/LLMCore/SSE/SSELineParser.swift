//
//  SSELineParser.swift
//  LLMCore
//

import Foundation

/// A decoded Server-Sent Events line from the chat proxy.
public enum SSEEvent: Sendable, Equatable {

    /// A chunk of generated text to append to the reply.
    case delta(String)

    /// The terminal marker indicating the reply is complete.
    case done

    /// A server-reported error message.
    case failure(String)
}

/// Pure, line-oriented parser for the proxy's `text/event-stream` body.
///
/// Each event is a `data:` line carrying either a JSON `{ "delta" | "error" }`
/// payload or the literal `[DONE]` sentinel. Blank lines and `:` keep-alive
/// comments are ignored. Kept free of networking so it is unit-testable.
public enum SSELineParser {

    /// Parses a single line of the event stream.
    /// - Parameter line: One line from the response body, without its trailing newline.
    /// - Returns: The decoded ``SSEEvent``, or `nil` for lines that carry no event.
    public static func parse(line: String) -> SSEEvent? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !trimmed.hasPrefix(":") else { return nil }
        guard trimmed.hasPrefix("data:") else { return nil }

        let payload = trimmed.dropFirst("data:".count).trimmingCharacters(in: .whitespaces)
        guard !payload.isEmpty else { return nil }

        if payload == "[DONE]" { return .done }

        guard let data = payload.data(using: .utf8),
              let chunk = try? JSONDecoder().decode(ChatChunkDTO.self, from: data) else {
            return .failure("malformed event payload")
        }
        return chunk.toEvent()
    }
}
