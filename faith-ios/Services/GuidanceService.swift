import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

final class GuidanceService {
    static let shared = GuidanceService()

    enum Availability: Equatable {
        case available
        case unsupportedOS
        case appleIntelligenceUnavailable(String)
    }

    enum ServiceError: Error {
        case unavailable
        case noContext
    }

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

    var availability: Availability {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return Self.modernAvailability()
        } else {
            return .unsupportedOS
        }
        #else
        return .unsupportedOS
        #endif
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private static func modernAvailability() -> Availability {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            return .available
        case .unavailable(let reason):
            return .appleIntelligenceUnavailable(String(describing: reason))
        @unknown default:
            return .appleIntelligenceUnavailable("unknown")
        }
    }
    #endif

    func streamReply(
        history: [ChatMessage],
        userMessage: String,
        verses: [Verse]
    ) -> AsyncThrowingStream<StreamEvent, Error> {
        AsyncThrowingStream { continuation in
            #if canImport(FoundationModels)
            if #available(iOS 26.0, *) {
                Task { @MainActor in
                    await self.runModern(
                        history: history,
                        userMessage: userMessage,
                        verses: verses,
                        continuation: continuation
                    )
                }
                return
            }
            #endif
            continuation.finish(throwing: ServiceError.unavailable)
        }
    }

    struct StreamEvent {
        var text: String
        var citedVerseNumbers: [Int]
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func runModern(
        history: [ChatMessage],
        userMessage: String,
        verses: [Verse],
        continuation: AsyncThrowingStream<StreamEvent, Error>.Continuation
    ) async {
        guard case .available = availability else {
            continuation.finish(throwing: ServiceError.unavailable)
            return
        }

        let retrieved = await VerseRetriever.shared.topK(query: userMessage, k: 3)
        let citedNumbers = retrieved.map(\.number)
        let prompt = buildPrompt(history: history, userMessage: userMessage, retrieved: retrieved)

        do {
            let session = LanguageModelSession(instructions: Self.instructionsText)
            let stream = session.streamResponse(to: prompt)
            for try await snapshot in stream {
                continuation.yield(StreamEvent(text: snapshot.content, citedVerseNumbers: citedNumbers))
            }
            continuation.finish()
        } catch {
            continuation.finish(throwing: error)
        }
    }
    #endif

    private func buildPrompt(history: [ChatMessage], userMessage: String, retrieved: [Verse]) -> String {
        var lines: [String] = []
        if !retrieved.isEmpty {
            lines.append("Relevant verses to draw from:")
            for v in retrieved {
                lines.append("---")
                lines.append("Dhammapada \(v.number) (\(v.chapterTitle)): \"\(v.text.trimmingCharacters(in: .whitespacesAndNewlines))\"")
                let storyTrim = v.story.prefix(400)
                lines.append("Story: \(storyTrim)\(v.story.count > 400 ? "…" : "")")
            }
            lines.append("---")
            lines.append("")
        }
        let recent = history.suffix(6)
        if !recent.isEmpty {
            lines.append("Recent conversation:")
            for m in recent {
                let label = m.roleValue == .user ? "user" : "assistant"
                lines.append("\(label): \(m.content)")
            }
            lines.append("")
        }
        lines.append("user: \(userMessage)")
        lines.append("assistant:")
        return lines.joined(separator: "\n")
    }
}
