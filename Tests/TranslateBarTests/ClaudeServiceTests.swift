// Tests/TranslateBarTests/ClaudeServiceTests.swift
import Testing
import Foundation
@testable import TranslateBar

struct ClaudeServiceTests {
    @Test func buildRequestURL() {
        let service = ClaudeService(apiKey: "test-key")
        let request = service.buildRequest(
            selectedMessage: "hey how's it going",
            userIntent: "还不错"
        )

        #expect(request.url?.absoluteString == "https://api.anthropic.com/v1/messages")
        #expect(request.httpMethod == "POST")
    }

    @Test func buildRequestHeaders() {
        let service = ClaudeService(apiKey: "test-key")
        let request = service.buildRequest(
            selectedMessage: "hey how's it going",
            userIntent: "还不错"
        )

        #expect(request.value(forHTTPHeaderField: "x-api-key") == "test-key")
        #expect(request.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
        #expect(request.value(forHTTPHeaderField: "content-type") == "application/json")
    }

    @Test func buildRequestBody() throws {
        let service = ClaudeService(apiKey: "test-key")
        let request = service.buildRequest(
            selectedMessage: "hey how's it going",
            userIntent: "还不错"
        )

        let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        #expect(body["model"] as? String == "claude-haiku-4-5-20251001")
        #expect(body["max_tokens"] as? Int == 150)

        let system = body["system"] as? String
        #expect(system != nil)
        #expect(system!.contains("casual"))

        let messages = body["messages"] as? [[String: Any]]
        #expect(messages?.count == 1)
        let content = messages?.first?["content"] as? String
        #expect(content?.contains("hey how's it going") == true)
        #expect(content?.contains("还不错") == true)
    }

    @Test func parseSuccessResponse() throws {
        let json = """
        {
            "content": [
                { "type": "text", "text": "Not bad at all!" }
            ]
        }
        """.data(using: .utf8)!

        let result = try ClaudeService.parseResponse(data: json)
        #expect(result == "Not bad at all!")
    }

    @Test func parseErrorResponse() {
        let json = """
        {
            "error": { "type": "invalid_request_error", "message": "bad request" }
        }
        """.data(using: .utf8)!

        #expect(throws: (any Error).self) {
            try ClaudeService.parseResponse(data: json)
        }
    }

    @Test func parseEmptyContent() {
        let json = """
        { "content": [] }
        """.data(using: .utf8)!

        #expect(throws: (any Error).self) {
            try ClaudeService.parseResponse(data: json)
        }
    }
}
