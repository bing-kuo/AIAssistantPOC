//
//  IntelligenceLog.swift
//  VoiceActivityDetection
//

import OSLog

/// Unified logging factory for the VoiceIntelligence module.
public enum IntelligenceLog {

    /// The shared reverse-DNS subsystem identifier for VoiceIntelligence.
    public static let subsystem = "com.bing.AIAssistantPOC.VoiceIntelligence"

    /// Logger instance for voice activity detection and speech endpointing.
    public static let vad = Logger(subsystem: subsystem, category: "VAD")
}
