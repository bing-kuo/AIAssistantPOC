//
//  SessionRowView.swift
//  AIAssistantPOC
//

import SwiftUI

struct SessionRowView: View {
    let summary: ChatSessionSummary

    var body: some View {
        Text(summary.title)
            .font(.body)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .contentShape(.rect)
    }
}
