//
//  LLMLog.swift
//  ProxyLLM
//

import OSLog

/// Unified logging factory for the LLMCore module.
public enum LLMLog {

    /// The shared reverse-DNS subsystem identifier for LLMCore.
    public static let subsystem = "com.bing.AIAssistantPOC.LLMCore"

    /// Logger instance for chat streaming requests.
    public static let responder = Logger(subsystem: subsystem, category: "Responder")
}
