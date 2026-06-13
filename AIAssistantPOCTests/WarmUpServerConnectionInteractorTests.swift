//
//  WarmUpServerConnectionInteractorTests.swift
//  AIAssistantPOCTests
//

import Foundation
import Testing
@testable import AIAssistantPOC

private actor ProbeSpy {
    private(set) var count = 0
    func record() { count += 1 }
}

@MainActor
@Suite("WarmUpServerConnectionInteractor")
struct WarmUpServerConnectionInteractorTests {

    @Test("invokes the injected probe once")
    func invokesProbe() async {
        // Given a warm-up use case over a spy probe
        let spy = ProbeSpy()
        let sut = WarmUpServerConnectionInteractor { await spy.record() }

        // When invoked
        await sut()

        // Then the probe ran exactly once
        #expect(await spy.count == 1)
    }
}
