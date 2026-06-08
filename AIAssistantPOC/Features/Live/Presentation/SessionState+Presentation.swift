//
//  SessionState+Presentation.swift
//  AIAssistantPOC
//

import SwiftUI

extension SessionState {
    var localizationKey: LocalizedStringKey {
        switch self {
        case .idle: "status.idle"
        case .listening: "status.listening"
        case .speaking: "status.speaking"
        case .processing: "status.processing"
        case .responding: "status.responding"
        case .playing: "status.playing"
        case .failed: "status.failed"
        }
    }

    var tint: Color {
        switch self {
        case .idle: .accentColor
        case .listening: .blue
        case .speaking: .red
        case .processing: .orange
        case .responding: .green
        case .playing: .purple
        case .failed: .yellow
        }
    }

    var waveformMode: MicroWaveformView.Mode {
        switch self {
        case .idle, .failed: .idle
        case .listening, .speaking: .reactive
        case .processing, .responding, .playing: .synthetic
        }
    }
}
