//
//  AIAssistantPOCApp.swift
//  AIAssistantPOC
//
//  Created by Bing on 2026/6/5.
//

import SwiftUI

@main
struct AIAssistantPOCApp: App {

    @State private var coordinator = CompositionRoot().makeAppCoordinator()

    var body: some Scene {
        WindowGroup {
            RootView(coordinator: coordinator)
        }
    }
}
