//
//  AIAssistantPOCApp.swift
//  AIAssistantPOC
//
//  Created by Bing on 2026/6/5.
//

import SwiftUI
import VoiceCore

@main
struct AIAssistantPOCApp: App {

    @State private var viewModel = RecorderViewModel(recorder: AudioEngineRecorder())

    var body: some Scene {
        WindowGroup {
            RecorderView(viewModel: viewModel)
        }
    }
}
