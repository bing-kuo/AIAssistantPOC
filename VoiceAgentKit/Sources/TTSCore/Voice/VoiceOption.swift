//
//  VoiceOption.swift
//  TTSCore
//

import Foundation

enum VoiceQuality: Int, Sendable, Equatable, Comparable {
    case `default` = 1
    case enhanced = 2
    case premium = 3

    static func < (lhs: VoiceQuality, rhs: VoiceQuality) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct VoiceOption: Sendable, Equatable {
    let identifier: String
    let language: String
    let quality: VoiceQuality
}
