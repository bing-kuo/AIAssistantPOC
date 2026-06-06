//
//  AudioRecording.swift
//  VoiceAgentDomain
//

import Foundation

/// The lifecycle state of an audio recorder.
public enum AudioRecorderState: Sendable, Equatable {
    case idle
    case recording
    case stopped
    case failed
}

/// A lightweight, thread-safe snapshot of a captured audio buffer.
public struct AudioFrame: Sendable, Equatable {

    /// The captured PCM samples, resampled to 16 kHz mono Float32 for downstream speech processing.
    public let samples: [Float]

    /// The number of PCM frames contained within ``samples``.
    public let frameCount: Int

    /// The Root-Mean-Square (RMS) amplitude representing the current audio loudness.
    public let rms: Float

    /// The precise capture timestamp in seconds, measured on the audio host clock.
    public let timestamp: TimeInterval

    public init(samples: [Float], frameCount: Int, rms: Float, timestamp: TimeInterval) {
        self.samples = samples
        self.frameCount = frameCount
        self.rms = rms
        self.timestamp = timestamp
    }
}

/// Errors that can occur during audio session configuration or pipeline initialization.
public enum AudioRecorderError: Error, Sendable, Equatable {
    case permissionDenied
    case engineStartFailed(String)
    case sessionConfigFailed(String)
}

/// An abstraction boundary defining the contract for microphone audio capture.
public protocol AudioRecording: Sendable {

    /// Requests microphone recording permission from the system.
    /// - Returns: A Boolean value indicating whether permission was granted.
    func requestPermission() async -> Bool

    /// Starts capturing audio buffers from the microphone input.
    /// - Returns: An asynchronous stream that continuously yields captured `AudioFrame` objects.
    /// - Throws: `AudioRecorderError` if permission is denied or the underlying engine fails to start.
    func start() async throws -> AsyncStream<AudioFrame>

    /// Stops the active audio capture session and terminates the stream.
    func stop() async
}
