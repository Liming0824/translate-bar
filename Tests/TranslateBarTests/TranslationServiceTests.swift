// Tests/TranslateBarTests/TranslationServiceTests.swift
import Testing
import Foundation
@testable import TranslateBar

struct TranslationServiceTests {
    @Test func buildRequestURL() {
        let service = TranslationService(apiKey: "fake-key")
        let request = service.buildRequest(text: "hello", source: "en", target: "zh")

        #expect(request.url?.host == "translation.googleapis.com")
        #expect(request.httpMethod == "POST")
        #expect(request.httpBody != nil)
    }

    @Test func buildRequestBody() throws {
        let service = TranslationService(apiKey: "fake-key")
        let request = service.buildRequest(text: "hello", source: "en", target: "zh")

        let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        #expect(body["q"] as? String == "hello")
        #expect(body["source"] as? String == "en")
        #expect(body["target"] as? String == "zh")
    }

    @Test func parseSuccessResponse() throws {
        let json = """
        {
            "data": {
                "translations": [
                    { "translatedText": "你好" }
                ]
            }
        }
        """.data(using: .utf8)!

        let result = try TranslationService.parseResponse(data: json)
        #expect(result == "你好")
    }

    @Test func parseErrorResponse() {
        let json = """
        { "error": { "message": "bad request" } }
        """.data(using: .utf8)!

        #expect(throws: (any Error).self) {
            try TranslationService.parseResponse(data: json)
        }
    }

    @Test func parseEmptyTranslations() {
        let json = """
        { "data": { "translations": [] } }
        """.data(using: .utf8)!

        #expect(throws: (any Error).self) {
            try TranslationService.parseResponse(data: json)
        }
    }
}
