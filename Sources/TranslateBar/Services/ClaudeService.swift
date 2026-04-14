// Sources/TranslateBar/Services/ClaudeService.swift
import Foundation

enum ClaudeError: Error, LocalizedError {
    case noApiKey
    case networkError(Error)
    case apiError(String)
    case emptyResult
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .noApiKey: return "Set your Claude API key in settings"
        case .networkError(let err): return "Request failed: \(err.localizedDescription)"
        case .apiError(let msg): return "Claude API error: \(msg)"
        case .emptyResult: return "No response generated"
        case .invalidResponse: return "Invalid response from Claude"
        }
    }
}

final class ClaudeService {
    private let apiKey: String
    private let session: URLSession
    private static let apiURL = "https://api.anthropic.com/v1/messages"

    private static let systemPrompt = """
        You are helping someone reply in a casual Slack conversation. \
        Generate a natural, friendly English response. The user will provide: \
        1) The message they are replying to. \
        2) What they want to say (may be in Chinese or rough English). \
        Interpret their meaning and produce a native-sounding English reply. \
        Keep it brief, conversational, and warm. This is off-topic small talk, not work discussion. \
        Reply with ONLY the response text, no quotes or explanation.
        """

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    func buildRequest(selectedMessage: String, userIntent: String) -> URLRequest {
        var request = URLRequest(url: URL(string: Self.apiURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let userContent = """
            Message I'm replying to: "\(selectedMessage)"

            What I want to say: "\(userIntent)"
            """

        let body: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 150,
            "system": Self.systemPrompt,
            "messages": [
                ["role": "user", "content": userContent]
            ]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }

    static func parseResponse(data: Data) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClaudeError.invalidResponse
        }

        if let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            throw ClaudeError.apiError(message)
        }

        guard let content = json["content"] as? [[String: Any]],
              let first = content.first,
              let text = first["text"] as? String else {
            throw ClaudeError.emptyResult
        }

        return text
    }

    func generateReply(selectedMessage: String, userIntent: String) async throws -> String {
        let request = buildRequest(selectedMessage: selectedMessage, userIntent: userIntent)

        do {
            let (data, _) = try await session.data(for: request)
            return try Self.parseResponse(data: data)
        } catch let error as ClaudeError {
            throw error
        } catch {
            throw ClaudeError.networkError(error)
        }
    }
}
