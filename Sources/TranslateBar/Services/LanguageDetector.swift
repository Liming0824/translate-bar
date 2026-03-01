// Sources/TranslateBar/Services/LanguageDetector.swift
import Foundation

struct LanguagePair {
    let source: String
    let target: String
}

enum LanguageDetector {
    /// Detects whether text is primarily Chinese or English.
    /// Returns source/target pair for translation.
    static func detect(_ text: String) -> LanguagePair {
        let cjkCount = text.unicodeScalars.filter { scalar in
            // CJK Unified Ideographs
            (0x4E00...0x9FFF).contains(scalar.value) ||
            // CJK Extension A
            (0x3400...0x4DBF).contains(scalar.value) ||
            // CJK Extension B
            (0x20000...0x2A6DF).contains(scalar.value) ||
            // CJK Compatibility Ideographs
            (0xF900...0xFAFF).contains(scalar.value)
        }.count

        let totalLetters = text.unicodeScalars.filter { !$0.properties.isWhitespace }.count
        guard totalLetters > 0 else {
            return LanguagePair(source: "en", target: "zh")
        }

        let cjkRatio = Double(cjkCount) / Double(totalLetters)
        if cjkRatio > 0.3 {
            return LanguagePair(source: "zh", target: "en")
        } else {
            return LanguagePair(source: "en", target: "zh")
        }
    }
}
