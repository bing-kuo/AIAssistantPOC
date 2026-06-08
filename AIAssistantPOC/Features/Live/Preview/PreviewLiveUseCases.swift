//
//  PreviewLiveUseCases.swift
//  AIAssistantPOC
//

import Foundation

struct PreviewProcessVoiceTurn: ProcessVoiceTurnUseCase {
    func callAsFunction(_ audio: [Float]) -> AsyncThrowingStream<VoiceTurnEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                continuation.yield(.userTranscribed("Tell me something"))
                for word in ["This ", "is ", "a ", "preview ", "reply."] {
                    continuation.yield(.replyDelta(word))
                }
                continuation.yield(.replyCompleted("This is a preview reply."))
                continuation.yield(.speaking)
                continuation.finish()
            }
        }
    }
}

struct PreviewStartNewConversation: StartNewConversationUseCase {
    func callAsFunction() async {}
}

struct PreviewResumeConversation: ResumeConversationUseCase {
    func callAsFunction(_ session: ChatSession) async {}
}
