//
//  VoiceActivityDetecting.swift
//  VoiceAgentDomain
//

import Foundation

/// A discrete event emitted by a voice activity detector as speech is segmented.
public enum VADEvent: Sendable, Equatable {

    /// The user has begun speaking.
    case speechStarted

    /// The user has stopped speaking; the captured utterance samples are attached.
    case speechEnded(segment: [Float])
}

/// Tunable thresholds governing speech detection and endpointing behaviour.
public struct VADConfiguration: Sendable {

    /// The sample rate, in Hz, of the audio fed to the detector.
    public var sampleRate: Int

    /// The fixed analysis window size, in samples, expected by the scoring model.
    public var windowSize: Int

    /// The probability at or above which a window is considered speech.
    public var speechThreshold: Float

    /// The probability below which a window is considered silence (hysteresis lower bound).
    public var silenceThreshold: Float

    /// Trailing silence, in milliseconds, required to declare the end of an utterance.
    public var minSilenceDurationMs: Int

    /// Minimum sustained speech, in milliseconds, required to confirm a speech start.
    public var minSpeechDurationMs: Int

    /// Pre-roll audio, in milliseconds, retained ahead of the speech onset. The
    /// detector additionally retains the ``minSpeechDurationMs`` confirmation
    /// window, so the captured utterance is not clipped at its start.
    public var speechPadMs: Int

    /// Target RMS that each window is normalized to before scoring. Compensates
    /// for clean-but-quiet capture (e.g. `.measurement` mode without AGC) by
    /// adaptively amplifying speech into Silero's effective range. Normalization
    /// affects scoring only; emitted utterance samples remain unamplified.
    public var scoringTargetRMS: Float

    /// Windows quieter than this RMS are treated as background and not amplified,
    /// preventing silence/noise from being boosted into false detections.
    public var scoringNoiseFloorRMS: Float

    /// Upper bound on the adaptive normalization gain.
    public var maxScoringGain: Float

    public init(
        sampleRate: Int = 16_000,
        windowSize: Int = 512,
        speechThreshold: Float = 0.5,
        silenceThreshold: Float = 0.35,
        minSilenceDurationMs: Int = 700,
        minSpeechDurationMs: Int = 250,
        speechPadMs: Int = 200,
        scoringTargetRMS: Float = 0.12,
        scoringNoiseFloorRMS: Float = 0.0015,
        maxScoringGain: Float = 40
    ) {
        self.sampleRate = sampleRate
        self.windowSize = windowSize
        self.speechThreshold = speechThreshold
        self.silenceThreshold = silenceThreshold
        self.minSilenceDurationMs = minSilenceDurationMs
        self.minSpeechDurationMs = minSpeechDurationMs
        self.speechPadMs = speechPadMs
        self.scoringTargetRMS = scoringTargetRMS
        self.scoringNoiseFloorRMS = scoringNoiseFloorRMS
        self.maxScoringGain = maxScoringGain
    }

    /// The duration, in milliseconds, represented by a single analysis window.
    public var windowDurationMs: Double {
        guard sampleRate > 0 else { return 0 }
        return Double(windowSize) / Double(sampleRate) * 1_000
    }
}

/// Scores a fixed-size audio window with the probability that it contains speech.
public protocol SpeechProbabilityScoring: Sendable {

    /// Returns the speech probability in `0...1` for a single analysis window.
    /// - Parameter window: Exactly `VADConfiguration.windowSize` Float32 samples at the configured sample rate.
    func score(_ window: [Float]) async throws -> Float

    /// Resets any recurrent internal state between independent utterances.
    func reset() async
}

/// Segments a stream of audio samples into speech utterances and endpoint events.
public protocol VoiceActivityDetecting: Sendable {

    /// Consumes a stream of audio sample chunks and emits ``VADEvent`` values as speech is detected.
    /// - Parameter samples: 16 kHz mono Float32 sample chunks of arbitrary length.
    func events(from samples: AsyncStream<[Float]>) -> AsyncStream<VADEvent>

    /// Resets the detector and its scorer to the initial idle state.
    func reset() async
}
