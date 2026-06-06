//
//  LLMConfiguration.swift
//  ProxyLLM
//

import Foundation

/// Connection settings for the self-hosted LLM chat proxy.
///
/// The base URL is injected so the endpoint can be repointed (e.g. from a Mac's
/// LAN address to a remote server) without code changes. The OpenAI (or other
/// provider) credentials live on the proxy, never in this configuration.
public struct LLMConfiguration: Sendable {

    /// Scheme + host + port of the chat proxy, e.g. `http://192.168.0.35:8000`.
    public let baseURL: URL

    /// Path of the streaming chat endpoint.
    public let path: String

    /// Request timeout in seconds.
    public let timeout: TimeInterval

    /// Optional bearer token guarding the proxy. This is a low-value, rotatable
    /// internal token, not a provider API key.
    public let accessToken: String?

    public init(
        baseURL: URL,
        path: String = "/api/v1/chat",
        timeout: TimeInterval = 60,
        accessToken: String? = nil
    ) {
        self.baseURL = baseURL
        self.path = path
        self.timeout = timeout
        self.accessToken = accessToken
    }

    /// The fully resolved endpoint URL.
    public var endpoint: URL {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.path = path
        return components?.url ?? baseURL
    }
}
