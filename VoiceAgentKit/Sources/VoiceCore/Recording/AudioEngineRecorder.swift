//
//  AudioEngineRecorder.swift
//  VoiceCore
//

import AVFoundation
import Foundation

/// An actor-isolated audio recorder backed by `AVAudioEngine` ensuring thread-safe hardware access.
public actor AudioEngineRecorder: AudioRecording {

    private let engine = AVAudioEngine()
    private var continuation: AsyncStream<AudioFrame>.Continuation?
    private var state: AudioRecorderState = .idle
    private let bufferSize: AVAudioFrameCount = 1024

    public init() {}

    /// The current lifecycle state of the recorder.
    public var currentState: AudioRecorderState { state }

    /// Requests recording permissions from the operating system.
    /// - Returns: A Boolean value indicating whether permission was granted.
    public func requestPermission() async -> Bool {
        #if os(macOS)
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        #else
        let granted = await AVAudioApplication.requestRecordPermission()
        #endif
        VoiceLog.session.info("Microphone permission request result: \(granted, privacy: .public)")
        return granted
    }

    /// Starts capturing audio buffers from the microphone input.
    /// - Returns: An asynchronous stream yielding encapsulated audio frames.
    /// - Throws: `AudioRecorderError.engineStartFailed` if configuration or initialization fails.
    public func start() async throws -> AsyncStream<AudioFrame> {
        guard state != .recording else {
            VoiceLog.recorder.notice("Start command ignored: already recording")
            throw AudioRecorderError.engineStartFailed("Already recording")
        }

        try configureSession()

        let (stream, continuation) = AsyncStream<AudioFrame>.makeStream()
        self.continuation = continuation
        
        continuation.onTermination = { [weak self] _ in
            Task { await self?.stop() }
        }
        
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        let sampleRate = format.sampleRate
        
        let recorderLog = VoiceLog.recorder
        input.installTap(onBus: 0, bufferSize: bufferSize, format: format) { buffer, when in
            guard let channelData = buffer.floatChannelData else { return }
            let frameCount = Int(buffer.frameLength)
            let samples = UnsafeBufferPointer(start: channelData[0], count: frameCount)
            let rms = AudioMath.rms(samples)
            let timestamp = sampleRate > 0 ? Double(when.sampleTime) / sampleRate : 0
            
            recorderLog.info("Captured audio frame: frames=\(frameCount, privacy: .public), rms=\(rms, privacy: .public)")
            continuation.yield(AudioFrame(frameCount: frameCount, rms: rms, timestamp: timestamp))
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            continuation.finish()
            self.continuation = nil
            state = .failed
            VoiceLog.recorder.error("Failed to start AVAudioEngine: \(error.localizedDescription, privacy: .public)")
            throw AudioRecorderError.engineStartFailed(error.localizedDescription)
        }
        
        state = .recording
        VoiceLog.recorder.info("AVAudioEngine started successfully at sampleRate=\(sampleRate, privacy: .public)")
        return stream
    }

    /// Stops the audio engine and deactivates the audio session.
    public func stop() async {
        guard state == .recording else { return }
        
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        continuation?.finish()
        continuation = nil
        state = .stopped
        
        #if os(iOS) || os(visionOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
        
        VoiceLog.recorder.info("Audio recording pipeline stopped")
    }

    // MARK: - Private

    private func configureSession() throws {
        #if os(iOS) || os(visionOS)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.allowBluetooth, .defaultToSpeaker]
            )
            try session.setActive(true)
            VoiceLog.session.info("AVAudioSession configured for playAndRecord with voiceChat mode")
        } catch {
            VoiceLog.session.error("AVAudioSession configuration failed: \(error.localizedDescription, privacy: .public)")
            throw AudioRecorderError.sessionConfigFailed(error.localizedDescription)
        }
        #endif
    }
}
