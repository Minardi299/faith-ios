import Foundation

actor AIService {
    static let shared = AIService()

    private let baseURL = URL(string: "https://ai.starb.ca")!
    private let model = "gpt-4o-mini"
    private let apiKey: String? = nil

    func reply(to messages: [ChatMessage]) async throws -> String {
        let payload = ChatRequest(
            model: model,
            messages: messages.map { .init(role: $0.role, content: $0.content) }
        )
        var request = URLRequest(url: baseURL.appendingPathComponent("v1/chat/completions"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AIError.badResponse
        }
        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        return decoded.choices.first?.message.content ?? ""
    }

    enum AIError: Error { case badResponse }

    private struct ChatRequest: Encodable {
        let model: String
        let messages: [Message]
        struct Message: Encodable {
            let role: String
            let content: String
        }
    }

    private struct ChatResponse: Decodable {
        let choices: [Choice]
        struct Choice: Decodable { let message: Message }
        struct Message: Decodable { let role: String; let content: String }
    }
}
