//
//  ProcessVoiceTurnInteractor.swift
//  AIAssistantPOC
//

import Foundation
import VoiceAgentDomain

struct ProcessVoiceTurnInteractor: ProcessVoiceTurnUseCase {

    private let transcribe: any TranscribeUtteranceUseCase
    private let generateReply: any GenerateReplyUseCase
    private let synthesizer: any SpeechSynthesizing
    private let transcript: any ChatTranscriptRepository

    init(
        transcribe: any TranscribeUtteranceUseCase,
        generateReply: any GenerateReplyUseCase,
        synthesizer: any SpeechSynthesizing,
        transcript: any ChatTranscriptRepository
    ) {
        self.transcribe = transcribe
        self.generateReply = generateReply
        self.synthesizer = synthesizer
        self.transcript = transcript
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
        let userText = try await transcribe(audio)
        try Task.checkCancellation()
        guard !userText.isEmpty else { return }

        continuation.yield(.userTranscribed(userText))
        await transcript.recordUserMessage(userText)

        var reply = ""
        for try await delta in generateReply(userText) {
            try Task.checkCancellation()
            reply += delta
            continuation.yield(.replyDelta(delta))
        }
        try Task.checkCancellation()

        continuation.yield(.replyCompleted(reply))
        if !reply.isEmpty {
            await transcript.recordAssistantMessage(reply)
        }

        guard !reply.isEmpty else { return }
        continuation.yield(.speaking)
        try await synthesizer.speak(reply)
    }
}
