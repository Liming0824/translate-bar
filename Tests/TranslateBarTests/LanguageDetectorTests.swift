// Tests/TranslateBarTests/LanguageDetectorTests.swift
import Testing
@testable import TranslateBar

struct LanguageDetectorTests {
    @Test func detectsChineseSimplified() {
        let result = LanguageDetector.detect("你好世界")
        #expect(result.source == "zh")
        #expect(result.target == "en")
    }

    @Test func detectsChineseTraditional() {
        let result = LanguageDetector.detect("計算機科學")
        #expect(result.source == "zh")
        #expect(result.target == "en")
    }

    @Test func detectsEnglish() {
        let result = LanguageDetector.detect("Hello world")
        #expect(result.source == "en")
        #expect(result.target == "zh")
    }

    @Test func mixedTextWithMajorityChinese() {
        let result = LanguageDetector.detect("这是一个test测试")
        #expect(result.source == "zh")
        #expect(result.target == "en")
    }

    @Test func mixedTextWithMajorityEnglish() {
        let result = LanguageDetector.detect("This is a 测试")
        #expect(result.source == "en")
        #expect(result.target == "zh")
    }

    @Test func emptyString() {
        let result = LanguageDetector.detect("")
        #expect(result.source == "en")
        #expect(result.target == "zh")
    }
}
