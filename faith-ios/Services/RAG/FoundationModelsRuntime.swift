import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// LLMRuntime backed by Apple's on-device Foundation Models framework
/// (`LanguageModelSession`). The model only **picks passage ids** and
/// writes a single sentence of framing — `CanonQuoteExtractor` then pulls
/// verbatim quotes from `CanonStore` so what the user reads is actual
/// canonical text, not the model's paraphrase.
///
/// **Availability gate:** `SystemLanguageModel.default.availability` is
/// checked at call time. Sim or pre-iOS-26 → `RetrievalOnlyRuntime`.
@MainActor
final class FoundationModelsRuntime: LLMRuntime {

    private let fallback = RetrievalOnlyRuntime()

    func reply(to prompt: String,
               tradition: Tradition,
               history: [ChatMessage]) async -> [MessageSegment] {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if case .available = SystemLanguageModel.default.availability {
                return await replyWithFoundationModels(to: prompt,
                                                        tradition: tradition,
                                                        history: history)
            }
        }
        #endif
        return await fallback.reply(to: prompt, tradition: tradition, history: history)
    }

    /// Streaming variant — yields incrementally complete segments as the
    /// model fills in the structured `ChatResponse`.
    func streamReply(to prompt: String,
                     tradition: Tradition,
                     history: [ChatMessage]) -> AsyncStream<[MessageSegment]> {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if case .available = SystemLanguageModel.default.availability {
                return streamReplyWithFoundationModels(to: prompt,
                                                        tradition: tradition,
                                                        history: history)
            }
        }
        #endif
        return fallback.streamReply(to: prompt, tradition: tradition, history: history)
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func replyWithFoundationModels(to prompt: String,
                                           tradition: Tradition,
                                           history: [ChatMessage]) async -> [MessageSegment] {
        await EmbeddingIndex.shared.buildIfNeeded()
        let session = LanguageModelSession(
            tools: [SearchCanonTool()],
            instructions: Self.instructions(for: tradition)
        )
        do {
            let response = try await session.respond(to: prompt, generating: ChatResponse.self)
            return Self.makeSegments(from: response.content, query: prompt)
        } catch {
            print("⚠️ FoundationModels error: \(error)")
            return await fallback.reply(to: prompt, tradition: tradition, history: history)
        }
    }

    /// Convert the model's structured response into chat segments. The
    /// model only writes `framing`; the canonical quote text comes from
    /// `CanonStore` via `CanonQuoteExtractor`. Used for both the final
    /// non-streaming response and each streaming snapshot.
    private static func makeSegments(from response: ChatResponse, query: String) -> [MessageSegment] {
        makeSegments(framing: response.framing, citations: response.citations, query: query)
    }

    private static func makeSegments(framing: String?, citations: [String]?, query: String) -> [MessageSegment] {
        var segments: [MessageSegment] = []
        if let framing {
            let cleaned = stripMarkdown(framing).trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleaned.isEmpty {
                segments.append(.text(cleaned + " "))
            }
        }
        guard let citations else { return segments }
        let canon = CanonStore.shared
        for id in citations {
            guard let passage = canon.passage(byID: id) else { continue }
            let quote = CanonQuoteExtractor.quote(from: passage, query: query)
            let cite = SuttaCite(
                code: passage.code,
                englishTitle: passage.englishTitle,
                suttaID: passage.id
            )
            if !quote.isEmpty {
                segments.append(.italic("\u{201C}" + quote + "\u{201D}"))
                segments.append(.text(" "))
            }
            segments.append(.citation(cite))
            segments.append(.text(" "))
        }
        return segments
    }

    @available(iOS 26.0, *)
    private func streamReplyWithFoundationModels(to prompt: String,
                                                 tradition: Tradition,
                                                 history: [ChatMessage]) -> AsyncStream<[MessageSegment]> {
        AsyncStream { continuation in
            let fallback = self.fallback
            let task = Task { @MainActor in
                await EmbeddingIndex.shared.buildIfNeeded()
                let session = LanguageModelSession(
                    tools: [SearchCanonTool()],
                    instructions: Self.instructions(for: tradition)
                )
                do {
                    let stream = session.streamResponse(to: prompt,
                                                         generating: ChatResponse.self)
                    for try await snapshot in stream {
                        let partial = snapshot.content
                        let segments = Self.makeSegments(
                            framing: partial.framing,
                            citations: partial.citations,
                            query: prompt
                        )
                        if !segments.isEmpty {
                            continuation.yield(segments)
                        }
                    }
                } catch {
                    print("⚠️ FoundationModels stream error: \(error)")
                    let final = await fallback.reply(to: prompt, tradition: tradition, history: history)
                    continuation.yield(final)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// System prompt for the librarian. Pulled out so both the streaming
    /// and non-streaming paths use identical instructions.
    @available(iOS 26.0, *)
    private static func instructions(for tradition: Tradition) -> String {
        _ = tradition
        return """
        You are a Buddhist librarian. Answer briefly and faithfully — paraphrase is welcome, opinion beyond the canon is not. Every substantive claim must come from a passage you cite.

        For substantive questions about Buddhism (doctrine, practice, a feeling like anger or grief, a topic like impermanence or sensuality):
        - Call searchCanon with 2–6 well-chosen English words. Include canonical synonyms for colloquial terms ("sex" → "sensuality lust desire kāma", "anxiety" → "fear worry restlessness").
        - Then fill the structured response:
          - `framing`: 2 to 4 sentences. Paraphrase what the canon teaches on this. Stay close to the actual texts — do not invent doctrine, do not add wellness platitudes, do not cite anything outside Buddhism. Do NOT include passage codes inline; references go in the citations field. NO markdown.
          - `citations`: 1 to 3 passage ids you drew on, from the tool's results. The app renders verbatim quotes from these ids underneath your framing — your job is the synthesis, theirs is the evidence.

        For greetings, thanks, or short clarifying exchanges:
        - Do NOT call the tool.
        - `framing`: one friendly sentence inviting a substantive question.
        - `citations`: empty.

        Strict rules:
        - NEVER make claims about Buddhism that aren't backed by one of your citations.
        - NEVER use markdown, asterisks, headings, bullet points, or numbered lists.
        - NEVER write more than 4 sentences.
        - NEVER paraphrase BEYOND what the texts actually say. If the canon doesn't speak to the question, say so plainly with empty citations.
        """
    }

    /// Belt-and-suspenders: even with structured output, on-device FM may
    /// emit `**bold**` or numbered lists in `framing`. Strip them.
    private static func stripMarkdown(_ s: String) -> String {
        var r = s
        r = r.replacingOccurrences(of: "**", with: "")
        r = r.replacingOccurrences(of: "__", with: "")
        let lines = r.split(separator: "\n", omittingEmptySubsequences: false).map { line -> String in
            var l = String(line)
            l = l.replacingOccurrences(of: #"^\s*\d+\.\s*"#, with: "", options: .regularExpression)
            l = l.replacingOccurrences(of: #"^\s*[-*]\s+"#, with: "", options: .regularExpression)
            return l
        }
        return lines.joined(separator: " ").replacingOccurrences(of: "  ", with: " ")
    }
    #endif
}

#if canImport(FoundationModels)

@available(iOS 26.0, *)
@Generable(description: "A response from a Buddhist librarian.")
struct ChatResponse {
    @Guide(description: "2 to 4 sentences answering the question by faithfully paraphrasing what the canon teaches. No markdown, no asterisks, no headings, no lists. Do NOT include passage codes inline; references go in the citations field. Do NOT write outside Buddhism. For casual greetings, ONE friendly sentence.")
    let framing: String

    @Guide(description: "1 to 3 passage ids from the searchCanon tool that ground every claim in the framing. Use the EXACT id (e.g. 'mn21', 'an7.64'). Empty array for greetings or when no canonical passage applies.")
    let citations: [String]
}

@available(iOS 26.0, *)
@Generable
struct SearchCanonArguments {
    @Guide(description: "Short search query (2–6 words). Include canonical synonyms for colloquial terms.")
    let query: String
}

@available(iOS 26.0, *)
struct SearchCanonTool: Tool {
    typealias Arguments = SearchCanonArguments
    typealias Output = String

    let description = "Search the bundled Buddhist canon by semantic similarity. Returns up to 5 passages, each formatted as `[id] code · english title: snippet`. Use these ids in the response's citations field."

    var parameters: GenerationSchema { SearchCanonArguments.generationSchema }

    func call(arguments: SearchCanonArguments) async throws -> String {
        let lines = await MainActor.run { () -> [String] in
            let hits = EmbeddingIndex.shared.topK(query: arguments.query, k: 5)
            let canon = CanonStore.shared
            return hits.compactMap { hit -> String? in
                guard let p = canon.passage(byID: hit.passageID) else { return nil }
                let body = p.lines.map(\.text).joined(separator: " ")
                let snippet = body.count > 220 ? String(body.prefix(220)) + "…" : body
                return "[\(p.id)] \(p.code) · \(p.englishTitle): \(snippet)"
            }
        }
        if lines.isEmpty {
            return "No passages found for that query."
        }
        return lines.joined(separator: "\n")
    }
}

#endif
