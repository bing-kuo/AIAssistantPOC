//
//  SessionDrawerView.swift
//  AIAssistantPOC
//

import SwiftUI

struct SessionDrawerView: View {
    private let isPresented: Bool
    private let onClose: () -> Void
    private let onNewSession: () -> Void
    private let onSelect: (UUID) -> Void
    private let onOpenSettings: () -> Void

    @State private var viewModel: SessionListViewModel

    init(
        viewModel: SessionListViewModel,
        isPresented: Bool,
        onClose: @escaping () -> Void,
        onNewSession: @escaping () -> Void,
        onSelect: @escaping (UUID) -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        self.isPresented = isPresented
        self.onClose = onClose
        self.onNewSession = onNewSession
        self.onSelect = onSelect
        self.onOpenSettings = onOpenSettings
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                content
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onOpenSettings) {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("settings.open")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("drawer.close")
                }
            }
        }
        .task { await viewModel.load() }
        .onChange(of: isPresented) { _, presented in
            if presented {
                Task { await viewModel.load() }
            }
        }
    }

    private var content: some View {
        List {
            Section {
                Button { onNewSession() } label: {
                    Label("sessions.new", systemImage: "square.and.pencil")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(.rect)
                }
                .foregroundStyle(.primary)
                .customListRowStyle()
            }
            
            if !viewModel.summaries.isEmpty {
                Section {
                    ForEach(viewModel.summaries) { summary in
                        Button { onSelect(summary.id) } label: {
                            SessionRowView(summary: summary)
                        }
                        .customListRowStyle()
                        .contextMenu {
                            Button(role: .destructive) {
                                Task { await viewModel.delete(id: summary.id) }
                            } label: {
                                Label("sessions.delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text("sessions.recents")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.plain)
    }
}

struct CustomListRowStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .buttonStyle(.plain)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 2, leading: 20, bottom: 2, trailing: 12))
    }
}

extension View {
    func customListRowStyle() -> some View {
        self.modifier(CustomListRowStyle())
    }
}

#Preview {
    let store = PreviewChatStore()
    return SessionDrawerView(
        viewModel: SessionListViewModel(
            fetchSummaries: FetchSessionSummariesInteractor(repository: store),
            deleteSession: DeleteSessionInteractor(repository: store),
            loadSession: LoadSessionInteractor(repository: store)
        ),
        isPresented: true,
        onClose: {},
        onNewSession: {},
        onSelect: { _ in },
        onOpenSettings: {}
    )
}
