//
//  PipelineBenchmarks.swift
//  AIAssistantPOCTests
//
//  Opt-in latency benchmarks against a live server. Skipped unless VOICE_BENCH is set.
//
//  Run:
//    VOICE_BENCH=1 VOICE_BENCH_URL=http://<server>:8000 VOICE_BENCH_N=30 \
//      xcodebuild test -scheme AIAssistantPOC \
//        -destination 'platform=iOS Simulator,name=iPhone 17' \
//        -only-testing:AIAssistantPOCTests/PipelineBenchmarks
//
//  Results (p50/p90/p95) are printed to the test log. For representative STT numbers,
//  point `sampleUtterance` at a real recorded utterance instead of the synthetic tone.
//

import Foundation
import Testing
import VoiceAgentDomain
import WhisperSTT
import ProxyLLM
@testable import AIAssistantPOC

private enum Bench {
    static var isEnabled: Bool { ProcessInfo.processInfo.environment["VOICE_BENCH"] != nil }
    static var baseURL: URL {
        URL(string: ProcessInfo.processInfo.environment["VOICE_BENCH_URL"] ?? "http://192.168.0.35:8000")!
    }
    static var iterations: Int {
        Int(ProcessInfo.processInfo.environment["VOICE_BENCH_N"] ?? "") ?? 20
    }
}

private func seconds(_ duration: Duration) -> Double {
    let c = duration.components
    return Double(c.seconds) + Double(c.attoseconds) / 1e18
}

private func percentile(_ values: [Double], _ p: Double) -> Double {
    guard !values.isEmpty else { return 0 }
    let sorted = values.sorted()
    let rank = p / 100 * Double(sorted.count - 1)
    let lo = Int(rank.rounded(.down))
    let hi = Int(rank.rounded(.up))
    guard lo != hi else { return sorted[lo] }
    let weight = rank - Double(lo)
    return sorted[lo] * (1 - weight) + sorted[hi] * weight
}

private func report(_ label: String, _ samplesSec: [Double], audioSeconds: Double? = nil) {
    guard !samplesSec.isEmpty else {
        print("[bench] \(label): no samples"); return
    }
    func ms(_ p: Double) -> String { String(format: "%.0f", percentile(samplesSec, p) * 1000) }
    var line = "[bench] \(label) (n=\(samplesSec.count)): p50=\(ms(50))ms p90=\(ms(90))ms p95=\(ms(95))ms"
    if let audioSeconds {
        line += String(format: " RTF(p50)=%.2f", percentile(samplesSec, 50) / audioSeconds)
    }
    print(line)
}

private func sampleUtterance(seconds: Double, sampleRate: Int) -> [Float] {
    let count = Int(seconds * Double(sampleRate))
    let frequency = 220.0
    return (0..<count).map { index in
        Float(0.1 * sin(2 * Double.pi * frequency * Double(index) / Double(sampleRate)))
    }
}

@Suite("PipelineBenchmarks")
struct PipelineBenchmarks {

    @Test("STT round-trip latency", .enabled(if: Bench.isEnabled))
    func sttRoundTrip() async throws {
        let recognizer = WhisperSpeechRecognizer(configuration: WhisperConfiguration(baseURL: Bench.baseURL))
        let sampleRate = 16_000
        let audioSeconds = 3.0
        let audio = sampleUtterance(seconds: audioSeconds, sampleRate: sampleRate)
        let clock = ContinuousClock()

        _ = try? await recognizer.transcribe(audio, sampleRate: sampleRate)   // warmup

        var samples: [Double] = []
        for _ in 0..<Bench.iterations {
            let start = clock.now
            _ = try await recognizer.transcribe(audio, sampleRate: sampleRate)
            samples.append(seconds(start.duration(to: clock.now)))
        }
        report("STT round-trip", samples, audioSeconds: audioSeconds)
    }

    @Test("LLM time-to-first-token and full-response latency", .enabled(if: Bench.isEnabled))
    func llmStreaming() async throws {
        let responder = ProxyLLMResponder(configuration: LLMConfiguration(baseURL: Bench.baseURL))
        let messages = [
            LLMMessage(role: .system, content: "You are a concise voice assistant."),
            LLMMessage(role: .user, content: "Say hello in one short sentence."),
        ]
        let clock = ContinuousClock()

        for try await _ in responder.stream(messages) {}   // warmup

        var ttft: [Double] = []
        var full: [Double] = []
        for _ in 0..<Bench.iterations {
            let start = clock.now
            var firstTokenAt: ContinuousClock.Instant?
            for try await delta in responder.stream(messages) where !delta.isEmpty {
                if firstTokenAt == nil { firstTokenAt = clock.now }
            }
            let end = clock.now
            if let firstTokenAt { ttft.append(seconds(start.duration(to: firstTokenAt))) }
            full.append(seconds(start.duration(to: end)))
        }
        report("LLM TTFT", ttft)
        report("LLM full", full)
    }
}
