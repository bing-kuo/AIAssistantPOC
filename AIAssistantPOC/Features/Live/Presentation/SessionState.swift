//
//  SessionState.swift
//  AIAssistantPOC
//

enum SessionState: Equatable, Sendable {
    case idle
    case listening
    case speaking
    case processing
    case responding
    case playing
    case failed
}
