//
//  StartNewConversationInteractor.swift
//  AIAssistantPOC
//

import Foundation

struct StartNewConversationInteractor: StartNewConversationUseCase {

    private let conversation: any ConversationRepository
    private let transcript: any ChatTranscriptRepository

    init(conversation: any ConversationRepository, transcript: any ChatTranscriptRepository) {
        self.conversation = conversation
        self.transcript = transcript
    }

    func callAsFunction() async {
        await conversation.reset()
        await transcript.beginNewSession()
    }
}
