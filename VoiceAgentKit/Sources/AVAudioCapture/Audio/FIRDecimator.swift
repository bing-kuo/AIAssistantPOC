//
//  FIRDecimator.swift
//  AVAudioCapture
//

import Accelerate

struct FIRDecimator {

    let factor: Int
    private let taps: [Float]
    private var history: [Float]

    init(factor: Int, cutoffHz: Double, inputSampleRate: Double, tapCount: Int = 127) {
        self.factor = factor
        self.taps = FIRDecimator.lowPassTaps(tapCount: tapCount, cutoffHz: cutoffHz, sampleRate: inputSampleRate)
        self.history = [Float](repeating: 0, count: tapCount - 1)
    }

    mutating func process(_ input: [Float]) -> [Float] {
        guard !input.isEmpty else { return [] }

        var work = history
        work.append(contentsOf: input)

        let tapCount = taps.count
        guard work.count >= tapCount else {
            history = work
            return []
        }

        let outputCount = (work.count - tapCount) / factor + 1
        var output = [Float](repeating: 0, count: outputCount)
        vDSP_desamp(work, vDSP_Stride(factor), taps, &output, vDSP_Length(outputCount), vDSP_Length(tapCount))

        history = Array(work[(outputCount * factor)...])
        return output
    }

    private static func lowPassTaps(tapCount: Int, cutoffHz: Double, sampleRate: Double) -> [Float] {
        let order = tapCount - 1
        let normalizedCutoff = cutoffHz / sampleRate
        var coefficients = [Float](repeating: 0, count: tapCount)
        var sum: Double = 0

        for index in 0...order {
            let offset = Double(index) - Double(order) / 2
            let sinc = offset == 0
                ? 2 * normalizedCutoff
                : sin(2 * Double.pi * normalizedCutoff * offset) / (Double.pi * offset)
            let hamming = 0.54 - 0.46 * cos(2 * Double.pi * Double(index) / Double(order))
            let value = sinc * hamming
            coefficients[index] = Float(value)
            sum += value
        }

        if sum != 0 {
            for index in 0...order { coefficients[index] /= Float(sum) }
        }
        return coefficients
    }
}
