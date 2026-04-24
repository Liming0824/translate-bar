// Sources/TranslateBar/Services/GrammarService.swift
import Foundation

enum GrammarError: Error, LocalizedError {
    case networkError(Error)
    case emptyResult
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .networkError(let err): return "Grammar check failed: \(err.localizedDescription)"
        case .emptyResult: return "No corrections available"
        case .invalidResponse: return "Invalid response from server"
        }
    }
}

final class GrammarService {
    private let session: URLSession
    private static let apiURL = "https://api.languagetool.org/v2/check"

    init(session: URLSession = .shared) {
        self.session = session
    }

    func buildRequest(text: String) -> URLRequest {
        var request = URLRequest(url: URL(string: Self.apiURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "text", value: text),
            URLQueryItem(name: "language", value: "auto"),
        ]
        request.httpBody = components.query?.data(using: .utf8)
        return request
    }

    static func parseResponse(data: Data, originalText: String) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GrammarError.invalidResponse
        }

        guard let matches = json["matches"] as? [[String: Any]] else {
            throw GrammarError.invalidResponse
        }

        if matches.isEmpty {
            return originalText
        }

        // Apply replacements in reverse order to preserve offsets
        var corrected = originalText
        let sorted = matches.sorted {
            ($0["offset"] as? Int ?? 0) > ($1["offset"] as? Int ?? 0)
        }

        for match in sorted {
            guard let offset = match["offset"] as? Int,
                  let length = match["length"] as? Int,
                  let replacements = match["replacements"] as? [[String: Any]],
                  let first = replacements.first,
                  let replacement = first["value"] as? String else {
                continue
            }

            let start = corrected.index(corrected.startIndex, offsetBy: offset)
            let end = corrected.index(start, offsetBy: length)
            corrected.replaceSubrange(start..<end, with: replacement)
        }

        return corrected
    }

    func polish(text: String) async throws -> String {
        let request = buildRequest(text: text)
        let (data, _) = try await session.data(for: request)
        return try Self.parseResponse(data: data, originalText: text)
    }
}
