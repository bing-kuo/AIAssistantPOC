//
//  SileroVADTests.swift
//  VoiceIntelligenceTests
//

import Testing
@testable import VoiceIntelligence

@Suite("SileroVAD")
struct SileroVADTests {

    @Test("loads the bundled model and scores silence as low probability")
    func scoresSilence() async throws {
        // Given a loaded model and a window of pure silence
        let sut = try SileroVAD()
        let silence = [Float](repeating: 0, count: 512)

        // When
        let probability = try await sut.score(silence)

        // Then silence should be well below the speech threshold
        #expect(probability >= 0)
        #expect(probability < 0.5)
    }

    @Test("rejects a window of the wrong size")
    func rejectsWrongWindowSize() async throws {
        // Given
        let sut = try SileroVAD()

        // When / Then
        await #expect(throws: SileroVADError.invalidWindowSize(expected: 512, actual: 256)) {
            _ = try await sut.score([Float](repeating: 0, count: 256))
        }
    }

    @Test("produces a stable probability across repeated silent windows")
    func stableAcrossWindows() async throws {
        // Given
        let sut = try SileroVAD()
        let silence = [Float](repeating: 0, count: 512)

        // When
        var last: Float = 1
        for _ in 0..<5 {
            last = try await sut.score(silence)
        }

        // Then recurrent state keeps silence probability low
        #expect(last < 0.5)
    }
}
