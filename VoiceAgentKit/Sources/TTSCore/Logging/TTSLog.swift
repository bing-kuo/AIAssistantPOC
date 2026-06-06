//
//  TTSLog.swift
//  TTSCore
//

import OSLog

/// Unified logging factory for the TTSCore module.
public enum TTSLog {

    /// The shared reverse-DNS subsystem identifier for TTSCore.
    public static let subsystem = "com.bing.AIAssistantPOC.TTSCore"

    /// Logger instance for speech synthesis and playback.
    public static let synthesizer = Logger(subsystem: subsystem, category: "Synthesizer")
}
