//
//  WarmUpServerConnectionUseCase.swift
//  AIAssistantPOC
//

import Foundation

/// Primes the iOS Local Network permission by touching the server once at launch,
/// so the first real turn is not the request that triggers (and is blocked by) the prompt.
protocol WarmUpServerConnectionUseCase: Sendable {
    func callAsFunction() async
}
