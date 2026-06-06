//
//  STTLog.swift
//  WhisperSTT
//

import OSLog

/// Unified logging factory for the STTCore module.
public enum STTLog {

    /// The shared reverse-DNS subsystem identifier for STTCore.
    public static let subsystem = "com.bing.AIAssistantPOC.STTCore"

    /// Logger instance for speech-to-text requests.
    public static let recognizer = Logger(subsystem: subsystem, category: "Recognizer")
}
