// Tests/TranslateBarTests/GrammarServiceTests.swift
import Testing
import Foundation
@testable import TranslateBar

struct GrammarServiceTests {
    @Test func buildRequestURL() {
        let service = GrammarService()
        let request = service.buildRequest(text: "He dont goes there")

        #expect(request.url?.host == "api.languagetool.org")
        #expect(request.httpMethod == "POST")
    }

    @Test func buildRequestBody() throws {
        let service = GrammarService()
        let request = service.buildRequest(text: "She go to school")

        let body = String(data: request.httpBody!, encoding: .utf8)!
        #expect(body.contains("text=She"))
        #expect(body.contains("language=auto"))
    }

    @Test func parseResponseWithMatches() throws {
        let json = """
        {
            "matches": [
                {
                    "offset": 3,
                    "length": 4,
                    "replacements": [{ "value": "doesn't" }]
                }
            ]
        }
        """.data(using: .utf8)!

        let result = try GrammarService.parseResponse(data: json, originalText: "He dont go there")
        #expect(result == "He doesn't go there")
    }

    @Test func parseResponseNoMatches() throws {
        let json = """
        { "matches": [] }
        """.data(using: .utf8)!

        let result = try GrammarService.parseResponse(data: json, originalText: "This is correct.")
        #expect(result == "This is correct.")
    }

    @Test func parseInvalidJSON() {
        let data = "not json".data(using: .utf8)!

        #expect(throws: (any Error).self) {
            try GrammarService.parseResponse(data: data, originalText: "test")
        }
    }

    @Test func parseResponseMissingMatches() {
        let json = """
        { "software": { "name": "LanguageTool" } }
        """.data(using: .utf8)!

        #expect(throws: (any Error).self) {
            try GrammarService.parseResponse(data: json, originalText: "test")
        }
    }
}
