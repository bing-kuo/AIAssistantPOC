//
//  RecorderViewModel.swift
//  AIAssistantPOC
//

import Observation
import VoiceCore

enum RecorderStatus: Equatable, Sendable {
    case idle
    case recording
    case stopped
    case permissionDenied
    case failed
}

@MainActor
@Observable
final class RecorderViewModel {

    private let recorder: any AudioRecording
    private var consumeTask: Task<Void, Never>?

    private(set) var isRecording = false
    private(set) var lastRMS: Float = 0
    private(set) var status: RecorderStatus = .idle

    init(recorder: any AudioRecording) {
        self.recorder = recorder
    }

    func toggle() async {
        if isRecording {
            await stop()
        } else {
            await start()
        }
    }

    private func start() async {
        guard await recorder.requestPermission() else {
            status = .permissionDenied
            return
        }

        do {
            let stream = try await recorder.start()
            isRecording = true
            status = .recording
            consumeTask = Task { [weak self] in
                for await frame in stream {
                    guard let self else { break }
                    self.lastRMS = frame.rms
                }

                if let self {
                    self.isRecording = false
                    self.status = .stopped
                }
            }
        } catch {
            isRecording = false
            status = .failed
        }
    }

    private func stop() async {
        await recorder.stop()
        consumeTask?.cancel()
        consumeTask = nil
        isRecording = false
        lastRMS = 0
        status = .stopped
    }
}
