//
//  SileroVAD.swift
//  SileroVAD
//

import Foundation
import VoiceAgentDomain
import OnnxRuntimeBindings

/// Errors raised while loading or running the Silero VAD model.
public enum SileroVADError: Error, Sendable, Equatable {
    case modelNotFound
    case sessionCreationFailed(String)
    case invalidWindowSize(expected: Int, actual: Int)
    case inferenceFailed(String)
}

/// A Silero VAD (v5) speech probability scorer backed by ONNX Runtime.
///
/// The ONNX session and its recurrent `state` tensor are confined to this actor,
/// giving thread-safe, serialized inference across the streaming pipeline.
public actor SileroVAD: SpeechProbabilityScoring {

    private let env: ORTEnv
    private let session: ORTSession
    private let windowSize: Int
    private let contextSize: Int
    private let sampleRate: Int64
    private var state: [Float]
    private var context: [Float]

    private static let stateCount = 2 * 1 * 128

    /// Loads the bundled `silero_vad.onnx` model and prepares an inference session.
    /// - Throws: ``SileroVADError`` if the model is missing or the session cannot be created.
    public init(windowSize: Int = 512, sampleRate: Int64 = 16_000) throws {
        guard let modelURL = Bundle.module.url(forResource: "silero_vad", withExtension: "onnx") else {
            throw SileroVADError.modelNotFound
        }

        do {
            let env = try ORTEnv(loggingLevel: .warning)
            let options = try ORTSessionOptions()
            self.session = try ORTSession(env: env, modelPath: modelURL.path, sessionOptions: options)
            self.env = env
        } catch {
            throw SileroVADError.sessionCreationFailed(error.localizedDescription)
        }

        self.windowSize = windowSize
        self.contextSize = sampleRate == 8_000 ? 32 : 64
        self.sampleRate = sampleRate
        self.state = [Float](repeating: 0, count: Self.stateCount)
        self.context = [Float](repeating: 0, count: sampleRate == 8_000 ? 32 : 64)
    }

    public func reset() async {
        state = [Float](repeating: 0, count: Self.stateCount)
        context = [Float](repeating: 0, count: contextSize)
    }

    public func score(_ window: [Float]) async throws -> Float {
        guard window.count == windowSize else {
            throw SileroVADError.invalidWindowSize(expected: windowSize, actual: window.count)
        }

        do {
            var modelInput = context
            modelInput.append(contentsOf: window)
            let inputTensor = try Self.floatTensor(modelInput, shape: [1, NSNumber(value: modelInput.count)])
            let stateTensor = try Self.floatTensor(state, shape: [2, 1, 128])

            var sampleRateValue = sampleRate
            let sampleRateData = NSMutableData(bytes: &sampleRateValue, length: MemoryLayout<Int64>.size)
            let sampleRateTensor = try ORTValue(tensorData: sampleRateData, elementType: .int64, shape: [])

            let outputs = try session.run(
                withInputs: ["input": inputTensor, "state": stateTensor, "sr": sampleRateTensor],
                outputNames: ["output", "stateN"],
                runOptions: nil
            )

            guard let outputValue = outputs["output"], let stateValue = outputs["stateN"] else {
                throw SileroVADError.inferenceFailed("Missing output tensors")
            }

            let probabilityData = try outputValue.tensorData() as Data
            let probability = probabilityData.withUnsafeBytes { $0.load(as: Float.self) }

            let updatedStateData = try stateValue.tensorData() as Data
            state = updatedStateData.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }

            context = Array(modelInput.suffix(contextSize))

            return probability
        } catch let error as SileroVADError {
            throw error
        } catch {
            throw SileroVADError.inferenceFailed(error.localizedDescription)
        }
    }

    private static func floatTensor(_ values: [Float], shape: [NSNumber]) throws -> ORTValue {
        let data = NSMutableData(bytes: values, length: values.count * MemoryLayout<Float>.size)
        return try ORTValue(tensorData: data, elementType: .float, shape: shape)
    }
}
