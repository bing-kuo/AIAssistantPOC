//
//  ResumeConversationInteractor.swift
//  AIAssistantPOC
//

import Foundation
import VoiceAgentDomain

struct ResumeConversationInteractor: ResumeConversationUseCase {

    private let conversation: any ConversationRepository
    private let transcript: any ChatTranscriptRecording

    init(conversation: any ConversationRepository, transcript: any ChatTranscriptRecording) {
        self.conversation = conversation
        self.transcript = transcript
    }

    func callAsFunction(_ session: ChatSession) async {
        let history = session.messages.map {
            LLMMessage(role: $0.role.llmRole, content: $0.text)
        }
        await conversation.restore(history)
        await transcript.resume(sessionID: session.id)
    }
}

private extension ChatRole {
    var llmRole: LLMRole {
        switch self {
        case .user: .user
        case .assistant: .assistant
        }
    }
}
