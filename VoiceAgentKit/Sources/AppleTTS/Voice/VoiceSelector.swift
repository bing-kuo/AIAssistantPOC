//
//  VoiceSelector.swift
//  AppleTTS
//

import Foundation

enum VoiceSelector {

    static func select(for language: SpeechLanguage, from voices: [VoiceOption]) -> VoiceOption? {
        let matches = voices.filter { $0.language.hasPrefix(language.languageCode) }
        guard !matches.isEmpty else { return nil }
        return matches.max { lhs, rhs in
            if lhs.quality != rhs.quality { return lhs.quality < rhs.quality }
            let lhsExact = lhs.language == language.bcp47
            let rhsExact = rhs.language == language.bcp47
            if lhsExact != rhsExact { return rhsExact }
            return lhs.identifier > rhs.identifier
        }
    }
}
