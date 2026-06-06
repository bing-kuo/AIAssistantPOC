//
//  DominantLanguageDetector.swift
//  TTSCore
//

import Foundation

enum SpeechLanguage: Sendable, Equatable {
    case traditionalChinese
    case english

    var bcp47: String {
        switch self {
        case .traditionalChinese: "zh-TW"
        case .english: "en-US"
        }
    }

    var languageCode: String {
        switch self {
        case .traditionalChinese: "zh"
        case .english: "en"
        }
    }
}

enum DominantLanguageDetector {

    static func detect(_ text: String) -> SpeechLanguage {
        var hanCount = 0
        var latinCount = 0
        for scalar in text.unicodeScalars {
            if isHan(scalar) {
                hanCount += 1
            } else if isLatinLetter(scalar) {
                latinCount += 1
            }
        }
        return hanCount > latinCount ? .traditionalChinese : .english
    }

    private static func isHan(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF, 0x20000...0x2FA1F:
            return true
        default:
            return false
        }
    }

    private static func isLatinLetter(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x41...0x5A, 0x61...0x7A:
            return true
        default:
            return false
        }
    }
}
