//
//  PreviewVoiceActivityDetector.swift
//  AIAssistantPOC
//

import VoiceAgentDomain

struct PreviewVoiceActivityDetector: VoiceActivityDetecting {
    func events(from samples: AsyncStream<[Float]>) -> AsyncStream<VADEvent> {
        AsyncStream { $0.finish() }
    }

    func reset() async {}
}
