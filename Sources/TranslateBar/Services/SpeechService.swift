import AVFoundation
import Foundation

final class SpeechService: NSObject, AVAudioPlayerDelegate, @unchecked Sendable {
    private let apiKey: String
    private let session: URLSession
    private var player: AVAudioPlayer?
    private var onFinished: (() -> Void)?
    private static let baseURL = "https://texttospeech.googleapis.com/v1/text:synthesize"

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    var isPlaying: Bool {
        player?.isPlaying ?? false
    }

    func stop() {
        player?.stop()
        player = nil
        onFinished?()
        onFinished = nil
    }

    func speak(text: String, languageCode: String, onFinished: @escaping () -> Void) async throws {
        stop()
        self.onFinished = onFinished

        var components = URLComponents(string: Self.baseURL)!
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "input": ["text": text],
            "voice": ["languageCode": languageCode],
            "audioConfig": ["audioEncoding": "MP3"],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await session.data(for: request)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SpeechError.invalidResponse
        }

        if let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            throw SpeechError.apiError(message)
        }

        guard let audioContent = json["audioContent"] as? String,
              let audioData = Data(base64Encoded: audioContent) else {
            throw SpeechError.invalidResponse
        }

        let audioPlayer = try AVAudioPlayer(data: audioData)
        audioPlayer.delegate = self
        self.player = audioPlayer
        audioPlayer.play()
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        self.player = nil
        onFinished?()
        onFinished = nil
    }
}

enum SpeechError: Error, LocalizedError {
    case invalidResponse
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response from TTS API"
        case .apiError(let msg): return "TTS error: \(msg)"
        }
    }
}
