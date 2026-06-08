//
//  RootView.swift
//  AIAssistantPOC
//

import SwiftUI

struct RootView: View {
    @State private var voiceViewModel: VoiceSessionViewModel
    @State private var showDrawer = false
    private let reading: any ChatSessionReading
    private let writing: any ChatSessionWriting

    private let transition = Animation.spring(response: 0.35, dampingFraction: 0.86)

    init(
        voiceViewModel: VoiceSessionViewModel,
        reading: any ChatSessionReading,
        writing: any ChatSessionWriting
    ) {
        _voiceViewModel = State(initialValue: voiceViewModel)
        self.reading = reading
        self.writing = writing
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
                    reading: reading,
                    writing: writing,
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
        .task { await voiceViewModel.beginNewSession() }
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
        guard let session = try? await reading.session(id: id) else { return }
        await voiceViewModel.resume(session)
    }
}
