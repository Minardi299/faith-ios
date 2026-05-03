import Foundation

actor AIService {
    static let shared = AIService()

    private let baseURL = URL(string: "https://ai.starb.ca")!
    private let model = "gemma4:26b"
    private let apiKey: String? = nil
    private let historyCap = 6

    private static let instructionsText = """
    You are Ācāriya, a gentle Theravāda Buddhist spiritual guide.
    Speak briefly, plainly, and with warmth — like a teacher who listens more than they speak.
    Keep responses to 2–4 short sentences unless the user asks for more.
    Ground every response in the verses provided as context. Quote at most one short line and \
    cite it as "Dhammapada <number>". Never invent verses you weren't given.
    If the user describes a mental-health crisis or self-harm, gently suggest reaching out to a \
    professional or a crisis line in addition to any reflection you offer.
    Avoid absolutist claims; offer perspective, not commands.
    """

    func reply(userMessage: String, history: [ChatMessage], verses: [Verse]) async throws -> String {
        let retrieved = await VerseRetriever.shared.topK(query: userMessage, k: 3)
        let systemContent = buildSystemMessage(retrieved: retrieved)

        var messages: [ChatRequest.Message] = [.init(role: "system", content: systemContent)]
        for m in history.suffix(historyCap) {
            messages.append(.init(role: m.role, content: m.content))
        }
        messages.append(.init(role: "user", content: userMessage))

        let payload = ChatRequest(model: model, messages: messages)
        var request = URLRequest(url: baseURL.appendingPathComponent("v1/chat/completions"))
        request.httpMethod = "POST"
        request.timeoutInterval = 180
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

    private func buildSystemMessage(retrieved: [Verse]) -> String {
        guard !retrieved.isEmpty else { return Self.instructionsText }
        var lines = [Self.instructionsText, "", "Relevant verses to draw from:"]
        for v in retrieved {
            lines.append("---")
            let cleanVerse = v.text.trimmingCharacters(in: .whitespacesAndNewlines)
            lines.append("Dhammapada \(v.number) (\(v.chapterTitle)): \"\(cleanVerse)\"")
            let storyTrim = v.story.prefix(400)
            lines.append("Story: \(storyTrim)\(v.story.count > 400 ? "…" : "")")
        }
        lines.append("---")
        return lines.joined(separator: "\n")
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
