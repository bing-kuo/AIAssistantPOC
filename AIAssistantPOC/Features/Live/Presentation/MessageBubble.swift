//
//  MessageBubble.swift
//  AIAssistantPOC
//

import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage

    private var isUser: Bool { message.role == .user }
    private var tint: Color { isUser ? .blue : .green }
    private var label: LocalizedStringKey { isUser ? "conversation.you" : "conversation.assistant" }

    var body: some View {
        HStack(alignment: .top) {
            if isUser { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(tint)
                Text(message.text)
                    .font(.subheadline)
                    .multilineTextAlignment(.leading)
            }
            .padding(12)
            .background(tint.opacity(0.12), in: .rect(cornerRadius: 12))
            if !isUser { Spacer(minLength: 40) }
        }
    }
}
