//
//  SpeechEndpointDetector.swift
//  VoiceActivityDetection
//

import Foundation
import VoiceAgentDomain

/// Segments streaming audio into utterances, emitting a speech-start event and a
/// speech-end (endpoint) event once the user stops talking.
///
/// The detector accumulates incoming samples into fixed analysis windows, scores
/// each with an injected ``SpeechProbabilityScoring`` model, and applies threshold
/// hysteresis plus minimum speech/silence durations to debounce the decision.
public actor SpeechEndpointDetector: VoiceActivityDetecting {

    private let scorer: any SpeechProbabilityScoring
    private let configuration: VADConfiguration

    private var pendingSamples: [Float] = []
    private var isSpeaking = false
    private var trailingSilenceMs: Double = 0
    private var sustainedSpeechMs: Double = 0
    private var utterance: [Float] = []
    private var leadingPad: [Float] = []

    public init(scorer: any SpeechProbabilityScoring, configuration: VADConfiguration = VADConfiguration()) {
        self.scorer = scorer
        self.configuration = configuration
    }

    public func reset() async {
        pendingSamples.removeAll()
        isSpeaking = false
        trailingSilenceMs = 0
        sustainedSpeechMs = 0
        utterance.removeAll()
        leadingPad.removeAll()
        await scorer.reset()
    }

    public nonisolated func events(from samples: AsyncStream<[Float]>) -> AsyncStream<VADEvent> {
        AsyncStream { continuation in
            let task = Task {
                for await chunk in samples {
                    if Task.isCancelled { break }
                    await self.ingest(chunk, yielding: continuation)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func ingest(_ chunk: [Float], yielding continuation: AsyncStream<VADEvent>.Continuation) async {
        pendingSamples.append(contentsOf: chunk)
        while pendingSamples.count >= configuration.windowSize {
            let window = Array(pendingSamples.prefix(configuration.windowSize))
            pendingSamples.removeFirst(configuration.windowSize)
            await evaluate(window, yielding: continuation)
        }
    }

    private func evaluate(_ window: [Float], yielding continuation: AsyncStream<VADEvent>.Continuation) async {
        let scoredWindow = normalizedForScoring(window)

        let probability: Float
        do {
            probability = try await scorer.score(scoredWindow)
        } catch {
            IntelligenceLog.vad.error("VAD scoring failed: \(error.localizedDescription, privacy: .public)")
            return
        }

        if isSpeaking {
            continueUtterance(window, probability: probability, yielding: continuation)
        } else {
            detectStart(window, probability: probability, yielding: continuation)
        }
    }

    private func normalizedForScoring(_ window: [Float]) -> [Float] {
        let level = rms(of: window)
        guard level > configuration.scoringNoiseFloorRMS else { return window }
        let gain = min(configuration.maxScoringGain, configuration.scoringTargetRMS / level)
        guard gain > 1 else { return window }
        return window.map { $0 * gain }
    }

    private func rms(of samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        var sumOfSquares: Float = 0
        for sample in samples { sumOfSquares += sample * sample }
        return (sumOfSquares / Float(samples.count)).squareRoot()
    }

    private func detectStart(_ window: [Float], probability: Float, yielding continuation: AsyncStream<VADEvent>.Continuation) {
        retainLeadingPad(window)

        guard probability >= configuration.speechThreshold else {
            sustainedSpeechMs = 0
            return
        }

        sustainedSpeechMs += configuration.windowDurationMs
        guard sustainedSpeechMs >= Double(configuration.minSpeechDurationMs) else { return }

        isSpeaking = true
        trailingSilenceMs = 0
        utterance = leadingPad + window
        leadingPad.removeAll()
        IntelligenceLog.vad.info("Speech started (probability=\(probability, privacy: .public))")
        continuation.yield(.speechStarted)
    }

    private func continueUtterance(_ window: [Float], probability: Float, yielding continuation: AsyncStream<VADEvent>.Continuation) {
        utterance.append(contentsOf: window)

        guard probability < configuration.silenceThreshold else {
            trailingSilenceMs = 0
            return
        }

        trailingSilenceMs += configuration.windowDurationMs
        guard trailingSilenceMs >= Double(configuration.minSilenceDurationMs) else { return }

        let segment = utterance
        isSpeaking = false
        trailingSilenceMs = 0
        sustainedSpeechMs = 0
        utterance.removeAll()
        IntelligenceLog.vad.info("Speech endpoint detected (segmentSamples=\(segment.count, privacy: .public))")
        #if DEBUG
        if AudioProbe.isEnabled {
            let stats = AudioProbe.analyze(segment, sampleRate: configuration.sampleRate)
            IntelligenceLog.vad.info("VAD segment \(stats.description, privacy: .public)")
        }
        #endif
        continuation.yield(.speechEnded(segment: segment))
    }

    private func retainLeadingPad(_ window: [Float]) {
        leadingPad.append(contentsOf: window)
        let maxPadSamples = Int(Double(configuration.speechPadMs) / 1_000 * Double(configuration.sampleRate))
        if leadingPad.count > maxPadSamples {
            leadingPad.removeFirst(leadingPad.count - maxPadSamples)
        }
    }
}
