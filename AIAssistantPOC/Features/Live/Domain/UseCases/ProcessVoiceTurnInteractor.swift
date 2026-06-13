//
//  ProcessVoiceTurnInteractor.swift
//  AIAssistantPOC
//

import Foundation
import VoiceAgentDomain
import os

private let perfSignposter = OSSignposter(subsystem: "AIAssistantPOC", category: "Performance")

struct ProcessVoiceTurnInteractor: ProcessVoiceTurnUseCase {

    private let transcribe: any TranscribeUtteranceUseCase
    private let generateReply: any GenerateReplyUseCase
    private let synthesizer: any SpeechSynthesizing
    private let transcript: any ChatTranscriptRepository
    private let voiceResponsesEnabled: @Sendable () async -> Bool

    init(
        transcribe: any TranscribeUtteranceUseCase,
        generateReply: any GenerateReplyUseCase,
        synthesizer: any SpeechSynthesizing,
        transcript: any ChatTranscriptRepository,
        voiceResponsesEnabled: @escaping @Sendable () async -> Bool
    ) {
        self.transcribe = transcribe
        self.generateReply = generateReply
        self.synthesizer = synthesizer
        self.transcript = transcript
        self.voiceResponsesEnabled = voiceResponsesEnabled
    }

    func callAsFunction(_ audio: [Float]) -> AsyncThrowingStream<VoiceTurnEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await run(audio, into: continuation)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { [synthesizer] _ in
                task.cancel()
                Task { await synthesizer.stop() }
            }
        }
    }

    private func run(
        _ audio: [Float],
        into continuation: AsyncThrowingStream<VoiceTurnEvent, Error>.Continuation
    ) async throws {
        let signpostID = perfSignposter.makeSignpostID()
        let interval = perfSignposter.beginInterval("VoiceTurn", id: signpostID, "samples=\(audio.count)")
        defer { perfSignposter.endInterval("VoiceTurn", interval) }

        let userText = try await transcribe(audio)
        perfSignposter.emitEvent("STT.done", id: signpostID, "chars=\(userText.count)")
        try Task.checkCancellation()
        guard !userText.isEmpty else { return }

        continuation.yield(.userTranscribed(userText))
        await transcript.recordUserMessage(userText)

        var reply = ""
        var firstTokenSeen = false
        for try await delta in generateReply(userText) {
            try Task.checkCancellation()
            if !firstTokenSeen {
                firstTokenSeen = true
                perfSignposter.emitEvent("LLM.firstToken", id: signpostID)
            }
            reply += delta
            continuation.yield(.replyDelta(delta))
        }
        try Task.checkCancellation()
        perfSignposter.emitEvent("LLM.complete", id: signpostID, "chars=\(reply.count)")

        continuation.yield(.replyCompleted(reply))
        if !reply.isEmpty {
            await transcript.recordAssistantMessage(reply)
        }

        guard !reply.isEmpty else { return }
        guard await voiceResponsesEnabled() else { return }
        continuation.yield(.speaking)
        perfSignposter.emitEvent("TTS.begin", id: signpostID)
        try await synthesizer.speak(reply)
    }
}
