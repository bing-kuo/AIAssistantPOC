//
//  WarmUpServerConnectionInteractor.swift
//  AIAssistantPOC
//

import Foundation

struct WarmUpServerConnectionInteractor: WarmUpServerConnectionUseCase {

    private let probe: @Sendable () async -> Void

    init(probe: @escaping @Sendable () async -> Void) {
        self.probe = probe
    }

    func callAsFunction() async {
        await probe()
    }
}
