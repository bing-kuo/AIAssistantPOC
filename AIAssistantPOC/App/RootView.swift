//
//  RootView.swift
//  AIAssistantPOC
//

import SwiftUI

struct RootView: View {
    @State private var voiceViewModel: VoiceSessionViewModel
    @State private var showDrawer = false
    private let fetchSummaries: any FetchSessionSummariesUseCase
    private let deleteSession: any DeleteSessionUseCase
    private let loadSession: any LoadSessionUseCase
    private let warmUpServer: any WarmUpServerConnectionUseCase

    private let transition = Animation.spring(response: 0.35, dampingFraction: 0.86)

    init(
        voiceViewModel: VoiceSessionViewModel,
        fetchSummaries: any FetchSessionSummariesUseCase,
        deleteSession: any DeleteSessionUseCase,
        loadSession: any LoadSessionUseCase,
        warmUpServer: any WarmUpServerConnectionUseCase
    ) {
        _voiceViewModel = State(initialValue: voiceViewModel)
        self.fetchSummaries = fetchSummaries
        self.deleteSession = deleteSession
        self.loadSession = loadSession
        self.warmUpServer = warmUpServer
    }

    var body: some View {
        GeometryReader { proxy in
            let drawerWidth = proxy.size.width

            ZStack(alignment: .leading) {
                NavigationStack {
                    RecorderView(viewModel: voiceViewModel)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button { open() } label: {
                                    Image(systemName: "clock.arrow.circlepath")
                                }
                                .accessibilityLabel("history.button")
                            }
                        }
                }

                SessionDrawerView(
                    fetchSummaries: fetchSummaries,
                    deleteSession: deleteSession,
                    isPresented: showDrawer,
                    onClose: { close() },
                    onNewSession: { Task { await startNewSession() } },
                    onSelect: { id in Task { await selectSession(id) } }
                )
                .frame(width: drawerWidth, height: proxy.size.height)
                .background(.background)
                .offset(x: showDrawer ? 0 : -drawerWidth)
            }
        }
        .task {
            Task { await warmUpServer() }
            await voiceViewModel.beginNewSession()
        }
    }

    private func open() {
        withAnimation(transition) { showDrawer = true }
    }

    private func close() {
        withAnimation(transition) {
            showDrawer = false
        }
    }

    private func startNewSession() async {
        close()
        await voiceViewModel.beginNewSession()
    }

    private func selectSession(_ id: UUID) async {
        close()
        guard let session = await loadSession(id) else { return }
        await voiceViewModel.resume(session)
    }
}
