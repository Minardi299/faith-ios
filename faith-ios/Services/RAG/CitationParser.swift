import Foundation

/// Parses LLM output into the `[MessageSegment]` array Chat renders.
///
/// The model is instructed to emit inline tokens of the form `[SC:id]` to
/// cite passages. We split the buffer on those tokens and resolve each id
/// via `CanonStore.shared.passage(byID:)`. Unresolved ids fall back to
/// literal text — better to render the token verbatim than to drop it.
enum CitationParser {

    /// Static-pattern regex; safe to construct once.
    private static let regex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: #"\[SC:([^\]]+)\]"#)
    }()

    @MainActor
    static func parse(_ buffer: String) -> [MessageSegment] {
        guard !buffer.isEmpty else { return [] }
        let nsBuffer = buffer as NSString
        let matches = regex.matches(in: buffer, range: NSRange(location: 0, length: nsBuffer.length))
        guard !matches.isEmpty else { return [.text(buffer)] }

        let canon = CanonStore.shared
        var segments: [MessageSegment] = []
        var cursor = 0
        for match in matches {
            let r = match.range
            if r.location > cursor {
                let before = nsBuffer.substring(with: NSRange(location: cursor, length: r.location - cursor))
                if !before.isEmpty {
                    segments.append(.text(before))
                }
            }
            let idRange = match.range(at: 1)
            let id = nsBuffer.substring(with: idRange)
            if let passage = canon.passage(byID: id) {
                segments.append(.citation(SuttaCite(
                    code: passage.code,
                    englishTitle: passage.englishTitle,
                    suttaID: passage.id
                )))
            } else {
                // Keep the literal token visible rather than silently dropping
                // it; an unknown id is a bug we'll want to see.
                segments.append(.text(nsBuffer.substring(with: r)))
            }
            cursor = r.location + r.length
        }
        if cursor < nsBuffer.length {
            let trailing = nsBuffer.substring(with: NSRange(location: cursor, length: nsBuffer.length - cursor))
            if !trailing.isEmpty {
                segments.append(.text(trailing))
            }
        }
        return segments
    }
}
