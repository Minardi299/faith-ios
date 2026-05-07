import Foundation
import NaturalLanguage
import Observation

/// On-device retrieval index over the bundled canon. Each non-stub passage
/// with body text gets a single L2-normalised vector built by averaging the
/// per-word `NLEmbedding.wordEmbedding(for: .english)` vectors of its tokens.
///
/// We use word embeddings rather than sentence embeddings because Apple's
/// English sentence model is **not present on iOS Simulator runtimes** — it
/// returns nil — but word embeddings have been supported since iOS 13 and
/// work everywhere.
///
/// **Three load sources**, in order:
/// 1. `embeddings.bin` shipped in the app bundle (built at compile time by
///    `tools/build_embeddings.swift`). Zero cold-start cost.
/// 2. `embeddings.bin` previously written to Application Support by a
///    runtime rebuild on a prior launch.
/// 3. Runtime rebuild over `CanonStore.shared` — used as a development
///    fallback when the bundle has no precomputed file (or its dim is stale).
///
/// The `topK` return type carries `line: Int` for forward compatibility with
/// line-level chunking; for now it is always `-1` (whole passage).
@MainActor
final class EmbeddingIndex: ObservableObject {

    static let shared = EmbeddingIndex()

    enum BuildStatus: Equatable, CustomStringConvertible {
        case idle
        case building(progress: Double)
        case ready(count: Int)
        case failed(message: String)

        var description: String {
            switch self {
            case .idle: return "idle"
            case .building(let p): return "building(\(Int(p * 100))%)"
            case .ready(let n): return "ready(\(n))"
            case .failed(let m): return "failed(\(m))"
            }
        }
    }

    @Published private(set) var status: BuildStatus = .idle

    private let fileMagic: UInt32 = 0x454D4231 // "EMB1"
    private let fileVersion: UInt32 = 1
    private let bundledFileName = "embeddings"
    private let bundledFileExt = "bin"

    private struct Entry { let id: String; let vec: [Float] }
    private var entries: [Entry] = []
    private var indexDim: Int = 0

    private init() {}

    // MARK: - Public API

    /// Hydrate from the bundle, then from Application Support, otherwise
    /// rebuild from `CanonStore`. Idempotent — safe to call multiple times.
    func buildIfNeeded() async {
        switch status {
        case .ready, .building: return
        default: break
        }
        if let loaded = loadFromBundle() {
            entries = loaded.entries
            indexDim = loaded.dim
            status = .ready(count: loaded.entries.count)
            return
        }
        if let loaded = loadFromAppSupport() {
            entries = loaded.entries
            indexDim = loaded.dim
            status = .ready(count: loaded.entries.count)
            return
        }
        await rebuildFromCanon()
    }

    /// Force a rebuild from the bundled canon, overwriting any saved index in
    /// Application Support. Does not touch the bundled file.
    func rebuildFromCanon() async {
        status = .building(progress: 0)

        // Same filter as `tools/build_embeddings.swift`: skip stubs, empty
        // bodies, and SuttaCentral repetition micro-entries (< 200 chars).
        let minBodyLen = 200
        let inputs: [(id: String, body: String)] = CanonStore.shared.entries
            .filter { !$0.lines.isEmpty && !$0.isStub }
            .compactMap { passage in
                let body = passage.lines
                    .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
                guard body.count >= minBodyLen else { return nil }
                return (passage.id, body)
            }

        guard !inputs.isEmpty else {
            status = .failed(message: "Canon has no entries with body text yet")
            return
        }

        let result: (entries: [Entry], dim: Int) = await Task.detached(priority: .userInitiated) {
            guard let embedder = NLEmbedding.wordEmbedding(for: .english) else {
                return ([], 0)
            }
            let dim = embedder.dimension
            guard dim > 0 else { return ([], 0) }

            var out: [Entry] = []
            out.reserveCapacity(inputs.count)
            for (id, body) in inputs {
                let capped: String = body.count > 4000 ? String(body.prefix(4000)) : body
                if let vec = Self.passageVector(capped, embedder: embedder, dim: dim) {
                    out.append(Entry(id: id, vec: vec))
                }
            }
            return (out, dim)
        }.value

        guard !result.entries.isEmpty else {
            status = .failed(message: "NLEmbedding produced no usable vectors")
            return
        }

        entries = result.entries
        indexDim = result.dim
        saveToAppSupport(result.entries, dim: result.dim)
        status = .ready(count: result.entries.count)
    }

    /// Returns up to `k` passages most similar to `query`, sorted by descending
    /// cosine similarity. Empty / whitespace-only queries return an empty list.
    /// Safe to call before `buildIfNeeded()`; returns `[]` until ready.
    func topK(query: String, k: Int) -> [(passageID: String, line: Int, score: Double)] {
        guard k > 0, !entries.isEmpty, indexDim > 0 else { return [] }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty,
              let embedder = NLEmbedding.wordEmbedding(for: .english),
              embedder.dimension == indexDim,
              let qf = Self.passageVector(q, embedder: embedder, dim: indexDim)
        else { return [] }

        let dim = indexDim
        var scored: [(id: String, score: Double)] = []
        scored.reserveCapacity(entries.count)
        for entry in entries {
            var dot: Float = 0
            for i in 0..<dim { dot += entry.vec[i] * qf[i] }
            scored.append((entry.id, Double(dot)))
        }
        scored.sort { $0.score > $1.score }
        return scored.prefix(k).map { (passageID: $0.id, line: -1, score: $0.score) }
    }

    // MARK: - Vector construction

    /// Bag-of-word-embeddings: tokenise, average per-token vectors, L2-normalise.
    nonisolated private static func passageVector(_ text: String,
                                                  embedder: NLEmbedding,
                                                  dim: Int) -> [Float]? {
        let lowered = text.lowercased()
        var sum = [Double](repeating: 0, count: dim)
        var n = 0
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = lowered
        tokenizer.enumerateTokens(in: lowered.startIndex..<lowered.endIndex) { range, _ in
            let token = String(lowered[range])
            if let v = embedder.vector(for: token), v.count == dim {
                for i in 0..<dim { sum[i] += v[i] }
                n += 1
            }
            return true
        }
        guard n > 0 else { return nil }

        var vec = [Float](repeating: 0, count: dim)
        var sumSq: Float = 0
        let inv = 1.0 / Double(n)
        for i in 0..<dim {
            let f = Float(sum[i] * inv)
            vec[i] = f
            sumSq += f * f
        }
        let mag = sqrt(sumSq)
        guard mag > 0 else { return nil }
        for i in 0..<dim { vec[i] /= mag }
        return vec
    }

    // MARK: - Persistence

    private var appSupportFileURL: URL? {
        guard let dir = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else { return nil }
        return dir.appendingPathComponent("embeddings.bin", isDirectory: false)
    }

    private func loadFromBundle() -> (entries: [Entry], dim: Int)? {
        // In test runs Bundle.main is the xctest harness, so fall back to the
        // bundle that owns this class (same trick CanonStore uses for canon.json).
        let url = Bundle.main.url(forResource: bundledFileName, withExtension: bundledFileExt)
            ?? Bundle(for: type(of: self)).url(forResource: bundledFileName, withExtension: bundledFileExt)
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return parse(data)
    }

    private func loadFromAppSupport() -> (entries: [Entry], dim: Int)? {
        guard let url = appSupportFileURL,
              let data = try? Data(contentsOf: url) else { return nil }
        return parse(data)
    }

    private func saveToAppSupport(_ items: [Entry], dim: Int) {
        guard let url = appSupportFileURL else { return }
        let data = encode(items, dim: dim)
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            print("⚠️ EmbeddingIndex save failed: \(error)")
        }
    }

    private func encode(_ items: [Entry], dim: Int) -> Data {
        var data = Data()
        appendLE(self.fileMagic, into: &data)
        appendLE(self.fileVersion, into: &data)
        appendLE(UInt32(items.count), into: &data)
        appendLE(UInt32(dim), into: &data)
        for item in items {
            let idBytes = Data(item.id.utf8)
            appendLE(UInt16(idBytes.count), into: &data)
            data.append(idBytes)
            item.vec.withUnsafeBufferPointer { buf in
                if let p = buf.baseAddress {
                    data.append(UnsafeBufferPointer(start: p, count: buf.count))
                }
            }
        }
        return data
    }

    private func parse(_ data: Data) -> (entries: [Entry], dim: Int)? {
        guard data.count >= 16 else { return nil }
        var offset = 0
        guard let magic = readLE(UInt32.self, data, &offset), magic == fileMagic,
              let version = readLE(UInt32.self, data, &offset), version == fileVersion,
              let count = readLE(UInt32.self, data, &offset),
              let savedDim = readLE(UInt32.self, data, &offset) else { return nil }
        let dim = Int(savedDim)
        guard dim > 0 else { return nil }

        let vecBytes = dim * MemoryLayout<Float>.size
        var out: [Entry] = []
        out.reserveCapacity(Int(count))
        for _ in 0..<count {
            guard let idLen = readLE(UInt16.self, data, &offset) else { return nil }
            guard offset + Int(idLen) <= data.count else { return nil }
            let idData = data.subdata(in: offset..<offset + Int(idLen))
            offset += Int(idLen)
            guard let id = String(data: idData, encoding: .utf8) else { return nil }
            guard offset + vecBytes <= data.count else { return nil }
            var vec = [Float](repeating: 0, count: dim)
            vec.withUnsafeMutableBytes { dst in
                data.copyBytes(to: dst.bindMemory(to: UInt8.self), from: offset..<offset + vecBytes)
            }
            offset += vecBytes
            out.append(Entry(id: id, vec: vec))
        }
        return (out, dim)
    }

    private func appendLE<T: FixedWidthInteger>(_ value: T, into data: inout Data) {
        var v = value.littleEndian
        withUnsafeBytes(of: &v) { data.append(contentsOf: $0) }
    }

    private func readLE<T: FixedWidthInteger>(_: T.Type, _ data: Data, _ offset: inout Int) -> T? {
        let size = MemoryLayout<T>.size
        guard offset + size <= data.count else { return nil }
        let value: T = data.withUnsafeBytes { buf in
            buf.loadUnaligned(fromByteOffset: offset, as: T.self)
        }
        offset += size
        return T(littleEndian: value)
    }
}
