//
//  AudioEngineRecorder.swift
//  AVAudioCapture
//

import AVFoundation
import VoiceAgentDomain
import Foundation

/// An actor-isolated audio recorder backed by `AVAudioEngine` ensuring thread-safe hardware access.
public actor AudioEngineRecorder: AudioRecording {

    private let engine = AVAudioEngine()
    private var continuation: AsyncStream<AudioFrame>.Continuation?
    private var state: AudioRecorderState = .idle
    private let bufferSize: AVAudioFrameCount = 1024
    private let targetSampleRate: Double = 16_000

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

        guard let downsampler = AudioDownsampler(inputFormat: format, targetSampleRate: targetSampleRate) else {
            continuation.finish()
            self.continuation = nil
            state = .failed
            VoiceLog.recorder.error("Failed to create 16 kHz audio converter from input format")
            throw AudioRecorderError.engineStartFailed("Unsupported input format for resampling")
        }

        input.installTap(onBus: 0, bufferSize: bufferSize, format: format) { buffer, when in
            guard let samples = downsampler.downsample(buffer), !samples.isEmpty else { return }
            let rms = AudioMath.rms(samples)
            let timestamp = sampleRate > 0 ? Double(when.sampleTime) / sampleRate : 0
            continuation.yield(AudioFrame(samples: samples, frameCount: samples.count, rms: rms, timestamp: timestamp))
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
                mode: .measurement,
                options: [.allowBluetooth, .defaultToSpeaker]
            )
            try session.setActive(true)
            if session.isInputGainSettable {
                try? session.setInputGain(1.0)
            }
            VoiceLog.session.info("AVAudioSession configured: measurement mode, inputGain=\(session.inputGain, privacy: .public), gainSettable=\(session.isInputGainSettable, privacy: .public)")
        } catch {
            VoiceLog.session.error("AVAudioSession configuration failed: \(error.localizedDescription, privacy: .public)")
            throw AudioRecorderError.sessionConfigFailed(error.localizedDescription)
        }
        #endif
    }
}
