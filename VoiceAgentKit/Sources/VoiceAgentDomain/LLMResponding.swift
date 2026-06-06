//
//  LLMResponding.swift
//  VoiceAgentDomain
//

import Foundation

/// A single turn in a conversation handed to the language model.
public struct LLMMessage: Sendable, Equatable, Codable {

    /// The author of the message.
    public let role: LLMRole

    /// The textual content of the message.
    public let content: String

    public init(role: LLMRole, content: String) {
        self.role = role
        self.content = content
    }
}

/// The author role of an ``LLMMessage``.
public enum LLMRole: String, Sendable, Codable {
    case system
    case user
    case assistant
}

/// Errors raised while streaming a model response.
public enum LLMError: Error, Sendable, Equatable {
    case emptyConversation
    case invalidResponse
    case server(status: Int)
    case transport(String)
    case decoding(String)
    case stream(String)
}

/// An abstraction boundary for streaming a language-model reply.
///
/// Consumers depend only on this protocol (DIP), so the concrete transport
/// (a self-hosted proxy, a future direct provider, or an on-device model) can
/// be swapped without changing callers. The provider and generation parameters
/// are decided by the backend, keeping model selection off the client.
public protocol LLMResponding: Sendable {

    /// Streams the assistant reply for a conversation as it is generated.
    /// - Parameter messages: The ordered conversation, typically a system prompt
    ///   followed by alternating user and assistant turns ending with the new user turn.
    /// - Returns: An async stream yielding text deltas in order; it finishes when
    ///   the reply is complete and finishes throwing ``LLMError`` on failure.
    func stream(_ messages: [LLMMessage]) -> AsyncThrowingStream<String, Error>
}
