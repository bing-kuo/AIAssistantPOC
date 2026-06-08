//
//  SessionListViewModel.swift
//  AIAssistantPOC
//

import Foundation
import Observation

@MainActor
@Observable
final class SessionListViewModel {

    private let reading: any ChatSessionReading
    private let writing: any ChatSessionWriting

    private(set) var summaries: [ChatSessionSummary] = []

    init(reading: any ChatSessionReading, writing: any ChatSessionWriting) {
        self.reading = reading
        self.writing = writing
    }

    func load() async {
        summaries = (try? await reading.summaries()) ?? []
    }

    func delete(id: UUID) async {
        try? await writing.deleteSession(id: id)
        await load()
    }
}
