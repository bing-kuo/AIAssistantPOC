//
//  AppCoordinator.swift
//  AIAssistantPOC
//

import Foundation
import Observation

enum RootDestination {
    case live
    case settings
}

@MainActor
@Observable
final class AppCoordinator {

    let voice: VoiceSessionViewModel
    let sessionList: SessionListViewModel

    private let makeSettings: @MainActor () -> SettingsViewModel
    private(set) var settings: SettingsViewModel?

    private let warmUpServer: any WarmUpServerConnectionUseCase

    private(set) var rootDestination: RootDestination = .live
    private(set) var isHistoryPresented = false

    init(
        voice: VoiceSessionViewModel,
        sessionList: SessionListViewModel,
        makeSettings: @escaping @MainActor () -> SettingsViewModel,
        warmUpServer: any WarmUpServerConnectionUseCase
    ) {
        self.voice = voice
        self.sessionList = sessionList
        self.makeSettings = makeSettings
        self.warmUpServer = warmUpServer
    }

    func warmUp() async {
        await warmUpServer()
    }

    func openHistory() {
        isHistoryPresented = true
    }

    func closeHistory() {
        isHistoryPresented = false
    }

    func openSettings() {
        isHistoryPresented = false
        if settings == nil { settings = makeSettings() }
        rootDestination = .settings
    }

    func closeSettings() {
        rootDestination = .live
    }

    func startNewSession() async {
        isHistoryPresented = false
        await voice.beginNewSession()
    }

    func selectSession(_ id: UUID) async {
        isHistoryPresented = false
        guard let session = await sessionList.resolve(id) else { return }
        await voice.resume(session)
    }
}
