//
//  DominantLanguageDetectorTests.swift
//  TTSCoreTests
//

import Testing
@testable import TTSCore

@Suite("DominantLanguageDetector")
struct DominantLanguageDetectorTests {

    @Test("pure Chinese resolves to Traditional Chinese")
    func pureChinese() {
        #expect(DominantLanguageDetector.detect("今天天氣很好") == .traditionalChinese)
    }

    @Test("pure English resolves to English")
    func pureEnglish() {
        #expect(DominantLanguageDetector.detect("Hello there friend") == .english)
    }

    @Test("Chinese-majority mixed text resolves to Traditional Chinese")
    func chineseMajority() {
        #expect(DominantLanguageDetector.detect("今天天氣真的很好很好 ok") == .traditionalChinese)
    }

    @Test("English-majority mixed text resolves to English")
    func englishMajority() {
        #expect(DominantLanguageDetector.detect("Open the 設定 please now") == .english)
    }

    @Test("empty or symbol-only text falls back to English")
    func fallback() {
        #expect(DominantLanguageDetector.detect("") == .english)
        #expect(DominantLanguageDetector.detect("123 !!! ???") == .english)
    }
}
