//
//  AudioMath.swift
//  VoiceCore
//

import Foundation

/// A collection of mathematical utilities for real-time audio signal processing.
public enum AudioMath {

    /// Computes the Root-Mean-Square (RMS) amplitude of an array of PCM audio samples.
    /// - Parameter samples: An array of floating-point audio samples.
    /// - Returns: The computed RMS amplitude representing the overall audio level.
    public static func rms(_ samples: [Float]) -> Float {
        samples.withUnsafeBufferPointer { rms($0) }
    }

    /// Computes the Root-Mean-Square (RMS) amplitude directly from a memory buffer pointer.
    /// - Parameter samples: A buffer pointer referencing the raw floating-point audio data.
    /// - Returns: The computed RMS amplitude, or `0.0` if the buffer is empty or invalid.
    public static func rms(_ samples: UnsafeBufferPointer<Float>) -> Float {
        guard let base = samples.baseAddress, samples.count > 0 else { return 0 }
        
        var sumOfSquares: Float = 0
        for i in 0..<samples.count {
            let sample = base[i]
            sumOfSquares += sample * sample
        }
        return (sumOfSquares / Float(samples.count)).squareRoot()
    }
}
