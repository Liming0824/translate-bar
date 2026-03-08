// Sources/TranslateBar/Services/TranslationService.swift
import Foundation

enum TranslationError: Error, LocalizedError {
    case noApiKey
    case networkError(Error)
    case apiError(String)
    case emptyResult
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .noApiKey: return "Set your API key in settings"
        case .networkError(let err): return "Translation failed: \(err.localizedDescription)"
        case .apiError(let msg): return "API error: \(msg)"
        case .emptyResult: return "No translation available"
        case .invalidResponse: return "Invalid response from server"
        }
    }
}

final class TranslationService {
    private let apiKey: String
    private let session: URLSession
    private static let baseURL = "https://translation.googleapis.com/language/translate/v2"

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    func buildRequest(text: String, source: String, target: String) -> URLRequest {
        var components = URLComponents(string: Self.baseURL)!
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "q": text,
            "source": source,
            "target": target,
            "format": "text",
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }

    static func parseResponse(data: Data) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TranslationError.invalidResponse
        }

        if let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            throw TranslationError.apiError(message)
        }

        guard let dataObj = json["data"] as? [String: Any],
              let translations = dataObj["translations"] as? [[String: Any]],
              let first = translations.first,
              let translatedText = first["translatedText"] as? String else {
            throw TranslationError.emptyResult
        }

        return translatedText
    }

    func translate(text: String) async throws -> String {
        let pair = LanguageDetector.detect(text)
        let request = buildRequest(text: text, source: pair.source, target: pair.target)

        let (data, response) = try await session.data(for: request)

        // Always try to parse the body first — Google returns error details as JSON even on 4xx
        return try Self.parseResponse(data: data)
    }
}
