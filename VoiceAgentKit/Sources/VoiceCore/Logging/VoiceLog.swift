//
//  VoiceLog.swift
//  VoiceCore
//

import Foundation
import OSLog

/// Unified logging factory for the VoiceCore module.
public enum VoiceLog {

    /// The shared reverse-DNS subsystem identifier for VoiceCore.
    public static let subsystem = "com.bing.AIAssistantPOC.VoiceCore"

    /// Logger instance for the audio capture pipeline and engine lifecycle.
    public static let recorder = Logger(subsystem: subsystem, category: "Recorder")

    /// Logger instance for `AVAudioSession` configurations and permissions.
    public static let session = Logger(subsystem: subsystem, category: "AudioSession")
}
