//
//  RootView.swift
//  AIAssistantPOC
//

import SwiftUI

struct RootView: View {
    let coordinator: AppCoordinator

    private let transition = Animation.spring(response: 0.35, dampingFraction: 0.86)

    var body: some View {
        GeometryReader { proxy in
            let drawerWidth = proxy.size.width

            ZStack(alignment: .leading) {
                NavigationStack {
                    rootContent
                }

                SessionDrawerView(
                    viewModel: coordinator.sessionList,
                    isPresented: coordinator.isHistoryPresented,
                    onClose: { coordinator.closeHistory() },
                    onNewSession: { Task { await coordinator.startNewSession() } },
                    onSelect: { id in Task { await coordinator.selectSession(id) } },
                    onOpenSettings: { coordinator.openSettings() }
                )
                .frame(width: drawerWidth, height: proxy.size.height)
                .background(.background)
                .offset(x: coordinator.isHistoryPresented ? 0 : -drawerWidth)
            }
            .animation(transition, value: coordinator.isHistoryPresented)
        }
        .task {
            Task { await coordinator.warmUp() }
            await coordinator.voice.beginNewSession()
        }
    }

    @ViewBuilder private var rootContent: some View {
        switch coordinator.rootDestination {
        case .live:
            RecorderView(viewModel: coordinator.voice)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { coordinator.openHistory() } label: {
                            Image(systemName: "clock.arrow.circlepath")
                        }
                        .accessibilityLabel("history.button")
                    }
                }
        case .settings:
            if let settings = coordinator.settings {
                SettingsView(viewModel: settings)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button { coordinator.closeSettings() } label: {
                                Image(systemName: "chevron.left")
                            }
                            .accessibilityLabel("settings.back")
                        }
                    }
            }
        }
    }
}
