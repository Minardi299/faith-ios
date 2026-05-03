import Foundation
import NaturalLanguage

actor VerseRetriever {
    static let shared = VerseRetriever()

    private struct Row {
        let verse: Verse
        let vector: [Float]
    }

    private var rows: [Row] = []
    private var ready = false
    private let dim = 512
    private let cacheVersion: UInt32 = 1

    func warm(verses: [Verse]) async {
        guard !ready else { return }
        if let loaded = loadCache(verses: verses) {
            rows = loaded
            ready = true
            return
        }
        rows = build(verses: verses)
        ready = !rows.isEmpty
        if ready { saveCache(rows: rows, verses: verses) }
    }

    func topK(query: String, k: Int = 3) -> [Verse] {
        guard ready, !rows.isEmpty else { return [] }
        guard let q = embed(query) else {
            return keywordFallback(query: query, k: k)
        }
        let scored = rows.map { (row: $0, score: dot(q, $0.vector)) }
        return scored
            .sorted { $0.score > $1.score }
            .prefix(k)
            .map { $0.row.verse }
    }

    private func build(verses: [Verse]) -> [Row] {
        var built: [Row] = []
        built.reserveCapacity(verses.count)
        for verse in verses {
            let corpus = corpus(for: verse)
            guard let vec = embed(corpus) else { continue }
            built.append(Row(verse: verse, vector: vec))
        }
        return built
    }

    private func corpus(for verse: Verse) -> String {
        "Verse \(verse.number) (\(verse.chapterTitle)): \(verse.text)\n\nStory: \(verse.story)"
    }

    private func embed(_ text: String) -> [Float]? {
        guard let embedding = NLEmbedding.sentenceEmbedding(for: .english) else { return nil }
        guard let vec = embedding.vector(for: text) else { return nil }
        var v = vec.map { Float($0) }
        normalize(&v)
        return v
    }

    private func normalize(_ v: inout [Float]) {
        var sum: Float = 0
        for x in v { sum += x * x }
        let norm = sum.squareRoot()
        guard norm > 0 else { return }
        for i in v.indices { v[i] /= norm }
    }

    private func dot(_ a: [Float], _ b: [Float]) -> Float {
        var s: Float = 0
        let n = min(a.count, b.count)
        for i in 0..<n { s += a[i] * b[i] }
        return s
    }

    private func keywordFallback(query: String, k: Int) -> [Verse] {
        let terms = query
            .lowercased()
            .split(whereSeparator: { !$0.isLetter })
            .map(String.init)
            .filter { $0.count > 2 }
        guard !terms.isEmpty else { return [] }
        let scored = rows.map { row -> (Verse, Int) in
            let blob = (row.verse.text + " " + row.verse.story).lowercased()
            let score = terms.reduce(0) { $0 + (blob.contains($1) ? 1 : 0) }
            return (row.verse, score)
        }
        return scored
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .prefix(k)
            .map { $0.0 }
    }

    // MARK: - Disk cache

    private var cacheURL: URL? {
        guard let dir = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else { return nil }
        return dir.appendingPathComponent("verses.embeddings.bin")
    }

    private func dataHash(verses: [Verse]) -> UInt64 {
        var h: UInt64 = 0xcbf29ce484222325
        let prime: UInt64 = 0x100000001b3
        for v in verses {
            for byte in v.text.utf8 { h = (h ^ UInt64(byte)) &* prime }
            for byte in v.story.utf8 { h = (h ^ UInt64(byte)) &* prime }
        }
        return h
    }

    private func saveCache(rows: [Row], verses: [Verse]) {
        guard let url = cacheURL else { return }
        var data = Data()
        var version = cacheVersion
        var count = UInt32(rows.count)
        var dimension = UInt32(dim)
        var hash = dataHash(verses: verses)
        withUnsafeBytes(of: &version) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: &count) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: &dimension) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: &hash) { data.append(contentsOf: $0) }
        for row in rows {
            var num = Int32(row.verse.number)
            withUnsafeBytes(of: &num) { data.append(contentsOf: $0) }
            row.vector.withUnsafeBufferPointer { buf in
                data.append(UnsafeBufferPointer(start: buf.baseAddress, count: buf.count))
            }
        }
        try? data.write(to: url, options: .atomic)
    }

    private func loadCache(verses: [Verse]) -> [Row]? {
        guard let url = cacheURL, let data = try? Data(contentsOf: url) else { return nil }
        let headerSize = 4 + 4 + 4 + 8
        guard data.count >= headerSize else { return nil }
        let version: UInt32 = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 0, as: UInt32.self) }
        let count: UInt32 = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 4, as: UInt32.self) }
        let dimension: UInt32 = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 8, as: UInt32.self) }
        let hash: UInt64 = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 12, as: UInt64.self) }
        guard version == cacheVersion,
              Int(dimension) == dim,
              Int(count) == verses.count,
              hash == dataHash(verses: verses) else { return nil }

        let rowSize = 4 + dim * MemoryLayout<Float>.size
        let expected = headerSize + Int(count) * rowSize
        guard data.count == expected else { return nil }

        let byNumber = Dictionary(uniqueKeysWithValues: verses.map { ($0.number, $0) })
        var loaded: [Row] = []
        loaded.reserveCapacity(Int(count))
        var offset = headerSize
        for _ in 0..<Int(count) {
            let num: Int32 = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: Int32.self) }
            offset += 4
            var vec = [Float](repeating: 0, count: dim)
            vec.withUnsafeMutableBufferPointer { buf in
                data.copyBytes(to: buf, from: offset..<(offset + dim * MemoryLayout<Float>.size))
            }
            offset += dim * MemoryLayout<Float>.size
            guard let verse = byNumber[Int(num)] else { return nil }
            loaded.append(Row(verse: verse, vector: vec))
        }
        return loaded
    }
}
